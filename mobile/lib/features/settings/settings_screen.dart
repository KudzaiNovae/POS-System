import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/db/local_db.dart';
import '../../core/services/printer/printer_provider.dart';
import '../../core/subscription/feature_gate.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/printer/app_printer_selector.dart';
import '../../core/widgets/printer/app_print_dialog.dart';

/// Production-ready Settings screen.
///
/// Covers every configurable surface an SME operator needs:
///   - Shop profile (name, address, phone, email)
///   - ZIMRA / tax registration (TIN, VAT number, fiscal device id)
///   - Currency + locale + country
///   - Subscription (current tier + upgrade CTA)
///   - Printer (Bluetooth/USB/network via printer_service)
///   - Print + receipt formatting preferences (persisted to Hive)
///   - Sync status (last pull, pending items in outbox, force-sync button)
///   - Data management (clear cache, export backup)
///   - Account (current user, logout)
///
/// Every control reads from and writes to Hive so restarts survive.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Shop profile
  late final TextEditingController _shopName;
  late final TextEditingController _shopAddress;
  late final TextEditingController _shopPhone;
  late final TextEditingController _ownerEmail;

  // Tax registration
  late final TextEditingController _tin;
  late final TextEditingController _vatNumber;
  late final TextEditingController _fiscalDeviceId;

  // Prefs
  late String _currency;
  late String _countryCode;
  late String _locale;

  // Print prefs (persisted under meta)
  late bool _autoPrint;
  late bool _showPrintDialog;
  late int _paperWidth;
  late int _fontSize;
  late bool _printQr;
  late bool _printBarcode;

  // Sync / about
  String _appVersion = '—';
  String _buildNumber = '—';
  int _outboxCount = 0;

  bool _saving = false;
  late _SettingsDraft _savedDraft;

  String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  _SettingsDraft get _currentDraft => _SettingsDraft(
        shopName: _clean(_shopName.text),
        shopAddress: _clean(_shopAddress.text),
        shopPhone: _clean(_shopPhone.text),
        ownerEmail: _clean(_ownerEmail.text),
        tin: _clean(_tin.text),
        vatNumber: _clean(_vatNumber.text),
        fiscalDeviceId: _clean(_fiscalDeviceId.text),
        currency: _currency,
        countryCode: _countryCode,
        locale: _locale,
        autoPrint: _autoPrint,
        showPrintDialog: _showPrintDialog,
        paperWidth: _paperWidth,
        fontSize: _fontSize,
        printQr: _printQr,
        printBarcode: _printBarcode,
      );

  bool get _hasChanges => _currentDraft != _savedDraft;

  void _onEdited() {
    if (!mounted) return;
    setState(() {});
  }

  String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  bool get _hasChanges {
    final meta = LocalDb.metaBox;
    return _clean(_shopName.text) != LocalDb.shopName ||
        _clean(_shopAddress.text) != LocalDb.shopAddress ||
        _clean(_shopPhone.text) != LocalDb.shopPhone ||
        _clean(_ownerEmail.text) != LocalDb.ownerEmail ||
        _clean(_tin.text) != LocalDb.tin ||
        _clean(_vatNumber.text) != LocalDb.vatNumber ||
        _clean(_fiscalDeviceId.text) != LocalDb.fiscalDeviceId ||
        _currency != LocalDb.currency ||
        _countryCode != LocalDb.countryCode ||
        _locale != LocalDb.locale ||
        _autoPrint != (meta.get('autoPrint', defaultValue: false) as bool) ||
        _showPrintDialog !=
            (meta.get('showPrintDialog', defaultValue: true) as bool) ||
        _paperWidth !=
            (meta.get('paperWidth', defaultValue: 80) as num).toInt() ||
        _fontSize != (meta.get('fontSize', defaultValue: 1) as num).toInt() ||
        _printQr != (meta.get('printQr', defaultValue: true) as bool) ||
        _printBarcode != (meta.get('printBarcode', defaultValue: false) as bool);
  }

  void _onEdited() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _shopName = TextEditingController(text: LocalDb.shopName ?? '');
    _shopAddress = TextEditingController(text: LocalDb.shopAddress ?? '');
    _shopPhone = TextEditingController(text: LocalDb.shopPhone ?? '');
    _ownerEmail = TextEditingController(text: LocalDb.ownerEmail ?? '');
    _tin = TextEditingController(text: LocalDb.tin ?? '');
    _vatNumber = TextEditingController(text: LocalDb.vatNumber ?? '');
    _fiscalDeviceId =
        TextEditingController(text: LocalDb.fiscalDeviceId ?? '');
    _shopName.addListener(_onEdited);
    _shopAddress.addListener(_onEdited);
    _shopPhone.addListener(_onEdited);
    _ownerEmail.addListener(_onEdited);
    _tin.addListener(_onEdited);
    _vatNumber.addListener(_onEdited);
    _fiscalDeviceId.addListener(_onEdited);

    _currency = LocalDb.currency;
    _countryCode = LocalDb.countryCode;
    _locale = LocalDb.locale;

    final meta = LocalDb.metaBox;
    _autoPrint = meta.get('autoPrint', defaultValue: false) as bool;
    _showPrintDialog =
        meta.get('showPrintDialog', defaultValue: true) as bool;
    _paperWidth = (meta.get('paperWidth', defaultValue: 80) as num).toInt();
    _fontSize = (meta.get('fontSize', defaultValue: 1) as num).toInt();
    _printQr = meta.get('printQr', defaultValue: true) as bool;
    _printBarcode = meta.get('printBarcode', defaultValue: false) as bool;
    _savedDraft = _currentDraft;

    _loadAboutAndSync();
  }

  Future<void> _loadAboutAndSync() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {}
    _refreshOutbox();
  }

  void _refreshOutbox() {
    setState(() => _outboxCount = LocalDb.outboxBox.length);
  }

  @override
  void dispose() {
    _shopName.dispose();
    _shopAddress.dispose();
    _shopPhone.dispose();
    _ownerEmail.dispose();
    _tin.dispose();
    _vatNumber.dispose();
    _fiscalDeviceId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      LocalDb.shopName = _shopName.text.trim().isEmpty ? null : _shopName.text.trim();
      LocalDb.shopAddress =
          _shopAddress.text.trim().isEmpty ? null : _shopAddress.text.trim();
      LocalDb.shopPhone =
          _shopPhone.text.trim().isEmpty ? null : _shopPhone.text.trim();
      LocalDb.ownerEmail =
          _ownerEmail.text.trim().isEmpty ? null : _ownerEmail.text.trim();
      LocalDb.tin = _tin.text.trim().isEmpty ? null : _tin.text.trim();
      LocalDb.vatNumber =
          _vatNumber.text.trim().isEmpty ? null : _vatNumber.text.trim();
      LocalDb.fiscalDeviceId = _fiscalDeviceId.text.trim().isEmpty
          ? null
          : _fiscalDeviceId.text.trim();
      LocalDb.currency = _currency;
      LocalDb.countryCode = _countryCode;
      LocalDb.locale = _locale;

      final meta = LocalDb.metaBox;
      await meta.put('autoPrint', _autoPrint);
      await meta.put('showPrintDialog', _showPrintDialog);
      await meta.put('paperWidth', _paperWidth);
      await meta.put('fontSize', _fontSize);
      await meta.put('printQr', _printQr);
      await meta.put('printBarcode', _printBarcode);
      _savedDraft = _currentDraft;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
            'You have unsaved edits in Settings. Save first or discard your changes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard')),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(printerConnectedProvider);
    final selectedPrinter = ref.watch(selectedPrinterProvider);
    final auth = ref.watch(authControllerProvider);

    return WillPopScope(
      onWillPop: _confirmDiscardIfDirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Settings',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          centerTitle: true,
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: Text(
                    'Unsaved',
                    style: AppTypography.labelSmall(
                      color: AppColors.warning,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: _saving || !_hasChanges ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubscriptionCard(
                tier: auth.tier,
                onUpgrade: () => _showUpgradeSheet(context, auth.tier),
              ),
              const SizedBox(height: AppSpacing.lg),
              _businessToolsSection(),
              const SizedBox(height: AppSpacing.lg),
              _shopProfileSection(),
              const SizedBox(height: AppSpacing.lg),
              _taxSection(),
              const SizedBox(height: AppSpacing.lg),
              _regionalSection(),
              const SizedBox(height: AppSpacing.lg),
              _printerSection(isConnected, selectedPrinter),
              const SizedBox(height: AppSpacing.lg),
              _syncSection(),
              const SizedBox(height: AppSpacing.lg),
              _dataSection(),
              const SizedBox(height: AppSpacing.lg),
              _accountSection(),
              const SizedBox(height: AppSpacing.lg),
              _aboutSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- sections ----

  /// Quick-launch tiles for backend-only features that don't have their
  /// own bottom-nav slot (Customers, Z-Reports, ZIMRA fiscal queue).
  Widget _businessToolsSection() {
    return _Section(
      title: 'Business tools',
      icon: Icons.dashboard_customize_outlined,
      subtitle:
          'Manage customers, close the day, and track ZIMRA submissions.',
      children: [
        AppCard(
          child: Column(
            children: [
              _navTile(
                icon: Icons.people_alt_outlined,
                title: 'Customers',
                subtitle: 'Address book + outstanding balances',
                onTap: () => context.push('/customers'),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _navTile(
                icon: Icons.receipt_long_outlined,
                title: 'Z-Reports',
                subtitle: "Close today's till and audit past closes",
                onTap: () => context.push('/reports/z'),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _navTile(
                icon: Icons.account_balance_outlined,
                title: 'Fiscal queue (ZIMRA)',
                subtitle: 'See FDMS submissions and any rejections',
                onTap: () => context.push('/fiscal'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryVeryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryDark, size: 18),
      ),
      title: Text(title,
          style:
              AppTypography.bodyMedium(weight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style:
              AppTypography.bodySmall(color: AppColors.textTertiary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  Widget _shopProfileSection() {
    return _Section(
      title: 'Shop profile',
      icon: Icons.store_outlined,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _shopName,
                decoration: const InputDecoration(
                  labelText: 'Shop / business name',
                  hintText: 'Shows on every receipt and invoice',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _shopAddress,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Street, city, country',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _shopPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. +263 77 123 4567',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _ownerEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Owner email',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taxSection() {
    return _Section(
      title: 'Tax & fiscalisation',
      icon: Icons.receipt_long_outlined,
      subtitle:
          'ZIMRA / tax authority details. These appear on every tax invoice.',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tin,
                decoration: const InputDecoration(
                  labelText: 'TIN (Tax Identification Number)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _vatNumber,
                decoration: const InputDecoration(
                  labelText: 'VAT registration number',
                  hintText: 'If VAT-registered',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _fiscalDeviceId,
                decoration: const InputDecoration(
                  labelText: 'Fiscal device ID (FDMS)',
                  hintText: 'Assigned by ZIMRA',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _regionalSection() {
    return _Section(
      title: 'Regional',
      icon: Icons.language_outlined,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                decoration: const InputDecoration(labelText: 'Country'),
                items: const [
                  DropdownMenuItem(value: 'ZW', child: Text('Zimbabwe')),
                  DropdownMenuItem(value: 'ZA', child: Text('South Africa')),
                  DropdownMenuItem(value: 'BW', child: Text('Botswana')),
                  DropdownMenuItem(value: 'ZM', child: Text('Zambia')),
                  DropdownMenuItem(value: 'MW', child: Text('Malawi')),
                  DropdownMenuItem(value: 'MZ', child: Text('Mozambique')),
                  DropdownMenuItem(value: 'NA', child: Text('Namibia')),
                  DropdownMenuItem(value: 'KE', child: Text('Kenya')),
                  DropdownMenuItem(value: 'TZ', child: Text('Tanzania')),
                  DropdownMenuItem(value: 'UG', child: Text('Uganda')),
                  DropdownMenuItem(value: 'NG', child: Text('Nigeria')),
                  DropdownMenuItem(value: 'GH', child: Text('Ghana')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _countryCode = v ?? _countryCode),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                    labelText: 'Default display currency'),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD — US Dollar')),
                  DropdownMenuItem(
                      value: 'ZWG', child: Text('ZWG — Zimbabwe Gold')),
                  DropdownMenuItem(value: 'ZAR', child: Text('ZAR — SA Rand')),
                  DropdownMenuItem(value: 'BWP', child: Text('BWP — Pula')),
                  DropdownMenuItem(value: 'ZMW', child: Text('ZMW — Kwacha')),
                  DropdownMenuItem(
                      value: 'KES', child: Text('KES — Kenyan Shilling')),
                  DropdownMenuItem(
                      value: 'NGN', child: Text('NGN — Naira')),
                  DropdownMenuItem(value: 'GHS', child: Text('GHS — Cedi')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP — Pound')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _locale,
                decoration: const InputDecoration(labelText: 'App language'),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'sn', child: Text('chiShona')),
                  DropdownMenuItem(value: 'nd', child: Text('isiNdebele')),
                  DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                ],
                onChanged: (v) => setState(() => _locale = v ?? _locale),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _printerSection(bool isConnected, selectedPrinter) {
    return _Section(
      title: 'Printer',
      icon: Icons.print_outlined,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _printerStatus(isConnected, selectedPrinter),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.search_outlined),
                      label: const Text('Find printer'),
                      onPressed: _openPrinterSelector,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Test print'),
                      onPressed: isConnected ? _testPrint : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Receipt options',
                  style: AppTypography.titleMedium()),
              const SizedBox(height: AppSpacing.md),
              _toggleRow(
                title: 'Auto-print after sale',
                subtitle: 'Automatically print when a sale is completed',
                value: _autoPrint,
                onChanged: (v) => setState(() => _autoPrint = v),
              ),
              const Divider(height: AppSpacing.lg),
              _toggleRow(
                title: 'Confirm before printing',
                subtitle: 'Show a preview + print dialog',
                value: _showPrintDialog,
                onChanged: (v) => setState(() => _showPrintDialog = v),
              ),
              const Divider(height: AppSpacing.lg),
              _toggleRow(
                title: 'Include QR code',
                subtitle: 'ZIMRA verification payload on each receipt',
                value: _printQr,
                onChanged: (v) => setState(() => _printQr = v),
              ),
              const Divider(height: AppSpacing.lg),
              _toggleRow(
                title: 'Include barcode',
                subtitle: 'Print receipt number as a barcode',
                value: _printBarcode,
                onChanged: (v) => setState(() => _printBarcode = v),
              ),
              const Divider(height: AppSpacing.lg),
              Text('Paper width', style: AppTypography.bodyMedium()),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 58, label: Text('58 mm')),
                  ButtonSegment(value: 80, label: Text('80 mm')),
                ],
                selected: {_paperWidth},
                onSelectionChanged: (s) =>
                    setState(() => _paperWidth = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Font size', style: AppTypography.bodyMedium()),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Small')),
                  ButtonSegment(value: 1, label: Text('Normal')),
                  ButtonSegment(value: 2, label: Text('Large')),
                ],
                selected: {_fontSize},
                onSelectionChanged: (s) => setState(() => _fontSize = s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _syncSection() {
    final lastPull = LocalDb.lastPullAt;
    final pulled = lastPull.year <= 1970
        ? 'Never'
        : '${lastPull.toLocal().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
    return _Section(
      title: 'Sync',
      icon: Icons.sync_outlined,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('Last successful pull', pulled),
              const Divider(height: AppSpacing.lg),
              _infoRow('Pending changes in outbox', '$_outboxCount'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Refresh status'),
                      onPressed: _refreshOutbox,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.cloud_sync_outlined),
                      label: const Text('Sync now'),
                      onPressed: () async {
                        await ref.read(syncServiceProvider).syncNow();
                        _refreshOutbox();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sync triggered')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataSection() {
    return _Section(
      title: 'Data',
      icon: Icons.storage_outlined,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('Products on device', '${LocalDb.allProducts().length}'),
              const Divider(height: AppSpacing.lg),
              _infoRow(
                  'Invoices on device', '${LocalDb.allInvoices().length}'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear local cache'),
                onPressed: _confirmClearCache,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountSection() {
    final email = LocalDb.ownerEmail ?? '—';
    final tenant = LocalDb.tenantId ?? '—';
    final device = LocalDb.deviceId ?? '—';
    return _Section(
      title: 'Account',
      icon: Icons.person_outline,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('Signed in as', email),
              const Divider(height: AppSpacing.lg),
              _infoRow('Tenant ID', tenant, copyable: true),
              const Divider(height: AppSpacing.lg),
              _infoRow('Device ID', device, copyable: true),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_outlined, color: AppColors.error),
                label: const Text('Sign out',
                    style: TextStyle(color: AppColors.error)),
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aboutSection() {
    return _Section(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        AppCard(
          child: Column(
            children: [
              _infoRow('App version', _appVersion),
              const Divider(height: AppSpacing.lg),
              _infoRow('Build', _buildNumber),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Center(
            child: Text('TillPro © 2026\nBuilt for SMEs, offline-first',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  // ---- helpers ----

  Widget _printerStatus(bool connected, printer) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: connected ? AppColors.successBg : AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
              connected
                  ? Icons.print_outlined
                  : Icons.print_disabled_outlined,
              color: connected ? AppColors.success : AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    connected && printer != null
                        ? printer.name
                        : 'No printer connected',
                    style:
                        AppTypography.titleSmall(weight: FontWeight.bold)),
                if (connected && printer != null)
                  Text(printer.connectionType.name.toUpperCase(),
                      style: AppTypography.labelSmall(
                          color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyMedium()),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle,
                  style:
                      AppTypography.bodySmall(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
        ),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium(weight: FontWeight.w600)),
        ),
        if (copyable)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_outlined, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Copied'),
                    duration: const Duration(milliseconds: 900)),
              );
            },
          ),
      ],
    );
  }

  void _openPrinterSelector() {
    showDialog(
      context: context,
      builder: (_) => AppPrinterSelector(
        onConnected: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Printer connected'),
                backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  void _testPrint() {
    showDialog(
      context: context,
      builder: (_) => AppPrinterTestDialog(
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Test print sent'),
                backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear local cache?'),
        content: const Text(
            'Local product, sale and invoice caches will be removed. Any unsent writes in the outbox will also be lost. Your account is not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await LocalDb.productsBox.clear();
    await LocalDb.salesBox.clear();
    await LocalDb.saleItemsBox.clear();
    await LocalDb.invoicesBox.clear();
    await LocalDb.customersBox.clear();
    await LocalDb.outboxBox.clear();
    LocalDb.lastPullAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    _refreshOutbox();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local cache cleared')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign back in to continue. Any unsent writes in the outbox will remain on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  void _showUpgradeSheet(BuildContext context, String currentTier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UpgradeSheet(currentTier: currentTier),
    );
  }
}

// ---- local widgets ----

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(title,
                style: AppTypography.titleLarge(
                    weight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!,
              style:
                  AppTypography.bodySmall(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.tier, required this.onUpgrade});
  final String tier;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final isPaid = tier != 'FREE';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPaid
              ? const [Color(0xFF6366F1), Color(0xFF8B5CF6)]
              : const [Color(0xFF0F172A), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_outlined,
              color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan',
                    style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(tier,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${FeatureGate.productLimit == 1 << 30 ? 'Unlimited' : FeatureGate.productLimit} products · ${FeatureGate.deviceLimit} devices · ${FeatureGate.historyDays}d history',
                  style: GoogleFonts.outfit(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
            ),
            onPressed: onUpgrade,
            child: Text(isPaid ? 'Manage' : 'Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _UpgradeSheet extends ConsumerStatefulWidget {
  const _UpgradeSheet({required this.currentTier});
  final String currentTier;
  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  String _tier = 'STARTER';
  String _provider = 'ECOCASH';
  final _phone = TextEditingController(text: LocalDb.shopPhone ?? '');
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentTier != 'FREE') {
      _tier = widget.currentTier;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _upgrade() async {
    setState(() => _submitting = true);
    try {
      final r = await ref
          .read(authControllerProvider.notifier)
          .upgradeSubscription(
              tier: _tier, provider: _provider, phone: _phone.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Upgrade initiated. ${r['message'] ?? 'Follow the prompt on your phone.'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not start upgrade: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upgrade your plan',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Pay via mobile money. Plan activates as soon as the provider confirms.',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tier,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: const [
              DropdownMenuItem(
                  value: 'STARTER',
                  child: Text('Starter — 500 products, 2 devices, 90d history')),
              DropdownMenuItem(
                  value: 'PRO',
                  child:
                      Text('Pro — unlimited products, 5 devices, advanced analytics')),
              DropdownMenuItem(
                  value: 'BUSINESS',
                  child:
                      Text('Business — multi-branch, 10 devices, priority support')),
            ],
            onChanged: (v) => setState(() => _tier = v ?? _tier),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Pay with'),
            items: const [
              DropdownMenuItem(value: 'ECOCASH', child: Text('EcoCash')),
              DropdownMenuItem(value: 'ONEMONEY', child: Text('OneMoney')),
              DropdownMenuItem(value: 'INNBUCKS', child: Text('InnBucks')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: (v) => setState(() => _provider = v ?? _provider),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Mobile number to charge',
                hintText: 'e.g. +263 77 123 4567'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _upgrade,
                  child: _submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Pay & upgrade'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsDraft {
  const _SettingsDraft({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.ownerEmail,
    required this.tin,
    required this.vatNumber,
    required this.fiscalDeviceId,
    required this.currency,
    required this.countryCode,
    required this.locale,
    required this.autoPrint,
    required this.showPrintDialog,
    required this.paperWidth,
    required this.fontSize,
    required this.printQr,
    required this.printBarcode,
  });

  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? ownerEmail;
  final String? tin;
  final String? vatNumber;
  final String? fiscalDeviceId;
  final String currency;
  final String countryCode;
  final String locale;
  final bool autoPrint;
  final bool showPrintDialog;
  final int paperWidth;
  final int fontSize;
  final bool printQr;
  final bool printBarcode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _SettingsDraft &&
        other.shopName == shopName &&
        other.shopAddress == shopAddress &&
        other.shopPhone == shopPhone &&
        other.ownerEmail == ownerEmail &&
        other.tin == tin &&
        other.vatNumber == vatNumber &&
        other.fiscalDeviceId == fiscalDeviceId &&
        other.currency == currency &&
        other.countryCode == countryCode &&
        other.locale == locale &&
        other.autoPrint == autoPrint &&
        other.showPrintDialog == showPrintDialog &&
        other.paperWidth == paperWidth &&
        other.fontSize == fontSize &&
        other.printQr == printQr &&
        other.printBarcode == printBarcode;
  }

  @override
  int get hashCode => Object.hash(
        shopName,
        shopAddress,
        shopPhone,
        ownerEmail,
        tin,
        vatNumber,
        fiscalDeviceId,
        currency,
        countryCode,
        locale,
        autoPrint,
        showPrintDialog,
        paperWidth,
        fontSize,
        printQr,
        printBarcode,
      );
}
