import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import 'customer_controller.dart';

/// Customers — search, browse, add, edit, delete.
///
/// Built on top of the offline-first CustomerListController so the
/// list renders immediately even before the first sync. Tapping a
/// row opens the edit sheet; the FAB creates a new one.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customerListProvider);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                (c.phone ?? '').toLowerCase().contains(q) ||
                (c.email ?? '').toLowerCase().contains(q) ||
                (c.tin ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () =>
                ref.read(customerListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New customer'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerListProvider.notifier).refresh(),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, email or TIN',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) => _CustomerTile(
                        c: list[i],
                        onTap: () => _open(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Customer? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerEditSheet(existing: existing),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.c, required this.onTap});
  final Customer c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = c.name.isEmpty
        ? '?'
        : c.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((s) => s.isEmpty ? '' : s[0].toUpperCase())
            .join();
    final hasBalance = c.balanceCents > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryVeryLight,
              child: Text(initials,
                  style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if ((c.phone ?? '').isNotEmpty || (c.email ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [c.phone, c.email]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasBalance)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Owes ${Money.cents(c.balanceCents)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const Text('—',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                if (c.dirty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.cloud_queue_rounded,
                        size: 12, color: AppColors.warning),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: const [
        Icon(Icons.people_alt_outlined,
            size: 72, color: AppColors.slate300),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No customers yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Add your first customer to start tracking debt and reusing details on invoices.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Edit / create sheet
// ─────────────────────────────────────────────────────────────────────
class _CustomerEditSheet extends ConsumerStatefulWidget {
  const _CustomerEditSheet({required this.existing});
  final Customer? existing;

  @override
  ConsumerState<_CustomerEditSheet> createState() =>
      _CustomerEditSheetState();
}

class _CustomerEditSheetState extends ConsumerState<_CustomerEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _tin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _tin = TextEditingController(text: e?.tin ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _tin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit customer' : 'New customer',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _field(_name, 'Name', icon: Icons.person_rounded),
            const SizedBox(height: 10),
            _field(_phone, 'Phone',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _field(_email, 'Email',
                icon: Icons.alternate_email_rounded,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _field(_tin, 'TIN (for VAT invoices)',
                icon: Icons.badge_rounded),
            if (isEdit) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Outstanding balance',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(Money.cents(widget.existing!.balanceCents),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEdit)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      label: const Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.errorLight),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (isEdit) const SizedBox(width: 10),
                Expanded(
                  flex: isEdit ? 2 : 1,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: Text(isEdit ? 'Save' : 'Create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {IconData? icon, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required.')));
      return;
    }
    setState(() => _saving = true);
    final c = widget.existing == null
        ? Customer(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            tin: _tin.text.trim().isEmpty ? null : _tin.text.trim(),
            dirty: true,
          )
        : (widget.existing!
          ..name = name
          ..phone = _phone.text.trim().isEmpty ? null : _phone.text.trim()
          ..email = _email.text.trim().isEmpty ? null : _email.text.trim()
          ..tin = _tin.text.trim().isEmpty ? null : _tin.text.trim());
    final saved =
        await ref.read(customerListProvider.notifier).upsert(c);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved == null
            ? 'Saved locally — will sync when online.'
            : 'Customer saved.')));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
            '${widget.existing!.name} will be removed. Existing invoices will keep their captured details.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    final done = await ref
        .read(customerListProvider.notifier)
        .delete(widget.existing!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete — try again when online.')));
    }
  }
}
