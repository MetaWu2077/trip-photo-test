const mysql = require('mysql');

const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = process.env.DB_PORT || 3306;
const DB_USER = process.env.DB_USER || 'root';
const DB_PASS = process.env.DB_PASS || '';
const DB_NAME = process.env.DB_NAME || '';

function getConn() {
  return mysql.createConnection({
    host: DB_HOST,
    port: Number(DB_PORT),
    user: DB_USER,
    password: DB_PASS,
    database: DB_NAME,
  });
}

// 关键：每次查询前执行 SET NAMES utf8mb4，确保中文正确
function q(sql, params = []) {
  return new Promise((resolve, reject) => {
    const conn = getConn();
    conn.connect(err => {
      if (err) { conn.end(); return reject(err); }
      conn.query('SET NAMES utf8mb4', err => {
        if (err) { conn.end(); return reject(err); }
        conn.query(sql, params, (err, rows) => {
          conn.end();
          if (err) return reject(err);
          resolve(rows);
        });
      });
    });
  });
}

// 懒初始化：表不存在则自动创建
async function ensureTables() {
  await q(`CREATE TABLE IF NOT EXISTS photos (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    session_id  INT NOT NULL,
    user_id     INT NOT NULL,
    thumb_key   VARCHAR(512) NOT NULL,
    original_key VARCHAR(512) DEFAULT '',
    file_size   INT UNSIGNED DEFAULT 0,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_session (session_id),
    INDEX idx_user (user_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  await q(`CREATE TABLE IF NOT EXISTS shifts (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    started_at DATETIME NOT NULL,
    ended_at   DATETIME DEFAULT NULL,
    photo_count INT UNSIGNED DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_date (user_id, started_at),
    INDEX idx_active (user_id, ended_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  await q(`CREATE TABLE IF NOT EXISTS bookings (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    customer_id  INT DEFAULT NULL,
    book_date    DATE NOT NULL,
    location     VARCHAR(256) DEFAULT '',
    status       ENUM('pending','confirmed','done','cancelled') DEFAULT 'pending',
    note         TEXT,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_book_date (book_date)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
}

let _tablesEnsured = false;
async function ensureTablesOnce() {
  if (!_tablesEnsured) {
    try { await ensureTables(); } catch (_) {}
    _tablesEnsured = true;
  }
}

function sendJson(status, data) {
  return {
    statusCode: status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(data),
  };
}

function extractPhone11(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length >= 11) return digits.slice(-11);
  return digits;
}

function nowStr() {
  return new Date().toISOString().slice(0, 19).replace('T', ' ');
}

exports.main = async (event, context) => {
  await ensureTablesOnce();

  // CloudBase HTTP Service 会传递完整路径（已剥离 /trip-api 前缀）
  let path = event.path || '';
  const method = event.httpMethod || 'GET';
  const queryParams = event.queryStringParameters || {};
  let body = {};

  if ((method === 'POST' || method === 'PATCH' || method === 'PUT') && event.body) {
    try { body = JSON.parse(event.body); } catch { body = {}; }
  }

  // CORS 预检
  if (method === 'OPTIONS') {
    return { statusCode: 204, headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': '*', 'Access-Control-Allow-Headers': '*' }, body: '' };
  }

  // === 认证相关 ===
  if (method === 'POST' && path === '/auth/send-code') {
    return sendJson(200, { success: true, message: '验证码已发送' });
  }

  if (method === 'POST' && path === '/auth/verify') {
    const { phone } = body;
    if (!phone) return sendJson(400, { error: '缺少手机号' });
    const phone11 = extractPhone11(phone);
    let users = await q('SELECT * FROM users WHERE phone = ?', [phone]);
    if (users.length === 0) {
      const result = await q('INSERT INTO users (phone, nick_name) VALUES (?, ?)', [phone, phone11]);
      users = [{ id: result.insertId, phone, nick_name: phone11 }];
    } else {
      await q('UPDATE users SET nick_name = ? WHERE id = ?', [phone11, users[0].id]);
      users[0].nick_name = phone11;
    }
    return sendJson(200, { success: true, user: users[0] });
  }

  // === 用户相关 ===
  if (method === 'GET' && path === '/users/me') {
    const userId = queryParams.userId;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    const users = await q('SELECT id, phone, nick_name, created_at, updated_at FROM users WHERE id = ?', [userId]);
    return sendJson(200, users[0] || null);
  }

  if (method === 'DELETE' && path === '/users/me') {
    const userId = queryParams.userId;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    await q('DELETE FROM sessions WHERE user_id = ?', [userId]);
    await q('DELETE FROM customers WHERE user_id = ?', [userId]);
    await q('DELETE FROM shifts WHERE user_id = ?', [userId]);
    await q('DELETE FROM photos WHERE user_id = ?', [userId]);
    await q('DELETE FROM bookings WHERE user_id = ?', [userId]);
    await q('DELETE FROM users WHERE id = ?', [userId]);
    return sendJson(200, { success: true });
  }

  if (method === 'PATCH' && path.startsWith('/users/')) {
    const id = path.split('/').pop();
    const nickName = String(body.nick_name ?? '').trim();
    if (!nickName) return sendJson(400, { error: '缺少nick_name' });
    await q('UPDATE users SET nick_name = ? WHERE id = ?', [nickName, id]);
    const users = await q('SELECT id, phone, nick_name, created_at, updated_at FROM users WHERE id = ?', [id]);
    return sendJson(200, users[0] || null);
  }

  // === 客户相关 ===
  if (method === 'GET' && path === '/customers') {
    const userId = queryParams.userId;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    const rows = await q('SELECT * FROM customers WHERE user_id = ? ORDER BY created_at DESC', [userId]);
    return sendJson(200, rows);
  }

  if (method === 'POST' && path === '/customers') {
    const { userId, name, phoneLast4, location } = body;
    const result = await q(
      'INSERT INTO customers (user_id, name, phone_last4, location) VALUES (?, ?, ?, ?)',
      [Number(userId), String(name ?? ''), String(phoneLast4 ?? ''), String(location ?? '')]
    );
    const [created] = await q('SELECT * FROM customers WHERE id = ?', [result.insertId]);
    return sendJson(200, created);
  }

  if (method === 'DELETE' && path === '/customers') {
    const customerId = queryParams.id;
    if (!customerId) return sendJson(400, { error: '缺少id' });
    await q('DELETE FROM customers WHERE id = ?', [customerId]);
    return sendJson(200, { success: true });
  }

  // === 会话/订单相关 ===
  if (method === 'GET' && path === '/sessions') {
    const userId = queryParams.userId;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    const rows = await q(
      'SELECT s.*, c.name as customer_name FROM sessions s LEFT JOIN customers c ON s.customer_id = c.id WHERE s.user_id = ? ORDER BY s.created_at DESC',
      [userId]
    );
    return sendJson(200, rows);
  }

  if (method === 'POST' && path === '/sessions') {
    const { userId, customerId, cosDirPrefix, status } = body;
    const startedAt = status === 'active' ? nowStr() : null;
    const result = await q(
      'INSERT INTO sessions (user_id, customer_id, cos_dir_prefix, status, started_at) VALUES (?, ?, ?, ?, ?)',
      [Number(userId), customerId || null, cosDirPrefix || '', status || 'pending', startedAt]
    );
    return sendJson(200, { id: result.insertId });
  }

  if (method === 'PATCH' && path.startsWith('/sessions/')) {
    const id = path.split('/').pop();
    const fields = [], vals = [];
    if (body.status !== undefined) { fields.push('status = ?'); vals.push(body.status); }
    if (body.cosDirPrefix !== undefined) { fields.push('cos_dir_prefix = ?'); vals.push(body.cosDirPrefix); }
    if (body.status === 'active' && body.startedAt === undefined) { fields.push('started_at = ?'); vals.push(nowStr()); }
    if (body.status === 'completed' && body.endedAt === undefined) { fields.push('ended_at = ?'); vals.push(nowStr()); }
    if (body.startedAt !== undefined) { fields.push('started_at = ?'); vals.push(body.startedAt); }
    if (body.endedAt !== undefined) { fields.push('ended_at = ?'); vals.push(body.endedAt); }
    if (fields.length === 0) return sendJson(400, { error: '无更新字段' });
    vals.push(id);
    await q(`UPDATE sessions SET ${fields.join(', ')} WHERE id = ?`, vals);
    return sendJson(200, { success: true });
  }

  // === 照片元数据相关 ===
  if (method === 'GET' && path === '/photos') {
    const userId = queryParams.userId;
    const sessionId = queryParams.sessionId;
    let sql = 'SELECT * FROM photos WHERE 1=1';
    const params = [];
    if (userId) { sql += ' AND user_id = ?'; params.push(Number(userId)); }
    if (sessionId) { sql += ' AND session_id = ?'; params.push(Number(sessionId)); }
    sql += ' ORDER BY created_at DESC';
    const rows = await q(sql, params);
    return sendJson(200, rows);
  }

  if (method === 'POST' && path === '/photos') {
    const { userId, sessionId, thumbKey, originalKey, fileSize } = body;
    if (!userId || !sessionId || !thumbKey) {
      return sendJson(400, { error: '缺少必要字段 userId/sessionId/thumbKey' });
    }
    const result = await q(
      'INSERT INTO photos (user_id, session_id, thumb_key, original_key, file_size) VALUES (?, ?, ?, ?, ?)',
      [Number(userId), Number(sessionId), thumbKey, originalKey || '', fileSize || 0]
    );
    const [created] = await q('SELECT * FROM photos WHERE id = ?', [result.insertId]);
    return sendJson(200, created);
  }

  if (method === 'DELETE' && path.startsWith('/photos/')) {
    const id = path.split('/').pop();
    await q('DELETE FROM photos WHERE id = ?', [Number(id)]);
    return sendJson(200, { success: true });
  }

  // === 班次/上工收工相关 ===
  if (method === 'GET' && path === '/shifts') {
    const userId = queryParams.userId;
    const date = queryParams.date; // YYYY-MM-DD 格式
    if (!userId) return sendJson(400, { error: '缺少userId' });
    let sql = 'SELECT * FROM shifts WHERE user_id = ?';
    const params = [Number(userId)];
    if (date) {
      sql += ' AND DATE(started_at) = ?';
      params.push(date);
    }
    sql += ' ORDER BY started_at DESC';
    const rows = await q(sql, params);
    return sendJson(200, rows);
  }

  if (method === 'POST' && path === '/shifts') {
    const { userId } = body;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    const result = await q(
      'INSERT INTO shifts (user_id, started_at) VALUES (?, ?)',
      [Number(userId), nowStr()]
    );
    const [created] = await q('SELECT * FROM shifts WHERE id = ?', [result.insertId]);
    return sendJson(200, created);
  }

  if (method === 'PATCH' && path.startsWith('/shifts/')) {
    const id = path.split('/').pop();
    const shift = await q('SELECT * FROM shifts WHERE id = ?', [Number(id)]);
    if (!shift.length) return sendJson(404, { error: '班次不存在' });
    if (shift[0].ended_at) return sendJson(400, { error: '已收工' });

    if (body.endedAt !== undefined || body.action === 'clock_out') {
      await q('UPDATE shifts SET ended_at = ? WHERE id = ? AND ended_at IS NULL', [nowStr(), Number(id)]);
    }
    // 更新照片计数
    if (body.photoCount !== undefined) {
      await q('UPDATE shifts SET photo_count = ? WHERE id = ?', [Number(body.photoCount), Number(id)]);
    }
    const [updated] = await q('SELECT * FROM shifts WHERE id = ?', [Number(id)]);
    return sendJson(200, updated);
  }

  // === 预约/订单相关 ===
  if (method === 'GET' && path === '/bookings') {
    const userId = queryParams.userId;
    if (!userId) return sendJson(400, { error: '缺少userId' });
    const rows = await q(
      'SELECT b.*, c.name as customer_name FROM bookings b LEFT JOIN customers c ON b.customer_id = c.id WHERE b.user_id = ? ORDER BY b.book_date DESC',
      [Number(userId)]
    );
    return sendJson(200, rows);
  }

  if (method === 'POST' && path === '/bookings') {
    const { userId, customerId, bookDate, location, status, note } = body;
    if (!userId || !bookDate) return sendJson(400, { error: '缺少 userId 或 bookDate' });
    const result = await q(
      'INSERT INTO bookings (user_id, customer_id, book_date, location, status, note) VALUES (?, ?, ?, ?, ?, ?)',
      [Number(userId), customerId || null, bookDate, location || '', status || 'pending', note || '']
    );
    const [created] = await q('SELECT * FROM bookings WHERE id = ?', [result.insertId]);
    return sendJson(200, created);
  }

  if (method === 'PATCH' && path.startsWith('/bookings/')) {
    const id = path.split('/').pop();
    const fields = [], vals = [];
    ['location', 'status', 'note'].forEach(f => {
      if (body[f] !== undefined) { fields.push(`${f} = ?`); vals.push(body[f]); }
    });
    if (fields.length === 0) return sendJson(400, { error: '无更新字段' });
    vals.push(Number(id));
    await q(`UPDATE bookings SET ${fields.join(', ')} WHERE id = ?`, vals);
    const [updated] = await q('SELECT * FROM bookings WHERE id = ?', [Number(id)]);
    return sendJson(200, updated);
  }

  if (method === 'DELETE' && path.startsWith('/bookings/')) {
    const id = path.split('/').pop();
    await q('DELETE FROM bookings WHERE id = ?', [Number(id)]);
    return sendJson(200, { success: true });
  }

  // === 统计相关 ===
  if (method === 'GET' && path === '/stats/daily') {
    const userId = queryParams.userId;
    const date = queryParams.date || new Date().toISOString().slice(0, 10); // 默认今天
    if (!userId) return sendJson(400, { error: '缺少userId' });

    const shifts = await q(
      'SELECT COUNT(*) as shift_count, SUM(photo_count) as total_photos FROM shifts WHERE user_id = ? AND DATE(started_at) = ? AND ended_at IS NOT NULL',
      [Number(userId), date]
    );
    const activeShifts = await q(
      'SELECT COUNT(*) as active_count FROM shifts WHERE user_id = ? AND ended_at IS NULL',
      [Number(userId)]
    );
    const sessions = await q(
      'SELECT COUNT(*) as session_count FROM sessions WHERE user_id = ? AND DATE(started_at) = ?',
      [Number(userId), date]
    );
    const customers = await q(
      'SELECT COUNT(DISTINCT customer_id) as customer_count FROM sessions WHERE user_id = ? AND customer_id IS NOT NULL AND DATE(started_at) = ?',
      [Number(userId), date]
    );

    return sendJson(200, {
      date,
      shiftCount: Number(shifts[0]?.shift_count || 0),
      totalPhotos: Number(shifts[0]?.total_photos || 0),
      activeShiftCount: Number(activeShifts[0]?.active_count || 0),
      sessionCount: Number(sessions[0]?.session_count || 0),
      customerCount: Number(customers[0]?.customer_count || 0),
    });
  }

  // === 健康检查 ===
  if (method === 'GET' && path === '/health') {
    return sendJson(200, { ok: true });
  }

  return sendJson(404, { error: 'Not Found' });
};
