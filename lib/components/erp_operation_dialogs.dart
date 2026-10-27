import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/erp_models.dart';
import '../repositories/erp_transaction_repository.dart';
import '../services/printing_service.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

// ============================================================================
// 1. USER & OWNER PROFILE DIALOG
// ============================================================================

class UserProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialRole;
  final ValueChanged<Map<String, String>> onSave;

  const UserProfileDialog({
    super.key,
    this.initialName = 'Adnan Khan',
    this.initialRole = 'Owner & Managing Director',
    required this.onSave,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _roleController;
  late TextEditingController _branchController;
  late TextEditingController _currentPinController;
  late TextEditingController _newPinController;
  late TextEditingController _confirmPinController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: 'adnan.khan@anwarsalt.com');
    _phoneController = TextEditingController(text: '+92 300 9876543');
    _roleController = TextEditingController(text: widget.initialRole);
    _branchController = TextEditingController(text: 'Anwar Salt Factory (Pvt) Ltd • Plot 14, Industrial Estate, Peshawar');
    _currentPinController = TextEditingController();
    _newPinController = TextEditingController();
    _confirmPinController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _branchController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handleSaveProfile() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Profile name cannot be blank.');
      return;
    }
    setState(() => _isSaving = true);

    widget.onSave({
      'name': _nameController.text.trim(),
      'role': _roleController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
    });

    Navigator.of(context).pop(true);
  }

  void _handleUpdatePin() {
    if (_newPinController.text.length < 4) {
      setState(() => _errorMessage = 'New PIN must be at least 4 digits.');
      return;
    }
    if (_newPinController.text != _confirmPinController.text) {
      setState(() => _errorMessage = 'New PIN and Confirmation PIN do not match.');
      return;
    }
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        AppToast.showSuccess(context, 'Terminal security PIN updated successfully.');
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.96, end: 1.0),
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 580,
              constraints: const BoxConstraints(maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppColors.radius),
                boxShadow: AppColors.shadowLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'AK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.isNotEmpty ? _nameController.text : 'User Profile',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _roleController.text.isNotEmpty ? _roleController.text : 'Factory Management',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.brandPrimary,
                      indicatorWeight: 2.5,
                      labelColor: AppColors.brandPrimary,
                      unselectedLabelColor: AppColors.textMuted,
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Profile Information'),
                        Tab(text: 'Terminal Security & PIN'),
                      ],
                    ),
                  ),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.danger.withAlpha(50)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11, color: AppColors.dangerText, fontWeight: FontWeight.w600),
                      ),
                    ),

                  // Tab Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Profile Info
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildInputField('Full Name', _nameController, Icons.person_outline),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInputField('Official Email', _emailController, Icons.email_outlined),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInputField('Phone / WhatsApp', _phoneController, Icons.phone_outlined),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildInputField('Position / Role Title', _roleController, Icons.badge_outlined),
                                const SizedBox(height: 12),
                                _buildInputField('Assigned Factory / Branch', _branchController, Icons.business_outlined, readOnly: true),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.verified_user_outlined, size: 16, color: AppColors.brandPrimary),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Administrator Role • Unrestricted access to General Ledger, Backup, and System Configuration.',
                                          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Tab 2: Security & PIN
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Terminal Quick-Switch PIN',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Use a 4 to 6 digit numerical PIN to authorize critical actions and switch cash register sessions.',
                                  style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 16),
                                _buildInputField('Current Terminal PIN', _currentPinController, Icons.lock_outline, isPassword: true),
                                const SizedBox(height: 12),
                                _buildInputField('New 4-Digit PIN', _newPinController, Icons.pin_outlined, isPassword: true),
                                const SizedBox(height: 12),
                                _buildInputField('Confirm New PIN', _confirmPinController, Icons.check_circle_outline, isPassword: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Dialog Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          label: 'Cancel',
                          variant: ButtonVariant.secondary,
                          onClick: () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          label: _isSaving ? 'Saving...' : 'Save changes',
                          icon: 'check',
                          variant: ButtonVariant.primary,
                          onClick: () {
                            if (_tabController.index == 0) {
                              _handleSaveProfile();
                            } else {
                              _handleUpdatePin();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
    bool readOnly = false,
  }) {
    return ErpFormField(
      label: label,
      controller: controller,
      prefixIcon: icon,
      obscureText: isPassword,
      readOnly: readOnly,
    );
  }
}

// ============================================================================
// 2. STAFF USER FORM DIALOG (SETTINGS)
// ============================================================================

class StaffUserDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onSave;

  const StaffUserDialog({
    super.key,
    this.initialData,
    required this.onSave,
  });

  @override
  State<StaffUserDialog> createState() => _StaffUserDialogState();
}

