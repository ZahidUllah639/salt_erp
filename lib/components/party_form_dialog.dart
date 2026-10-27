import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/party.dart';
import '../repositories/party_repository.dart';
import 'app_components.dart';
import 'app_icons.dart';

class PartyFormDialog extends StatefulWidget {
  final String type; // 'Customer' or 'Supplier'
  final Party? partyToEdit;
  final PartyRepository repository;

  const PartyFormDialog({
    super.key,
    required this.type,
    this.partyToEdit,
    required this.repository,
  });

  @override
  State<PartyFormDialog> createState() => _PartyFormDialogState();
}

class _PartyFormDialogState extends State<PartyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _phoneController;
  late TextEditingController _secondaryPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _taxIdController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _notesController;

  late String _openingBalanceType;
  late String _openingBalanceDate;
  late bool _isArchived;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.partyToEdit;
    final isCustomer = widget.type == 'Customer';

    _codeController = TextEditingController(text: p?.code ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _contactPersonController = TextEditingController(text: p?.contactPerson ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _secondaryPhoneController = TextEditingController(text: p?.secondaryPhone ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _taxIdController = TextEditingController(text: p?.taxId ?? '');
    _openingBalanceController = TextEditingController(
      text: p != null ? p.openingBalance.toStringAsFixed(0) : '0',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');

    _openingBalanceType = p?.openingBalanceType ?? (isCustomer ? 'Receivable' : 'Payable');
    _openingBalanceDate = p?.openingBalanceDate ?? DateTime.now().toIso8601String().substring(0, 10);
    _isArchived = p?.isArchived ?? false;

    if (p == null) {
      _loadNextCode();
    }
  }

  Future<void> _loadNextCode() async {
    try {
      final code = await widget.repository.generateNextCode(widget.type);
      if (mounted && _codeController.text.isEmpty) {
        setState(() => _codeController.text = code);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _secondaryPhoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_openingBalanceDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _openingBalanceDate = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final opBal = double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;
    if (opBal < 0) {
      setState(() => _errorMessage = 'Opening balance cannot be negative.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();
      if (widget.partyToEdit == null) {
        final newParty = Party(
          code: _codeController.text.trim(),
          type: widget.type,
          name: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
          phone: _phoneController.text.trim(),
          secondaryPhone: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
          openingBalance: opBal,
          openingBalanceType: _openingBalanceType,
          openingBalanceDate: _openingBalanceDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isArchived: _isArchived,
          createdAt: now,
          updatedAt: now,
        );
        await widget.repository.createParty(newParty);
      } else {
        final updatedParty = widget.partyToEdit!.copyWith(
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
          phone: _phoneController.text.trim(),
          secondaryPhone: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
          openingBalance: opBal,
          openingBalanceType: _openingBalanceType,
          openingBalanceDate: _openingBalanceDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isArchived: _isArchived,
          updatedAt: now,
        );
        await widget.repository.updateParty(updatedParty);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DuplicatePartyCodeException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partyToEdit != null;
    final isCustomer = widget.type == 'Customer';
    final title = isEdit ? 'Edit ${widget.type} Profile' : 'New ${widget.type} Profile';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: AppMotion.duration(context, AppMotion.normal),
        curve: AppMotion.easeOut,
        builder: (context, value, child) {
          if (AppMotion.isReducedMotion(context)) return child!;
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              child: child,
            ),
          );
        },
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            boxShadow: AppColors.dialogShadow,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isCustomer ? AppColors.brandLight : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: AppIcons.icon(
                      isCustomer ? 'users' : 'truck',
                      size: 20,
                      color: isCustomer ? AppColors.brandPrimary : AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'Update party contact information, tax IDs and accounting defaults.'
                              : 'Register a verified ${widget.type.toLowerCase()} with traceable opening ledger balance.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close (Esc)',
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        DangerNotice(
                          title: 'Validation Error',
                          message: _errorMessage!,
                          actionLabel: 'Dismiss',
                          onAction: () => setState(() => _errorMessage = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // SECTION 1: Identity & Primary Info
                      _buildSectionTitle('1. Commercial Profile & Identification'),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildFormField(
                              label: 'Unique ID / Code *',
                              controller: _codeController,
                              hint: isCustomer ? 'CUS-0143' : 'SUP-0032',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Code is required';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _buildFormField(
                              label: '${widget.type} Name / Business Title *',
                              controller: _nameController,
                              hint: isCustomer ? 'e.g. Al-Madina Traders' : 'e.g. Khewra Salt Co.',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Name is required';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Contact Person / Representative',
                              controller: _contactPersonController,
                              hint: 'e.g. Sheikh Abdul Rehman',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: 'Tax / NTN / STRN Details',
                              controller: _taxIdController,
                              hint: 'e.g. NTN-8821943-3',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2: Communication & Location
                      _buildSectionTitle('2. Contact Numbers & Factory Delivery Address'),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Primary Phone / WhatsApp *',
                              controller: _phoneController,
                              hint: '+92 300 000 0000',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Phone number is required';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: 'Secondary Phone / Landline (Optional)',
                              controller: _secondaryPhoneController,
                              hint: '+92 51 000 0000',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildFormField(
                        label: 'Factory Site / Warehouse Address',
                        controller: _addressController,
                        hint: 'Shop / Plot / Gate number, Market or Industrial Estate, City',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3: Opening Balance & Accounting
                      _buildSectionTitle('3. Opening Ledger Balance & Financial Direction'),
                      const SizedBox(height: 6),
                      const Text(
                        'Opening balances establish historical account positions without inflating current sales or purchases.',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormField(
                                    label: 'Opening Amount (Rs)',
                                    controller: _openingBalanceController,
                                    hint: '0',
                                    keyboardType: TextInputType.number,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return null;
                                      final num = double.tryParse(val.trim());
                                      if (num == null || num < 0) return 'Invalid amount';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: ErpDropdownField<String>(
                                    label: 'Direction',
                                    value: _openingBalanceType,
                                    items: const ['Receivable', 'Payable'],
                                    itemLabel: (v) => v == 'Receivable' ? 'Receivable (Owes Factory)' : 'Payable (Factory Owes)',
                                    onChanged: (val) {
                                      if (val != null) setState(() => _openingBalanceType = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Effective Date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      InkWell(
                                        onTap: _pickDate,
                                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                        child: Container(
                                          height: 38,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: AppColors.border),
                                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _openingBalanceDate,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              AppIcons.icon('calendar', size: 14, color: AppColors.textMuted),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SECTION 4: Notes & Archival Status
                      _buildFormField(
                        label: 'Operational Notes & Commercial Terms',
                        controller: _notesController,
                        hint: 'Credit terms, agreed transport discount, salt grade preferences...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _isArchived,
                            activeColor: AppColors.brandPrimary,
                            onChanged: (val) => setState(() => _isArchived = val ?? false),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Archive profile (Hides from active billing menus while preserving audit history)',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(top: BorderSide(color: AppColors.borderLight)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppColors.radiusLg)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.ghost,
                    onClick: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: isEdit ? 'Update Profile' : 'Save Profile',
                    icon: 'check',
                    variant: ButtonVariant.primary,
                    isLoading: _isSaving,
                    onClick: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return ErpFormField(
      label: label,
      controller: controller,
      hint: hint,
      maxLines: maxLines,
      keyboardType: keyboardType ?? TextInputType.text,
      validator: validator,
    );
  }
}
