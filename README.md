# 旅拍照片上传 (trip-photo-test)

一个用于将旅行照片上传至**腾讯云 COS** 的 Flutter 示例应用。  
支持从相册选择图片、自动压缩缩略图，并将缩略图与原图分别上传到 COS，上传完成后展示访问 URL。

---

## 功能特性

- 📷 从系统相册选择图片（`image_picker`）
- 🔒 运行时申请并处理相册/存储权限（`permission_handler`）
- 🖼️ 图片预览 + 自动压缩至 1080 px 宽度 JPEG 80%（`image`）
- ☁️ 分别上传缩略图与原图到腾讯云 COS（`tencent_cos`）
- ⚙️ 通过 `.env` 文件管理密钥（`flutter_dotenv`），**绝不硬编码到源码**
- ✅/❌ loading 状态 + 成功/失败提示 + 上传后 URL 展示

---

## 环境要求

| 依赖         | 版本要求         |
|------------|--------------|
| Flutter    | ≥ 3.19.0     |
| Dart       | ≥ 3.0.0      |
| Android    | minSdk 21+   |
| iOS        | 12.0+        |

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/MetaWu2077/trip-photo-test.git
cd trip-photo-test
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env`，填入你的腾讯云 COS 凭证：

```bash
cp .env.example .env
```

编辑 `.env`：

```dotenv
COS_APP_ID=1234567890
COS_SECRET_ID=AKIDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
COS_SECRET_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
COS_REGION=ap-guangzhou
COS_BUCKET=my-bucket-1234567890
COS_DOMAIN=                    # 可选：自定义 CDN 域名
```

> ⚠️ **安全提示**：`.env` 已加入 `.gitignore`，请勿将含真实密钥的 `.env` 提交到版本控制。

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 运行

```bash
flutter run
```

---

## `.env` 配置说明

| 字段             | 必填 | 说明                                                      |
|----------------|----|---------------------------------------------------------|
| `COS_APP_ID`   | ✅  | 腾讯云账号 AppID（数字），见「账号信息」页面                               |
| `COS_SECRET_ID`  | ✅  | CAM 密钥 SecretId，见「访问管理 > API 密钥管理」                      |
| `COS_SECRET_KEY` | ✅  | CAM 密钥 SecretKey                                        |
| `COS_REGION`   | ✅  | 存储桶所在地域，例如 `ap-guangzhou`、`ap-shanghai`                 |
| `COS_BUCKET`   | ✅  | 存储桶名称，格式 `<BucketName>-<AppID>`，例如 `photos-1234567890` |
| `COS_DOMAIN`   | ❌  | 自定义 CDN/加速域名（留空时使用默认 COS 域名）                            |

若任意必填字段缺失，App 将在主页顶部展示橙色警告横幅，并禁用上传按钮。

---

## 权限配置

### Android

以下权限已在 `android/app/src/main/AndroidManifest.xml` 中声明，无需额外修改：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>         <!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>                                                 <!-- Android ≤ 12 -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>                                                 <!-- Android ≤ 9 -->
```

### iOS

以下 key 已在 `ios/Runner/Info.plist` 中添加：

| Key                              | 说明               |
|----------------------------------|------------------|
| `NSPhotoLibraryUsageDescription` | 访问相册（读取）         |
| `NSPhotoLibraryAddUsageDescription` | 保存至相册（写入，备用）  |
| `NSCameraUsageDescription`       | 摄像头（如需拍照上传）      |

---

## 项目结构

```
trip-photo-test/
├── lib/
│   ├── main.dart                  # 入口：加载 dotenv，启动 App
│   ├── pages/
│   │   └── home_page.dart         # 主页：选图、预览、上传 UI
│   └── services/
│       └── cos_uploader.dart      # 腾讯 COS 上传封装
├── android/                       # Android 平台代码
├── ios/                           # iOS 平台代码
├── test/
│   └── widget_test.dart           # Widget 测试
├── .env.example                   # 环境变量模板
├── .gitignore
├── analysis_options.yaml
└── pubspec.yaml
```

---

## CI / CD

仓库已配置两个 GitHub Actions workflow：

| Workflow | 触发 | 说明 |
|----------|-----|------|
| `flutter_ci.yml` | push / PR | `flutter analyze` + `flutter test` |
| `build.yml` | push to main/master | 编译 Release APK 并上传 Artifact |

`build.yml` 通过 GitHub Secrets 注入 COS 密钥（`COS_APP_ID`、`COS_SECRET_ID` 等），无需在代码中硬编码。

---

## 常见问题

**Q: 运行时提示「.env 加载失败」？**  
A: 确保项目根目录存在 `.env` 文件，并且 `pubspec.yaml` 中已将 `.env` 列为 assets（默认已配置）。

**Q: 上传失败，错误码 403？**  
A: 检查 SecretId/SecretKey 是否正确，以及 COS 存储桶的「跨域访问 CORS」和「访问权限」设置。

**Q: Android 13 无法选图？**  
A: 确认 `AndroidManifest.xml` 中包含 `READ_MEDIA_IMAGES` 权限，且 App 在运行时已获得该权限。
