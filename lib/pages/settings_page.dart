import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/printing_service.dart';
import '../services/backup_service.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';
import '../database/database_service.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback openReceipt;

  const SettingsPage({super.key, required this.openReceipt});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _activeTab = 'Backup & recovery';
  bool _autoBackupEnabled = true;

  BackupConfig? _backupConfig;
  bool _isPerformingBackup = false;
  String? _backupMessage;
  bool _isBackupError = false;
  List<BackupFileInfo> _backupHistory = [];

  static const List<String> tabs = [
    'Business profile',
    'Cost recipes',
    'Backup & recovery',
    'Thermal printing',
    'Users & permissions',
  ];

  // --- Production Costing & Yield Standards State ---
  late final TextEditingController _batchSizeController;
  late final TextEditingController _electricityCostController;
  late final TextEditingController _laborCostController;
  late final TextEditingController _packagingWasteController;
  late final TextEditingController _targetMarginController;
  String _pricingBasis = 'FIFO (First-In, First-Out)';

  // --- Business Profile State ---
  late final TextEditingController _factoryNameController;
  late final TextEditingController _ntnController;
  late final TextEditingController _strnController;
  late final TextEditingController _permitController;
  late final TextEditingController _addressController;
  late final TextEditingController _directorController;
  late final TextEditingController _phoneController;

  // --- Thermal Printing State ---
  late final TextEditingController _receiptCopiesController;
  String _defaultPrinter = 'Xprinter XP-Q200';
  String _paperWidth = '80 mm';
  String _textSize = 'Standard';

  final List<Map<String, dynamic>> _staffUsers = [
    {
      'name': 'Adnan Khan',
      'role': 'Managing Director',
      'access': 'Administrator (Full Access)',
      'status': 'Active Now',
      'tone': BadgeTone.green,
    },
    {
      'name': 'Muhammad Tariq',
      'role': 'Shift Supervisor',
      'access': 'Operations & Production',
      'status': 'Logged In',
      'tone': BadgeTone.blue,
    },
    {
      'name': 'Bilal Ahmed',
      'role': 'Cashier & Sales',
      'access': 'POS & Cash Reconciliation',
      'status': 'Active Now',
      'tone': BadgeTone.green,
    },
  ];

  void _openAddStaffDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StaffUserDialog(
        onSave: (data) {
          setState(() {
            _staffUsers.add({
              'name': data['name'],
              'role': data['role'],
              'access': data['access'],
              'status': data['status'] ?? 'Active Now',
              'tone': data['status'] == 'Suspended' ? BadgeTone.red : BadgeTone.green,
            });
          });
          AppToast.showSuccess(context, 'Staff account created for ${data['name']}');
        },
      ),
    );
  }

  void _openEditStaffDialog(int index) {
    final user = _staffUsers[index];
    showDialog(
      context: context,
      builder: (ctx) => StaffUserDialog(
        initialData: user,
        onSave: (data) {
          setState(() {
            _staffUsers[index] = {
              'name': data['name'],
              'role': data['role'],
              'access': data['access'],
              'status': data['status'] ?? user['status'],
              'tone': data['status'] == 'Suspended' ? BadgeTone.red : BadgeTone.green,
            };
          });
          AppToast.showSuccess(context, 'Staff account updated for ${data['name']}');
        },
      ),
    );
  }

  void _deleteStaffUser(int index) {
    final user = _staffUsers[index];
    if (user['access'] == 'Administrator (Full Access)') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Action Not Permitted', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: const Text(
            'The primary factory administrator account cannot be deleted. This protects system ownership and master terminal access.',
            style: TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Terminal Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to remove ${user['name']} (${user['role']})? They will immediately lose access to all factory POS and terminal features.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _staffUsers.removeAt(index);
              });
              AppToast.showSuccess(context, 'Account for ${user['name']} revoked successfully.');
            },
            child: const Text('Revoke Access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadBackupSettings();
    _loadPersistentSettings();
  }

  void _initControllers() {
    _batchSizeController = TextEditingController(text: '1000');
    _electricityCostController = TextEditingController(text: '48.50');
    _laborCostController = TextEditingController(text: '1200');
    _packagingWasteController = TextEditingController(text: '1.5');
    _targetMarginController = TextEditingController(text: '16.0');

    _factoryNameController = TextEditingController(text: 'Anwar Salt Factory (Pvt) Ltd');
    _ntnController = TextEditingController(text: '4182904-7');
    _strnController = TextEditingController(text: '32-77-8761-234-9');
    _permitController = TextEditingController(text: 'ML-2024-KHW-89');
    _addressController = TextEditingController(text: 'Plot 42-B, Industrial Estate, Jamrud Road, Peshawar, KPK');
    _directorController = TextEditingController(text: 'Adnan Khan');
    _phoneController = TextEditingController(text: '+92 91 5824901 / +92 300 859 1042');

    _receiptCopiesController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _batchSizeController.dispose();
    _electricityCostController.dispose();
    _laborCostController.dispose();
    _packagingWasteController.dispose();
    _targetMarginController.dispose();

    _factoryNameController.dispose();
    _ntnController.dispose();
    _strnController.dispose();
    _permitController.dispose();
    _addressController.dispose();
    _directorController.dispose();
    _phoneController.dispose();

    _receiptCopiesController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistentSettings() async {
    try {
      final all = await DatabaseService.instance.getAllSettings();
      if (!mounted || all.isEmpty) return;
      setState(() {
        if (all.containsKey('costing_batch_size')) _batchSizeController.text = all['costing_batch_size']!;
        if (all.containsKey('costing_electricity_rate')) _electricityCostController.text = all['costing_electricity_rate']!;
        if (all.containsKey('costing_labor_rate')) _laborCostController.text = all['costing_labor_rate']!;
        if (all.containsKey('costing_packaging_waste')) _packagingWasteController.text = all['costing_packaging_waste']!;
        if (all.containsKey('costing_target_margin')) _targetMarginController.text = all['costing_target_margin']!;
        if (all.containsKey('costing_pricing_basis')) _pricingBasis = all['costing_pricing_basis']!;

        if (all.containsKey('profile_factory_name')) _factoryNameController.text = all['profile_factory_name']!;
        if (all.containsKey('profile_ntn')) _ntnController.text = all['profile_ntn']!;
        if (all.containsKey('profile_strn')) _strnController.text = all['profile_strn']!;
        if (all.containsKey('profile_permit')) _permitController.text = all['profile_permit']!;
        if (all.containsKey('profile_address')) _addressController.text = all['profile_address']!;
        if (all.containsKey('profile_director')) _directorController.text = all['profile_director']!;
        if (all.containsKey('profile_phone')) _phoneController.text = all['profile_phone']!;

        if (all.containsKey('print_receipt_copies')) _receiptCopiesController.text = all['print_receipt_copies']!;
        if (all.containsKey('print_default_printer')) _defaultPrinter = all['print_default_printer']!;
        if (all.containsKey('print_paper_width')) _paperWidth = all['print_paper_width']!;
        if (all.containsKey('print_text_size')) _textSize = all['print_text_size']!;
      });
    } catch (_) {}
  }

  Future<void> _saveCostingSettings() async {
    final batchSize = _batchSizeController.text.trim();
    final elec = _electricityCostController.text.trim();
    final labor = _laborCostController.text.trim();
    final waste = _packagingWasteController.text.trim();
    final margin = _targetMarginController.text.trim();

    if (batchSize.isEmpty || elec.isEmpty || labor.isEmpty || waste.isEmpty || margin.isEmpty) {
      AppToast.showError(context, 'Please fill in all costing parameters before saving.');
      return;
    }

    try {
      await DatabaseService.instance.setSettings({
        'costing_batch_size': batchSize,
        'costing_electricity_rate': elec,
        'costing_labor_rate': labor,
        'costing_packaging_waste': waste,
        'costing_target_margin': margin,
        'costing_pricing_basis': _pricingBasis,
      });

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'Production costing parameters updated & permanently saved to database.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to save costing settings: $e');
    }
  }

  void _resetCostingDefaults() {
    setState(() {
      _batchSizeController.text = '1000';
      _electricityCostController.text = '48.50';
      _laborCostController.text = '1200';
      _packagingWasteController.text = '1.5';
      _targetMarginController.text = '16.0';
      _pricingBasis = 'FIFO (First-In, First-Out)';
    });
    AppToast.showInfo(context, 'Reset to factory baseline defaults. Click Update to save.');
  }

  Future<void> _saveBusinessProfile() async {
    final factory = _factoryNameController.text.trim();
    if (factory.isEmpty) {
      AppToast.showError(context, 'Factory Legal Name cannot be empty.');
      return;
    }

    try {
      await DatabaseService.instance.setSettings({
        'profile_factory_name': factory,
        'profile_ntn': _ntnController.text.trim(),
        'profile_strn': _strnController.text.trim(),
        'profile_permit': _permitController.text.trim(),
        'profile_address': _addressController.text.trim(),
        'profile_director': _directorController.text.trim(),
        'profile_phone': _phoneController.text.trim(),
      });

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'Factory commercial profile updated & saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to save business profile: $e');
    }
  }

  Future<void> _saveThermalPrintingSettings() async {
    try {
      await DatabaseService.instance.setSettings({
        'print_receipt_copies': _receiptCopiesController.text.trim(),
        'print_default_printer': _defaultPrinter,
        'print_paper_width': _paperWidth,
        'print_text_size': _textSize,
      });
      if (!mounted) return;
      AppToast.showSuccess(context, 'Thermal printing configuration saved successfully.');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to save printer settings: $e');
    }
  }

  Future<void> _loadBackupSettings() async {
    try {
      final cfg = await BackupService.instance.loadConfig();
      final hist = await BackupService.instance.getBackupHistory();
      if (mounted) {
        setState(() {
          _backupConfig = cfg;
          _autoBackupEnabled = cfg.enabled;
          _backupHistory = hist;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: 'Settings',
      subtitle: 'Configure business rules, printing, protection and access.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;
          final navWidget = _buildSettingsNav();
          final bodyWidget = _buildSettingsBody();

          if (isCompact) {
            return Column(
              children: [
                navWidget,
                const SizedBox(height: 12),
                bodyWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 210, child: navWidget),
              const SizedBox(width: 12),
              Expanded(child: bodyWidget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsNav() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: tabs.map((t) {
          final active = _activeTab == t;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = t),
              child: Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFEDF4FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        t,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? AppColors.brandPrimary : const Color(0xFF647084),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Opacity(
                      opacity: 0.5,
                      child: AppIcons.icon('arrow', size: 13, color: active ? AppColors.brandPrimary : const Color(0xFF647084)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsBody() {
    if (_activeTab == 'Business profile') {
      return _buildBusinessProfileSection();
    }
    if (_activeTab == 'Cost recipes') {
      return _buildCostRecipesSection();
    }
    if (_activeTab == 'Users & permissions') {
      return _buildUsersSection();
    }
    if (_activeTab == 'Thermal printing') {
      return _buildThermalPrintingSection();
    }
    // Default to Backup & recovery
    return Column(
      children: [
        _buildBackupConfigSection(),
        const SizedBox(height: 12),
        _buildBackupStatusSection(),
      ],
    );
  }

  Widget _buildBackupConfigSection() {
    final cfg = _backupConfig ??
        const BackupConfig(backupDirectory: r'D:\Salt Factory Backups');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: AppIcons.icon('download', size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Automatic backups',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Transactionally verified SQLite snapshots with active write protection.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                    ),
                  ],
                ),
              ),
              // Toggle
              GestureDetector(
                onTap: () async {
                  final newEnabled = !_autoBackupEnabled;
                  setState(() => _autoBackupEnabled = newEnabled);
                  final updated = cfg.copyWith(enabled: newEnabled);
                  await BackupService.instance.saveConfig(updated);
                  setState(() => _backupConfig = updated);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _autoBackupEnabled ? AppColors.primary : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: _autoBackupEnabled ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFF777799), blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Destination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BACKUP DESTINATION',
                        style: TextStyle(fontSize: 8, color: Color(0xFF7C8798), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cfg.backupDirectory,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Store backups on an external drive or secondary disk to protect against hardware failure.',
                        style: TextStyle(fontSize: 8, color: Color(0xFFA06A27)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Change folder',
                  variant: ButtonVariant.secondary,
                  onClick: _showChangeFolderDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Settings Grid (2 columns)
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'Schedule',
                  cfg.schedule,
                  ['Daily', 'Weekly', 'Manual'],
                  onChanged: (val) async {
                    if (val != null) {
                      final updated = cfg.copyWith(schedule: val);
                      await BackupService.instance.saveConfig(updated);
                      setState(() => _backupConfig = updated);
                    }
                  },
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _buildDropdownField(
                  'Retention policy',
                  '${cfg.retentionCount} backups',
                  ['7 backups', '15 backups', '30 backups'],
                  onChanged: (val) async {
                    if (val != null) {
                      final count = int.tryParse(val.split(' ').first) ?? 15;
                      final updated = cfg.copyWith(retentionCount: count);
                      await BackupService.instance.saveConfig(updated);
                      setState(() => _backupConfig = updated);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'On normal app close',
                  cfg.backupOnShutdown ? 'Enabled' : 'Disabled',
                  ['Enabled', 'Disabled'],
                  onChanged: (val) async {
                    if (val != null) {
                      final updated = cfg.copyWith(backupOnShutdown: val == 'Enabled');
                      await BackupService.instance.saveConfig(updated);
                      setState(() => _backupConfig = updated);
                    }
                  },
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _buildInputField(
                  'Scheduled time',
                  cfg.backupTime,
                  onChanged: (val) async {
                    final updated = cfg.copyWith(backupTime: val);
                    await BackupService.instance.saveConfig(updated);
                    _backupConfig = updated;
                  },
                ),
              ),
            ],
          ),

          // High-priority Reliability & Power Loss Notice
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFF59E0B).withAlpha(120)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcons.icon('warning', size: 15, color: const Color(0xFFD97706)),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Reliability Notice: Normal shutdown backups only execute during clean, orderly application exits. Sudden power cuts, electrical outages, operating-system crashes (BSOD), or forced termination via Task Manager cannot trigger shutdown hooks. Automated scheduled backups and external media replication remain essential for enterprise disaster recovery.',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF92400E),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupStatusSection() {
    final hasHistory = _backupHistory.isNotEmpty;
    final latestBackup = hasHistory ? _backupHistory.first : null;
    final isVerified = latestBackup != null && latestBackup.isValid;

    String statusTitle;
    String statusSubtitle;
    String timeAgo = '';

    if (latestBackup != null) {
      statusTitle = isVerified
          ? 'Latest backup verified 100% consistent'
          : 'Backup verification issue detected';
      statusSubtitle = '${latestBackup.fileName} • ${latestBackup.formattedSize}';
      final diff = DateTime.now().difference(latestBackup.createdAt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    } else {
      statusTitle = 'No automated backup recorded yet';
      statusSubtitle = 'Click "Back up now" to create your first verified snapshot.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isVerified ? AppColors.greenBg : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIcons.icon(
                  isVerified ? 'check' : 'warning',
                  size: 16,
                  color: isVerified ? AppColors.green : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              if (timeAgo.isNotEmpty)
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF8993A3)),
                ),
            ],
          ),

          if (_backupMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isBackupError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _backupMessage!,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: _isBackupError ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                ),
              ),
            ),
          ],

          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                AppButton(
                  label: _isPerformingBackup ? 'Backing up...' : 'Back up now',
                  icon: 'download',
                  variant: ButtonVariant.primary,
                  onClick: _isPerformingBackup ? () {} : _triggerManualBackup,
                ),
                const SizedBox(width: 7),
                AppButton(
                  label: 'Open backup folder',
                  variant: ButtonVariant.secondary,
                  onClick: _openBackupFolder,
                ),
                const SizedBox(width: 7),
                AppButton(
                  label: 'Restore backup',
                  variant: ButtonVariant.ghost,
                  onClick: _showRestoreDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualBackup() async {
    setState(() {
      _isPerformingBackup = true;
      _backupMessage = null;
      _isBackupError = false;
    });

    final result = await BackupService.instance.createBackup(reason: 'Manual backup trigger from settings');
    final hist = await BackupService.instance.getBackupHistory();
    final cfg = await BackupService.instance.loadConfig();

    if (mounted) {
      setState(() {
        _isPerformingBackup = false;
        _backupConfig = cfg;
        _backupHistory = hist;
        _backupMessage = result.message;
        _isBackupError = !result.success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openBackupFolder() async {
    final dirPath = _backupConfig?.backupDirectory ?? await BackupService.instance.getDefaultBackupDirectory();
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dirPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dirPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dirPath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open folder: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showChangeFolderDialog() {
    final controller = TextEditingController(
      text: _backupConfig?.backupDirectory ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change Backup Folder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter an absolute folder path on this computer or an external drive:',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              _ErpFormField(
                label: 'Folder Path',
                controller: controller,
                hintText: r'D:\Salt Factory Backups',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPath = controller.text.trim();
                if (newPath.isNotEmpty) {
                  final updated = _backupConfig?.copyWith(backupDirectory: newPath) ??
                      BackupConfig(backupDirectory: newPath);
                  await BackupService.instance.saveConfig(updated);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  await _loadBackupSettings();
                }
              },
              child: const Text('Save Folder'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog() async {
    final history = await BackupService.instance.getBackupHistory();
    if (!mounted) return;

    if (history.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Backups Found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: const Text(
            'There are no valid backup files (.db) in the configured destination folder to restore from.',
            style: TextStyle(fontSize: 11),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    BackupFileInfo? selected = history.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Restore Database Backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a verified backup file to restore. All active database locks will be coordinated, and a safety rollback snapshot of the current database will be created before replacement.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    const Text('Available Backups:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: history.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = history[idx];
                          final isSelected = selected == item;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryLight.withAlpha(50),
                            title: Text(
                              item.fileName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${item.formattedDate} • ${item.formattedSize} • ${item.integrityStatus}',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: item.isValid ? AppColors.green : AppColors.danger,
                              ),
                            ),
                            leading: Icon(
                              item.isValid ? Icons.check_circle : Icons.error,
                              size: 16,
                              color: item.isValid ? AppColors.green : AppColors.danger,
                            ),
                            onTap: () {
                              setModalState(() => selected = item);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber, size: 16, color: Color(0xFFB91C1C)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: Restoring replaces current transactions with the snapshot state. If restore fails, the pre-restore rollback snapshot preserves your current data.',
                              style: TextStyle(fontSize: 8.5, color: Color(0xFF7F1D1D), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: selected == null || !selected!.isValid
                      ? null
                      : () async {
                          final targetPath = selected!.filePath;
                          Navigator.pop(ctx);
                          _executeRestore(targetPath);
                        },
                  child: const Text('Restore Database', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeRestore(String backupPath) async {
    setState(() {
      _isPerformingBackup = true;
      _backupMessage = 'Restoring database snapshot...';
      _isBackupError = false;
    });

    final res = await BackupService.instance.restoreBackup(backupPath);
    await _loadBackupSettings();

    if (mounted) {
      setState(() {
        _isPerformingBackup = false;
        _backupMessage = res.message;
        _isBackupError = !res.success;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            res.success ? 'Restore Succeeded' : 'Restore Alert',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: res.success ? AppColors.green : AppColors.danger,
            ),
          ),
          content: Text(res.message, style: const TextStyle(fontSize: 11)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildThermalPrintingSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: AppIcons.icon('print', size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Thermal printer',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Printer capabilities are detected before each job.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                    ),
                  ],
                ),
              ),
              const AppBadge(label: 'Connected', tone: BadgeTone.green),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'Default printer',
                  _defaultPrinter,
                  ['Xprinter XP-Q200', 'Virtual PDF Export'],
                  onChanged: (val) {
                    if (val != null) setState(() => _defaultPrinter = val);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDropdownField(
                  'Paper width',
                  _paperWidth,
                  ['80 mm', '58 mm'],
                  onChanged: (val) {
                    if (val != null) setState(() => _paperWidth = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Receipt copies',
                  controller: _receiptCopiesController,
                  suffixText: 'copies',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDropdownField(
                  'Text size',
                  _textSize,
                  ['Standard', 'Large'],
                  onChanged: (val) {
                    if (val != null) setState(() => _textSize = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                AppButton(
                  label: 'Test print',
                  icon: 'print',
                  variant: ButtonVariant.primary,
                  onClick: widget.openReceipt,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Printer diagnostics',
                  variant: ButtonVariant.secondary,
                  onClick: () async {
                    final printers = await PrintingService.instance.getAvailablePrinters();
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Printer Diagnostics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              printers.isEmpty
                                  ? 'No hardware thermal printers found on this machine.'
                                  : 'Detected ${printers.length} printer(s):',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            ...printers.map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('• ${p.name} ${p.isDefault ? "(Default)" : ""}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                )),
                            const SizedBox(height: 12),
                            const Text(
                              'Fallback: Virtual PDF Export is fully operational.',
                              style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(),
                AppButton(
                  label: 'Save Configuration',
                  icon: 'check',
                  variant: ButtonVariant.primary,
                  onClick: _saveThermalPrintingSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessProfileSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: AppIcons.icon('factory', size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Factory Legal & Commercial Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Official commercial credentials printed on sales receipts, tax invoices and transport manifests',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const AppBadge(label: 'Verified Entity', tone: BadgeTone.green),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Factory Legal Name',
                  controller: _factoryNameController,
                  hintText: 'e.g. Anwar Salt Factory (Pvt) Ltd',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControllerField(
                  label: 'NTN / Tax Registration Number',
                  controller: _ntnController,
                  hintText: 'e.g. 4182904-7',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Sales Tax STRN',
                  controller: _strnController,
                  hintText: 'e.g. 32-77-8761-234-9',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControllerField(
                  label: 'Salt Mine Reserve Permit',
                  controller: _permitController,
                  hintText: 'e.g. ML-2024-KHW-89',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildControllerField(
            label: 'Factory Site Address',
            controller: _addressController,
            hintText: 'Plot, Industrial Area, City, Province',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Managing Director',
                  controller: _directorController,
                  hintText: 'Full Name',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControllerField(
                  label: 'Factory Contact Phone',
                  controller: _phoneController,
                  hintText: 'e.g. +92 91 5824901',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Save Profile Changes',
              icon: 'check',
              variant: ButtonVariant.primary,
              onClick: _saveBusinessProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRecipesSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.violetBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: AppIcons.icon('box', size: 20, color: AppColors.violet),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Production Costing & Yield Standards',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Configures electricity tariffs, shift labor allocation and expected packaging waste for batches',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const AppBadge(label: 'Auto-Calibrated', tone: BadgeTone.blue),
            ],
          ),
          const SizedBox(height: 16),
          // Informative Context Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Standard costing parameters automatically allocate direct overheads to finished salt products during batch creation and maintain accurate gross margins.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Standard Batch Size (kg)',
                  controller: _batchSizeController,
                  suffixText: 'kg (1 Tonne)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControllerField(
                  label: 'Electricity Allocation per Batch',
                  controller: _electricityCostController,
                  prefixText: 'Rs',
                  suffixText: '/ kWh',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Labor Allocation per Shift',
                  controller: _laborCostController,
                  prefixText: 'Rs',
                  suffixText: '/ Line Worker',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControllerField(
                  label: 'Packaging Waste Allowance',
                  controller: _packagingWasteController,
                  suffixText: '% Tolerance',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControllerField(
                  label: 'Target Gross Margin Threshold',
                  controller: _targetMarginController,
                  suffixText: '% Target',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  'Default Pricing Basis',
                  _pricingBasis,
                  [
                    'FIFO (First-In, First-Out)',
                    'Weighted Average Cost (AVCO)',
                    'Standard Costing Model',
                    'LIFO (Last-In, First-Out)',
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _pricingBasis = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Reset Defaults',
                icon: 'rotate',
                variant: ButtonVariant.secondary,
                onClick: _resetCostingDefaults,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Update Costing Parameters',
                icon: 'check',
                variant: ButtonVariant.primary,
                onClick: _saveCostingSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: AppIcons.icon('users', size: 18, color: AppColors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Authorized Factory Users & Terminals',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Staff permissions for Windows desktop terminals and cash registers',
                            style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'Add staff user',
                icon: 'plus',
                variant: ButtonVariant.primary,
                onClick: _openAddStaffDialog,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  color: AppColors.tableHeaderBg,
                  border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
                ),
                children: [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('NAME & DESIGNATION', style: AppTypography.tableHeader)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ACCESS LEVEL', style: AppTypography.tableHeader)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('TERMINAL STATUS', style: AppTypography.tableHeader)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ACTIONS', style: AppTypography.tableHeader)),
                ],
              ),
              ..._staffUsers.asMap().entries.map((entry) => _buildUserRow(entry.key, entry.value)),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildUserRow(int index, Map<String, dynamic> user) {
    final name = user['name'] as String;
    final role = user['role'] as String;
    final access = user['access'] as String;
    final status = user['status'] as String;
    final tone = user['tone'] as BadgeTone? ?? BadgeTone.green;

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(role, style: const TextStyle(fontSize: 9.5, color: AppColors.textSubtle)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(access, style: AppTypography.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(label: status, tone: tone),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _openEditStaffDialog(index),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Edit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                tooltip: 'More actions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 150),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openEditStaffDialog(index);
                  } else if (val == 'delete') {
                    _deleteStaffUser(index);
                  } else if (val == 'toggle_status') {
                    setState(() {
                      final isSuspended = user['status'] == 'Suspended';
                      user['status'] = isSuspended ? 'Active Now' : 'Suspended';
                      user['tone'] = isSuspended ? BadgeTone.green : BadgeTone.red;
                    });
                    AppToast.showSuccess(
                      context,
                      '${user['name']} account status changed to ${user['status']}',
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    height: 32,
                    child: Text('Edit permissions', style: TextStyle(fontSize: 11)),
                  ),
                  PopupMenuItem(
                    value: 'toggle_status',
                    height: 32,
                    child: Text(
                      user['status'] == 'Suspended' ? 'Reactivate account' : 'Suspend terminal access',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 32,
                    child: Text('Revoke account', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControllerField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return _ErpFormField(
      label: label,
      controller: controller,
      hintText: hintText,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly,
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options, {
    ValueChanged<String?>? onChanged,
  }) {
    return _ErpDropdownField(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }

  Widget _buildInputField(
    String label,
    String value, {
    ValueChanged<String>? onChanged,
    String? hintText,
    String? prefixText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return _ErpFormField(
      label: label,
      initialValue: value,
      hintText: hintText,
      prefixText: prefixText,
      suffixText: suffixText,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }
}

class _ErpFormField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const _ErpFormField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  State<_ErpFormField> createState() => _ErpFormFieldState();
}

class _ErpFormFieldState extends State<_ErpFormField> {
  bool _isHovered = false;
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isFocused
        ? AppColors.brandPrimary
        : (_isHovered ? const Color(0xFF64748B) : const Color(0xFFD0D5DD));

    final borderWidth = _isFocused ? 1.5 : 1.0;

    final boxShadow = _isFocused
        ? const [
            BoxShadow(
              color: Color(0x282563EB),
              blurRadius: 6,
              spreadRadius: 1.5,
              offset: Offset(0, 1),
            ),
          ]
        : (_isHovered
            ? const [
                BoxShadow(
                  color: Color(0x0E0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x050F172A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _isFocused ? AppColors.brandPrimary : const Color(0xFF344054),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          cursor: widget.readOnly ? SystemMouseCursors.basic : SystemMouseCursors.text,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: 44,
            decoration: BoxDecoration(
              color: widget.readOnly
                  ? const Color(0xFFF8FAFC)
                  : (_isHovered ? const Color(0xFFFDFEFE) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: boxShadow,
            ),
            child: TextFormField(
              controller: widget.controller,
              initialValue: widget.controller == null ? widget.initialValue : null,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1D2939),
              ),
              cursorColor: AppColors.brandPrimary,
              cursorHeight: 18,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.only(
                  left: widget.prefixIcon != null ? 0 : 14,
                  right: 14,
                  top: 12,
                  bottom: 12,
                ),
                prefixIcon: widget.prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: widget.prefixIcon,
                      )
                    : null,
                prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                prefixText: widget.prefixText != null ? '${widget.prefixText} ' : null,
                prefixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isFocused ? AppColors.brandPrimary : const Color(0xFF475467),
                ),
                suffixText: widget.suffixText,
                suffixStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF667085),
                ),
                hintText: widget.hintText,
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErpDropdownField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  const _ErpDropdownField({
    required this.label,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  State<_ErpDropdownField> createState() => _ErpDropdownFieldState();
}

class _ErpDropdownFieldState extends State<_ErpDropdownField> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final validValue = widget.options.contains(widget.value) ? widget.value : widget.options.first;
    final borderColor = _isHovered ? const Color(0xFF64748B) : const Color(0xFFD0D5DD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFFDFEFE) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: _isHovered
                  ? const [
                      BoxShadow(
                        color: Color(0x0E0F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x050F172A),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
            alignment: Alignment.centerLeft,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  child: AppIcons.icon(
                    'arrow',
                    size: 14,
                    color: _isHovered ? AppColors.brandPrimary : const Color(0xFF667085),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1D2939),
                ),
                items: widget.options
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
