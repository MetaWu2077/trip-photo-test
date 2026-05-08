import 'package:flutter/material.dart';
import '../../cloudbase/cloudbase_client.dart';
import '../../cloudbase/models/cloud_customer.dart';
import '../../cloudbase/repositories/cloud_customer_repository.dart';

/// 客户管理页面：展示、新建、删除客户。
class CustomerManagementPage extends StatefulWidget {
  final VoidCallback? onCustomerSelected;

  const CustomerManagementPage({super.key, this.onCustomerSelected});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _repo = CloudCustomerRepository();
  List<CloudCustomer> _customers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null || userId <= 0) return;
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _repo.getCustomers(userId);
      setState(() { _customers = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addCustomer() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) return;
    final result = await showDialog<_CustomerFormResult>(
      context: context,
      builder: (_) => _CustomerFormDialog(),
    );
    if (result == null) return;
    setState(() => _loading = true);
    final created = await _repo.createCustomer(
      userId: userId,
      name: result.name,
      phoneLast4: result.phoneLast4,
      location: result.location,
    );
    if (!mounted) return;
    if (created != null) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('客户「${result.name}」已添加'), behavior: SnackBarBehavior.floating),
      );
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加失败'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteCustomer(CloudCustomer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除客户「${customer.name}」？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _repo.deleteCustomer(customer.id);
    if (!mounted) return;
    if (ok) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('客户「${customer.name}」已删除'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _selectCustomer(CloudCustomer customer) {
    if (widget.onCustomerSelected != null) {
      widget.onCustomerSelected!.call();
      Navigator.pop(context, customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('客户管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('暂无客户', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('点击右下角添加', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final c = _customers[index];
          return Dismissible(
            key: ValueKey(c.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red[50],
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            confirmDismiss: (_) async {
              await _deleteCustomer(c);
              return false;
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(c.name.isNotEmpty ? c.name[0] : '?'),
              ),
              title: Text(c.name),
              subtitle: Text(
                [
                  if (c.phoneLast4 != null && c.phoneLast4!.isNotEmpty) '尾号 ${c.phoneLast4}',
                  if (c.location != null && c.location!.isNotEmpty) c.location,
                ].join(' · '),
              ),
              trailing: widget.onCustomerSelected != null
                  ? const Icon(Icons.chevron_right_rounded)
                  : null,
              onTap: widget.onCustomerSelected != null ? () => _selectCustomer(c) : null,
            ),
          );
        },
      ),
    );
  }
}

class _CustomerFormResult {
  final String name;
  final String? phoneLast4;
  final String? location;

  _CustomerFormResult({required this.name, this.phoneLast4, this.location});
}

class _CustomerFormDialog extends StatefulWidget {
  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加客户'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '姓名 *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: '手机尾号（后4位）',
                hintText: '如 6287',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '如 三亚海棠湾',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入姓名'), behavior: SnackBarBehavior.floating),
              );
              return;
            }
            final phone = _phoneCtrl.text.trim();
            Navigator.pop(
              context,
              _CustomerFormResult(
                name: name,
                phoneLast4: phone.isEmpty ? null : phone,
                location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
              ),
            );
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