class _StaffUserDialogState extends State<StaffUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late String _accessLevel;
  late String _status;

  final List<String> _accessLevels = [
    'Administrator (Full Access)',
    'Operations & Production',
    'POS & Cash Reconciliation',
    'Auditor & Read-Only',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d?['name'] ?? '');
    _roleController = TextEditingController(text: d?['role'] ?? '');
    _accessLevel = d?['access'] ?? _accessLevels.first;
    _status = d?['status'] ?? 'Active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    widget.onSave({
      'name': _nameController.text.trim(),
      'role': _roleController.text.trim(),
      'access': _accessLevel,
      'status': _status,
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialData != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Staff Terminal Access' : 'Add Staff Member',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ErpFormField(
                    label: 'Full Name',
                    controller: _nameController,
                    hint: 'e.g. Tariq Mehmood',
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Designation / Job Title',
                    controller: _roleController,
                    hint: 'e.g. Shift Incharge / Packaging',
                  ),
                  const SizedBox(height: 12),
                  ErpDropdownField<String>(
                    label: 'Permission Tier',
                    value: _accessLevel,
                    items: _accessLevels,
                    onChanged: (val) {
                      if (val != null) setState(() => _accessLevel = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Terminal Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 5),
                  Row(
                    children: ['Active', 'Suspended', 'Off Shift'].map((s) {
                      final isSelected = _status == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          selected: isSelected,
                          selectedColor: AppColors.brandLight,
                          onSelected: (_) => setState(() => _status = s),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: isEdit ? 'Update staff' : 'Save staff member',
                    variant: ButtonVariant.primary,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PRODUCT FORM DIALOG (PRODUCTS & UNITS)
// ============================================================================

class ProductFormDialog extends StatefulWidget {
  final List<String>? initialRow;
  final ValueChanged<List<String>> onSave;

  const ProductFormDialog({
    super.key,
    this.initialRow,
    required this.onSave,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _conversionController;
  late TextEditingController _stockController;
  late String _type;
  late String _baseUnit;
  late String _status;

  late final List<String> _types;
  late final List<String> _units;
  late final List<String> _statuses;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRow;
    _types = ['Finished goods', 'Raw salt', 'Packaging', 'Finished product', 'Raw material'];
    final incomingType = r != null ? r[2] : _types.first;
    if (!_types.contains(incomingType)) {
      _types.add(incomingType);
    }
    _type = incomingType;

    _units = ['Packet', 'Kilogram', 'Piece', 'Carton', 'Cotton', 'Bundle', 'Tonne'];
    final incomingUnit = r != null ? r[3] : _units.first;
    if (!_units.contains(incomingUnit)) {
      _units.add(incomingUnit);
    }
    _baseUnit = incomingUnit;

    _statuses = ['Active', 'Low stock', 'Archived', 'Suspended'];
    final incomingStatus = r != null ? r[6] : _statuses.first;
    if (!_statuses.contains(incomingStatus)) {
      _statuses.add(incomingStatus);
    }
    _status = incomingStatus;

    _nameController = TextEditingController(text: r != null ? r[0] : '');
    _codeController = TextEditingController(text: r != null ? r[1] : 'FG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    _conversionController = TextEditingController(text: r != null ? r[4] : '1 cotton = 24 packets = 19.2 kg');
    _stockController = TextEditingController(text: r != null ? r[5] : '1,000');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _conversionController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    widget.onSave([
      _nameController.text.trim(),
      _codeController.text.trim(),
      _type,
      _baseUnit,
      _conversionController.text.trim(),
      _stockController.text.trim(),
      _status,
    ]);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRow != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 540,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Product & Unit Specification' : 'Register New Product / Unit',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ErpFormField(
                          label: 'Product / Item Name',
                          controller: _nameController,
                          hint: 'e.g. HGM Pink Salt 800g × 24',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ErpFormField(
                          label: 'SKU / Code',
                          controller: _codeController,
                          hint: 'FG-080024',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Product Category',
                          value: _type,
                          items: _types,
                          onChanged: (val) {
                            if (val != null) setState(() => _type = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Base Stock Unit',
                          value: _baseUnit,
                          items: _units,
                          onChanged: (val) {
                            if (val != null) setState(() => _baseUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Packaging & Unit Conversion Formula',
                    controller: _conversionController,
                    hint: '1 cotton = 24 packets = 19.2 kg',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Starting Available Stock',
                          controller: _stockController,
                          hint: '0',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Stock Health Status',
                          value: _status,
                          items: _statuses,
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: isEdit ? 'Save product' : 'Create product',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. STOCK ADJUSTMENT DIALOG (STOCK MANAGEMENT)
// ============================================================================

class StockAdjustmentDialog extends StatefulWidget {
  final List<String> products;
  final String? initialProduct;
  final ValueChanged<Map<String, dynamic>> onSave;

  const StockAdjustmentDialog({
    super.key,
    required this.products,
    this.initialProduct,
    required this.onSave,
  });

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  late String _selectedProduct;
  late final List<String> _productList;
  late String _adjustmentType; // 'Surplus / Increase (+)' or 'Damaged / Wastage (-)'
  final TextEditingController _qtyController = TextEditingController(text: '100');
  final TextEditingController _costController = TextEditingController(text: '76.40');
  final TextEditingController _reasonController = TextEditingController(text: 'Physical stock count audit reconciliation');

  @override
  void initState() {
    super.initState();
    _productList = List<String>.from(widget.products);
    final init = widget.initialProduct;
    if (init != null && !_productList.contains(init)) {
      _productList.insert(0, init);
    }
    _selectedProduct = (init != null && _productList.contains(init))
        ? init
        : (_productList.isNotEmpty ? _productList.first : 'HGM Pink Salt 800g × 24');
    if (!_productList.contains(_selectedProduct)) {
      _productList.add(_selectedProduct);
    }
    _adjustmentType = 'Surplus / Increase (+)';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = double.tryParse(_qtyController.text.replaceAll(',', '')) ?? 0.0;
    final cost = double.tryParse(_costController.text.replaceAll(',', '')) ?? 0.0;
    if (qty <= 0) return;

    widget.onSave({
      'product': _selectedProduct,
      'isPositive': _adjustmentType.startsWith('Surplus'),
      'quantity': qty,
      'unitCost': cost,
      'reason': _reasonController.text.trim(),
      'notes': _reasonController.text.trim(),
      'date': DateTime.now().toIso8601String(),
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Record Stock Adjustment / Physical Audit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ErpDropdownField<String>(
                    label: 'Select Material / Product',
                    value: _selectedProduct,
                    items: _productList,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProduct = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Adjustment Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['Surplus / Increase (+)', 'Damaged / Wastage (-)'].map((t) {
                      final isSelected = _adjustmentType == t;
                      return ChoiceChip(
                        label: Text(t, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                        selected: isSelected,
                        selectedColor: t.contains('+') ? AppColors.greenBg : AppColors.redBg,
                        onSelected: (_) => setState(() => _adjustmentType = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Quantity Adjusted',
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpFormField(
                          label: 'Unit Valuation (Rs)',
                          controller: _costController,
                          keyboardType: TextInputType.number,
                          hint: '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Audit Reason / Notes',
                    controller: _reasonController,
                    maxLines: 2,
                    hint: 'Reason for physical inventory adjustment...',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Apply stock adjustment',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    onClick: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. PRODUCTION BATCH RECORDING DIALOG
// ============================================================================

class ProductionBatchDialog extends StatefulWidget {
  final List<String>? products;
  final String? initialProduct;
  final ValueChanged<Map<String, dynamic>> onSave;

  const ProductionBatchDialog({
    super.key,
    this.products,
    this.initialProduct,
    required this.onSave,
  });

  @override
  State<ProductionBatchDialog> createState() => _ProductionBatchDialogState();
}

class _ProductionBatchDialogState extends State<ProductionBatchDialog> {
  final TextEditingController _batchNoController = TextEditingController(
    text: 'PRD-0${(2648 + DateTime.now().minute).toString()}',
  );
  late String _shift;
  late String _finishedProduct;
  late final List<String> _productList;
  final TextEditingController _producedQtyController = TextEditingController(text: '600');
  final TextEditingController _rawSaltKgController = TextEditingController(text: '620');
  final TextEditingController _packetsUsedController = TextEditingController(text: '600');
  final TextEditingController _labourCostController = TextEditingController(text: '5400');
  final String _status = 'Verified';

  @override
  void initState() {
    super.initState();
    _productList = (widget.products != null && widget.products!.isNotEmpty)
        ? List<String>.from(widget.products!)
        : ['HGM Pink Salt 800g × 24', 'Fine White Salt 1kg', '50 kg Industrial Bag'];
    final init = widget.initialProduct;
    if (init != null && !_productList.contains(init)) {
      _productList.insert(0, init);
    }
    _finishedProduct = (init != null && _productList.contains(init))
        ? init
        : _productList.first;
    _shift = 'Morning Shift';
  }

  @override
  void dispose() {
    _batchNoController.dispose();
    _producedQtyController.dispose();
    _rawSaltKgController.dispose();
    _packetsUsedController.dispose();
    _labourCostController.dispose();
    super.dispose();
  }

  void _save() {
    final produced = double.tryParse(_producedQtyController.text) ?? 0.0;
    if (produced <= 0) return;

    widget.onSave({
      'batchNo': _batchNoController.text.trim(),
      'time': '26 Oct • $_shift',
      'product': _finishedProduct,
      'shift': _shift,
      'reported': _producedQtyController.text.trim(),
      'verified': _producedQtyController.text.trim(),
      'discrepancy': '0',
      'cost': 'Rs ${_labourCostController.text.trim()}',
      'rawSaltKg': double.tryParse(_rawSaltKgController.text) ?? 620.0,
      'packetsUsed': double.tryParse(_packetsUsedController.text) ?? 600.0,
      'labourCost': double.tryParse(_labourCostController.text) ?? 5400.0,
      'producedQty': produced,
      'status': _status,
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 540,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Record Finished Packaging & Production Batch',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Batch Identifier',
                          controller: _batchNoController,
                          hint: 'PRD-XXXXX',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Operating Shift',
                          value: _shift,
                          items: const [
                            'Morning Shift',
                            'Evening Shift',
                            'Night Shift',
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _shift = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpDropdownField<String>(
                    label: 'Finished Goods Manufactured',
                    value: _finishedProduct,
                    items: _productList,
                    onChanged: (val) {
                      if (val != null) setState(() => _finishedProduct = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Units Produced (Packets)',
                          controller: _producedQtyController,
                          keyboardType: TextInputType.number,
                          hint: '600',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpFormField(
                          label: 'Raw Salt Consumed (kg)',
                          controller: _rawSaltKgController,
                          keyboardType: TextInputType.number,
                          hint: '620',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Packaging Packets Used',
                          controller: _packetsUsedController,
                          keyboardType: TextInputType.number,
                          hint: '600',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpFormField(
                          label: 'Labour & Overhead (Rs)',
                          controller: _labourCostController,
                          keyboardType: TextInputType.number,
                          hint: '5400',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Submit production batch',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. COMMERCIAL TRANSACTION DIALOG (SALES & PURCHASES)
// ============================================================================

class TransactionEntryDialog extends StatefulWidget {
  final String type; // 'Sales' or 'Purchases'
  final List<String>? initialRow;
  final ValueChanged<List<String>> onSave;
  final void Function(Map<String, dynamic> data)? onSaveDetailed;

  const TransactionEntryDialog({
    super.key,
    required this.type,
    this.initialRow,
    required this.onSave,
    this.onSaveDetailed,
  });

  @override
  State<TransactionEntryDialog> createState() => _TransactionEntryDialogState();
}

class _TransactionEntryDialogState extends State<TransactionEntryDialog> {
  late TextEditingController _refController;
  late TextEditingController _partyController;
  late TextEditingController _itemController;
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late TextEditingController _paidController;
  late String _wallet;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  final List<String> _wallets = [
    'Cash in Hand',
    'UBL Bank',
    'EasyPaisa',
    'Cash in Hand — HGM Work',
    'Credit (Unpaid)',
  ];

  @override
  void initState() {
    super.initState();
    final isSales = widget.type == 'Sales';
    final r = widget.initialRow;

    _refController = TextEditingController(
      text: r != null ? r[0] : '${isSales ? "SAL" : "PUR"}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _partyController = TextEditingController(text: r != null ? r[2] : (isSales ? 'Al-Madina Traders' : 'Khewra Salt Co.'));
    _itemController = TextEditingController(text: isSales ? 'HGM Pink Salt 800g × 24' : 'Raw Pink Rock Salt');
    _qtyController = TextEditingController(text: '50');
    _rateController = TextEditingController(text: isSales ? '970' : '2520');
    _paidController = TextEditingController(text: r != null ? r[4].replaceAll(RegExp(r'[^0-9.]'), '') : '48500');
    _wallet = _wallets.first;
  }

  @override
  void dispose() {
    _refController.dispose();
    _partyController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  double get _total {
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    return qty * rate;
  }

  double get _paid => double.tryParse(_paidController.text.replaceAll(',', '')) ?? 0.0;
  double get _due => (_total - _paid).clamp(0.0, double.infinity);

  void _save() {
    if (_partyController.text.trim().isEmpty) return;
    final status = _due <= 0.01 ? 'Paid' : (_paid > 0 ? 'Partial' : (widget.type == 'Sales' ? 'Credit' : 'Unpaid'));

    final row = [
      _refController.text.trim(),
      DateFormat('dd MMM, hh:mm a').format(DateTime.now()),
      _partyController.text.trim(),
      'Rs ${_currencyFormat.format(_total)}',
      'Rs ${_currencyFormat.format(_paid)}',
      'Rs ${_currencyFormat.format(_due)}',
      status,
    ];

    widget.onSave(row);

    widget.onSaveDetailed?.call({
      'ref': _refController.text.trim(),
      'party': _partyController.text.trim(),
      'item': _itemController.text.trim(),
      'qty': double.tryParse(_qtyController.text) ?? 1.0,
      'rate': double.tryParse(_rateController.text) ?? 0.0,
      'total': _total,
      'paid': _paid,
      'due': _due,
      'wallet': _wallet,
      'status': status,
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSales = widget.type == 'Sales';
    final partyLabel = isSales ? 'Customer Account' : 'Supplier Account';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Record ${isSales ? "Sales Invoice" : "Purchase Voucher"}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Invoice / Reference #',
                          controller: _refController,
                          hint: 'SAL-XXXXX',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpFormField(
                          label: partyLabel,
                          controller: _partyController,
                          hint: 'Party name',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Product Item Description',
                    controller: _itemController,
                    hint: 'Product description',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Quantity',
                          controller: _qtyController,
                          hint: '1',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpFormField(
                          label: 'Unit Price (Rs)',
                          controller: _rateController,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Grand Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 5),
                            Container(
                              height: 38,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                              ),
                              child: Text(
                                'Rs ${_currencyFormat.format(_total)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: isSales ? 'Amount Received (Rs)' : 'Amount Paid (Rs)',
                          controller: _paidController,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Payment Wallet',
                          value: _wallets.contains(_wallet) ? _wallet : _wallets.first,
                          items: _wallets,
                          onChanged: (val) {
                            if (val != null) setState(() => _wallet = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _due > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _due > 0 ? AppColors.amber.withAlpha(50) : AppColors.green.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _due > 0 ? 'Remaining Balance (Receivable / Due):' : 'Full Payment Received:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _due > 0 ? AppColors.warningText : AppColors.successText),
                        ),
                        Text(
                          'Rs ${_currencyFormat.format(_due)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _due > 0 ? AppColors.warningText : AppColors.successText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Record & Post Transaction',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. WALLET TRANSFER DIALOG (CASH & WALLETS)
// ============================================================================

class WalletTransferDialog extends StatefulWidget {
  final List<String> walletNames;
  final ValueChanged<Map<String, dynamic>> onSave;

  const WalletTransferDialog({
    super.key,
    required this.walletNames,
    required this.onSave,
  });

  @override
  State<WalletTransferDialog> createState() => _WalletTransferDialogState();
}

class _WalletTransferDialogState extends State<WalletTransferDialog> {
  late String _fromWallet;
  late String _toWallet;
  final TextEditingController _amountController = TextEditingController(text: '20,000');
  final TextEditingController _notesController = TextEditingController(text: 'Daily cash deposit to bank / electronic wallet');

  @override
  void initState() {
    super.initState();
    _fromWallet = widget.walletNames.isNotEmpty ? widget.walletNames.first : 'Cash in Hand';
    _toWallet = widget.walletNames.length > 1 ? widget.walletNames[1] : 'EasyPaisa';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final amt = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    if (amt <= 0 || _fromWallet == _toWallet) return;

    widget.onSave({
      'from': _fromWallet,
      'to': _toWallet,
      'amount': amt,
      'notes': _notesController.text.trim(),
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inter-Wallet Transfer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Source Wallet (From)',
                          value: widget.walletNames.contains(_fromWallet) ? _fromWallet : widget.walletNames.first,
                          items: widget.walletNames,
                          onChanged: (val) {
                            if (val != null) setState(() => _fromWallet = val);
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 26, 8, 0),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.brandPrimary),
                      ),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Destination Wallet (To)',
                          value: widget.walletNames.contains(_toWallet) ? _toWallet : widget.walletNames.first,
                          items: widget.walletNames,
                          onChanged: (val) {
                            if (val != null) setState(() => _toWallet = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Transfer Amount (Rs)',
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    hint: '0',
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Transfer Memo / Reference',
                    controller: _notesController,
                    hint: 'Transfer reason or reference code...',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Transfer funds',
                    icon: 'arrow',
                    variant: ButtonVariant.primary,
                    onClick: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. DAILY RECORD / VOUCHER DIALOG (DAILY RECORDS)
// ============================================================================

class DailyVoucherDialog extends StatefulWidget {
  final String defaultType; // 'Expense', 'Collection', 'Payment', 'Adjustment'
  final List<String>? initialRow;
  final ValueChanged<List<String>> onSave;
  final void Function(Map<String, dynamic> data)? onSaveDetailed;

  const DailyVoucherDialog({
    super.key,
    this.defaultType = 'Expense',
    this.initialRow,
    required this.onSave,
    this.onSaveDetailed,
  });

  @override
  State<DailyVoucherDialog> createState() => _DailyVoucherDialogState();
}

class _DailyVoucherDialogState extends State<DailyVoucherDialog> {
  late TextEditingController _refController;
  late TextEditingController _descController;
  late TextEditingController _partyController;
  late TextEditingController _amountController;
  late String _type;
  late String _wallet;

  final List<String> _types = [
    'Add expense',
    'Customer collection',
    'Supplier payment',
    'Wallet transfer',
    'Receive money',
    'Add adjustment',
  ];

  final List<String> _wallets = [
    'Cash in Hand',
    'UBL Bank',
    'EasyPaisa',
    'Cash in Hand — HGM Work',
    'UBL Bank — HGM Work',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initialRow;
    final prefix = widget.defaultType.startsWith('Add exp') ? 'EXP' : (widget.defaultType.startsWith('Cust') ? 'COL' : 'PAY');

    _refController = TextEditingController(
      text: r != null ? r[0] : '$prefix-0${(2920 + DateTime.now().minute).toString()}',
    );
    _type = widget.defaultType;
    _descController = TextEditingController(text: r != null ? r[2] : 'Daily factory operating expense');
    _partyController = TextEditingController(text: r != null ? r[3] : 'General Vendor / Payee');
    _amountController = TextEditingController(
      text: r != null ? (r[4] != '—' ? r[4].replaceAll(RegExp(r'[^0-9.]'), '') : r[5].replaceAll(RegExp(r'[^0-9.]'), '')) : '5000',
    );
    _wallet = r != null ? r[6] : _wallets.first;
  }

  @override
  void dispose() {
    _refController.dispose();
    _descController.dispose();
    _partyController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amt = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (amt <= 0) return;

    final isMoneyIn = _type.contains('collection') || _type.contains('Receive');
    final formattedAmt = 'Rs ${NumberFormat('#,##0.00').format(amt)}';

    final row = [
      _refController.text.trim(),
      DateFormat('hh:mm a • EEEE').format(DateTime.now()),
      _descController.text.trim(),
      _partyController.text.trim(),
      isMoneyIn ? formattedAmt : '—',
      !isMoneyIn ? formattedAmt : '—',
      _wallet,
    ];

    widget.onSave(row);

    widget.onSaveDetailed?.call({
      'ref': _refController.text.trim(),
      'type': _type,
      'desc': _descController.text.trim(),
      'party': _partyController.text.trim(),
      'amount': amt,
      'wallet': _wallet,
      'isMoneyIn': isMoneyIn,
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Record Financial Voucher: $_type',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Voucher #',
                          controller: _refController,
                          hint: 'EXP-XXXXX',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Voucher Type',
                          value: _types.contains(_type) ? _type : _types.first,
                          items: _types,
                          onChanged: (val) {
                            if (val != null) setState(() => _type = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Description / Category',
                    controller: _descController,
                    hint: 'e.g. Labour wages, Meals, Factory repairs',
                  ),
                  const SizedBox(height: 12),
                  ErpFormField(
                    label: 'Party / Recipient / Vendor',
                    controller: _partyController,
                    hint: 'e.g. Labour Team A, Al-Rehman Hotel',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ErpFormField(
                          label: 'Amount (Rs)',
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ErpDropdownField<String>(
                          label: 'Affected Wallet',
                          value: _wallets.contains(_wallet) ? _wallet : _wallets.first,
                          items: _wallets,
                          onChanged: (val) {
                            if (val != null) setState(() => _wallet = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    onClick: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Post to Daily Ledger',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 9. ACTIVE NOTIFICATIONS POPOVER (HEADER BELL)
// ============================================================================

class NotificationPopover extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  final VoidCallback onClose;

  const NotificationPopover({
    super.key,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Operational Alerts (2)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          _buildAlertItem(
            icon: Icons.warning_amber_rounded,
            color: AppColors.danger,
            title: 'Negative stock alert',
            message: 'Fine White Salt 1kg has -200 packets recorded. Reconcile with pending production.',
            action: 'Review in Stock',
            onTap: () {
              onClose();
              onNavigate('Stock Management');
            },
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildAlertItem(
            icon: Icons.inventory_2_outlined,
            color: AppColors.amber,
            title: 'Packaging reorder warning',
            message: 'Empty 800g Printed Packets are at 18,600 pcs, near minimum buffer threshold.',
            action: 'Check Packaging',
            onTap: () {
              onClose();
              onNavigate('Products & Units');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String action,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.3)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onTap,
                  child: Text(
                    action,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brandPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. STOCK PROFILE & DOUBLE-ENTRY LEDGER DIALOG
// ============================================================================

class StockProfileDialog extends StatefulWidget {
  final Product product;
  final ErpTransactionRepository? repository;
  final VoidCallback? onStockAdjusted;

  const StockProfileDialog({
    super.key,
    required this.product,
    this.repository,
    this.onStockAdjusted,
  });

  @override
  State<StockProfileDialog> createState() => _StockProfileDialogState();
}

class _StockProfileDialogState extends State<StockProfileDialog> {
  late final ErpTransactionRepository _repository;
  late Product _product;
  List<StockMovement> _movements = [];
  bool _isLoading = true;
  String? _error;

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final _numberFormat = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ErpTransactionRepository();
    _product = widget.product;
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repository.getStockMovementHistory(_product.id);
      final prods = await _repository.getProducts();
      final fresh = prods.firstWhere((p) => p.id == _product.id, orElse: () => _product);

      if (mounted) {
        setState(() {
          _product = fresh;
          _movements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load stock movements: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openStockAdjustment() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => StockAdjustmentDialog(
        products: [_product.name],
        initialProduct: _product.name,
        onSave: (adj) async {
          final isPositive = adj['isPositive'] as bool;
          final qty = adj['quantity'] as double;
          final reason = adj['reason'] as String;
          final memo = adj['notes'] as String?;

          try {
            final newCount = isPositive ? (_product.currentStock + qty) : (_product.currentStock - qty);
            final fullReason = '$reason${memo != null && memo.isNotEmpty ? " • $memo" : ""}';
            await _repository.createStockAdjustment(
              productId: _product.id,
              adjustmentDate: DateTime.now().toIso8601String().substring(0, 10),
              adjustmentType: isPositive ? 'Physical Count Discrepancy' : 'Damage',
              countedQuantity: newCount,
              reason: fullReason,
              operatorName: 'Warehouse Supervisor',
            );
            await _loadMovements();
            widget.onStockAdjusted?.call();
            if (mounted) {
              AppToast.showSuccess(
                context,
                'Stock adjustment of ${isPositive ? "+" : "-"}${_numberFormat.format(qty)} ${_product.baseUnit} recorded for "${_product.name}".',
              );
            }
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Failed to record adjustment: $e');
            }
          }
        },
      ),
    );
  }

  void _exportLedger() {
    final buffer = StringBuffer();
    buffer.writeln('Product Code,Product Name,Date,Reference No,Movement Type,Quantity,Base Unit,Unit Cost,Total Cost,Balance After');
    for (final m in _movements) {
      buffer.writeln(
        '"${_product.code}","${_product.name}","${m.movementDate}","${m.referenceNo}","${m.movementType}",${m.quantity},"${_product.baseUnit}",${m.unitCost},${m.totalCost},${m.balanceAfter}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppToast.showSuccess(context, 'Stock ledger for "${_product.name}" copied to clipboard (${_movements.length} movements).');
  }

  @override
  Widget build(BuildContext context) {
    final isNegative = _product.currentStock < 0;
    final isLow = _product.currentStock <= 100 && !isNegative;
    final isHealthy = !isNegative && !isLow;

    final badgeTone = isHealthy
        ? BadgeTone.green
        : isNegative
            ? BadgeTone.red
            : BadgeTone.amber;

    final stockValue = _product.currentStock * _product.averageCost;

    final initials = _product.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('').toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isNegative ? const Color(0xFFFEE2E2) : AppColors.brandLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isNegative ? AppColors.danger.withValues(alpha: 0.3) : AppColors.brandPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isNotEmpty ? initials : 'ST',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isNegative ? AppColors.danger : AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PRODUCT STOCK PROFILE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isNegative ? AppColors.danger : AppColors.textSubtle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppBadge(
                              label: isNegative ? 'Negative' : (isLow ? 'Low stock' : 'Healthy'),
                              tone: badgeTone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${_product.code}  •  Category: ${_product.category}  •  Base Unit: ${_product.baseUnit}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Negative stock reconciliation alert banner
                    if (isNegative)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deficit Alert: Negative Stock of ${_numberFormat.format(_product.currentStock)} ${_product.baseUnit}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Sales vouchers were posted before recording production shifts. Perform an audit stock adjustment or record manufacturing output to reconcile.',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF991B1B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Reconcile now',
                              variant: ButtonVariant.primary,
                              onClick: _openStockAdjustment,
                            ),
                          ],
                        ),
                      ),

                    // Metrics Grid (4 cards)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Available stock',
                            value: '${_numberFormat.format(_product.currentStock)} ${_product.baseUnit}',
                            hint: isNegative ? 'Deficit requires production' : 'Physical inventory count',
                            isAlert: isNegative || isLow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Average cost',
                            value: 'Rs ${_product.averageCost.toStringAsFixed(2)}',
                            hint: 'Weighted FIFO cost per ${_product.baseUnit}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Stock valuation',
                            value: 'Rs ${_currencyFormat.format(stockValue)}',
                            hint: 'General ledger inventory balance',
                            isAlert: isNegative,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Conversion specification',
                            value: _product.conversionDescription ?? 'Direct 1:1',
                            hint: 'Trading to base stock ratio',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Ledger Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DOUBLE-ENTRY STOCK MOVEMENT LEDGER',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chronological audit trail of purchases, sales, production shifts, and count adjustments.',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppButton(
                          label: 'Export ledger',
                          icon: 'download',
                          variant: ButtonVariant.secondary,
                          onClick: _exportLedger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ledger Table
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: AppTableSkeleton(rowCount: 4, columnCount: 6),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                      )
                    else if (_movements.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            const Text('No stock movement transactions recorded yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            const Text('Balance reflects initial opening setup or pending entries.', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 720,
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.4), // Date
                                1: FlexColumnWidth(1.4), // Ref No
                                2: FlexColumnWidth(1.8), // Type
                                3: FlexColumnWidth(1.2), // Qty
                                4: FlexColumnWidth(1.2), // Unit Cost
                                5: FlexColumnWidth(1.3), // Total
                                6: FlexColumnWidth(1.3), // Balance After
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(
                                    color: AppColors.tableHeaderBg,
                                    border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                                  ),
                                  children: [
                                    _HeaderCell('DATE'),
                                    _HeaderCell('REFERENCE'),
                                    _HeaderCell('TYPE'),
                                    _HeaderCell('QUANTITY'),
                                    _HeaderCell('UNIT COST'),
                                    _HeaderCell('TOTAL'),
                                    _HeaderCell('BALANCE'),
                                  ],
                                ),
                                ..._movements.map((m) {
                                  final isPositive = m.quantity > 0;
                                  final isZero = m.quantity == 0;
                                  final qtyStr = isPositive
                                      ? '+${_numberFormat.format(m.quantity)}'
                                      : _numberFormat.format(m.quantity);

                                  return TableRow(
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          m.movementDate.length >= 10 ? m.movementDate.substring(0, 10) : m.movementDate,
                                          style: const TextStyle(fontSize: 10.5, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          m.referenceNo,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.brandPrimary),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          m.movementType,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          qtyStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isZero
                                                ? AppColors.textMuted
                                                : isPositive
                                                    ? AppColors.green
                                                    : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          'Rs ${m.unitCost.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          'Rs ${_currencyFormat.format(m.totalCost.abs())}',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          _numberFormat.format(m.balanceAfter),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: m.balanceAfter < 0 ? AppColors.danger : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_movements.length} ledger movement(s) recorded in SQLite audit database.',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      AppButton(
                        label: 'Adjust stock',
                        variant: ButtonVariant.primary,
                        icon: 'plus',
                        onClick: _openStockAdjustment,
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'Close',
                        variant: ButtonVariant.secondary,
                        onClick: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String hint,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : AppColors.surfaceMuted,
        border: Border.all(color: isAlert ? const Color(0xFFFCA5A5) : AppColors.borderLight),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isAlert ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ============================================================================
// 11. UNIVERSAL ERP EXPORT MODAL
// ============================================================================

class AppExportDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final String filenamePrefix;

  const AppExportDialog({
    super.key,
    required this.title,
    this.subtitle = 'Export structured records to CSV or print report.',
    required this.headers,
    required this.rows,
    this.filenamePrefix = 'AnwarSalt_Export',
  });

  String _generateCsv() {
    final buffer = StringBuffer();
    buffer.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    for (final row in rows) {
      buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }
    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    final csv = _generateCsv();
    Clipboard.setData(ClipboardData(text: csv));
    AppToast.showSuccess(context, '$title copied to clipboard (${rows.length} rows as CSV).');
    Navigator.of(context).pop();
  }

  Future<void> _exportPdfReport(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      final report = ReportData(
        title: title,
        subtitle: subtitle,
        dateRange: 'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        columnHeaders: headers.take(6).toList(),
        rows: rows.map((r) => r.take(6).toList()).toList(),
        summaryMetrics: {'Total Records': '${rows.length}'},
      );
      final res = await PrintingService.instance.exportReportPdf(report);
      if (context.mounted) {
        if (res.success) {
          AppToast.showSuccess(context, 'PDF generated: ${res.message}');
        } else {
          AppToast.showInfo(context, 'Report status: ${res.message}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, 'PDF export failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow: AppColors.shadowLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.download_rounded, size: 18, color: AppColors.brandPrimary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text('${rows.length} rows ready for export', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),

                  // Data Preview Box
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headers.join(' | '),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brandPrimary),
                          ),
                          const Divider(height: 12),
                          ...rows.take(5).map(
                            (r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                r.join(' | '),
                                style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                          if (rows.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '... and ${rows.length - 5} more records',
                                style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy CSV to Clipboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandPrimary,
                            side: const BorderSide(color: AppColors.brandPrimary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _copyToClipboard(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('Print / Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _exportPdfReport(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSubtle),
      ),
    );
  }
}
