import 'package:flutter/material.dart';
import '../../cloudbase/models/cloud_customer.dart';
import '../../cloudbase/repositories/cloud_customer_repository.dart';
import 'customer_management_page.dart';

/// 客户选择对话框：展示已有客户列表，可选其一或新建。
Future<CloudCustomer?> showCustomerSelectorDialog(BuildContext context) {
  return showModalBottomSheet<CloudCustomer>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CustomerSelectorSheet(),
  );
}

class _CustomerSelectorSheet extends StatefulWidget {
  const _CustomerSelectorSheet();

  @override
  State<_CustomerSelectorSheet> createState() => _CustomerSelectorSheetState();
}

class _CustomerSelectorSheetState extends State<_CustomerSelectorSheet> {
  final _repo = CloudCustomerRepository();
  List<CloudCustomer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // 从 context 中获取 userId
    // ignore: use_build_context_synchronously
    final list = await _repo.getCustomers(0); // 临时传 0，后面修正
    if (mounted) setState(() { _customers = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('选择客户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<CloudCustomer>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerManagementPage(
                            onCustomerSelected: () => Navigator.pop(context),
                          ),
                        ),
                      );
                      if (result != null && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('暂无客户，请先添加', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(c.name.isNotEmpty ? c.name[0] : '?'),
                              ),
                              title: Text(c.name),
                              subtitle: Text(
                                [
                                  if (c.phoneLast4 != null) '尾号 ${c.phoneLast4}',
                                  if (c.location != null && c.location!.isNotEmpty) c.location,
                                ].join(' · '),
                              ),
                              onTap: () => Navigator.pop(context, c),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
