import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/party.dart';
import '../models/ledger_entry.dart';
import '../repositories/party_repository.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/party_form_dialog.dart';
import '../components/receipt_modal.dart';
import '../services/printing_service.dart';

class PartyDetailPage extends StatefulWidget {
  final int partyId;
  final PartyRepository repository;
  final VoidCallback onBack;

  const PartyDetailPage({
    super.key,
    required this.partyId,
    required this.repository,
    required this.onBack,
  });

  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  Party? _party;
  List<LedgerEntry> _ledger = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeTabIndex = 0; // 0 = Ledger, 1 = Commercial Transactions, 2 = Profile Info

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await widget.repository.getPartyById(widget.partyId);
      if (p == null) {
        setState(() {
          _errorMessage = 'Profile not found or was removed.';
          _isLoading = false;
        });
        return;
      }

      final ledger = await widget.repository.getPartyLedger(widget.partyId);
      final txns = await widget.repository.getPartyTransactions(widget.partyId);

      if (mounted) {
        setState(() {
          _party = p;
          _ledger = ledger;
          _transactions = txns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    if (_party == null) return;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PartyFormDialog(
        type: _party!.type,
        partyToEdit: _party,
        repository: widget.repository,
      ),
    );

    if (res == true) {
      await _loadData();
    }
  }

  Future<void> _toggleArchive() async {
    if (_party == null) return;
    final newState = !_party!.isArchived;
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: newState ? 'Archive Profile?' : 'Restore Profile?',
      message: newState
          ? 'Archiving "${_party!.name}" will hide them from active sales/purchase selectors. All historical ledger entries remain strictly preserved.'
          : 'Restore "${_party!.name}" to active status for current factory operations?',
      confirmLabel: newState ? 'Archive' : 'Restore',
      isDanger: newState,
      auditNote: 'Audit trails and historical accounting ledgers remain permanently intact.',
    );

    if (confirm == true) {
      await widget.repository.setArchived(_party!.id!, newState);
      await _loadData();
      if (mounted) {
        AppToast.showSuccess(
          context,
          newState ? 'Profile archived successfully.' : 'Profile restored to active status.',
        );
      }
    }
  }

  Future<void> _deleteProfile() async {
    if (_party == null) return;

    // Check if transactions exist
    final hasCommercialTxns = _party!.transactionCount > 0;
    if (hasCommercialTxns) {
      await showAppConfirmationDialog(
        context: context,
        title: 'Audit Trail Protected',
        message: 'Cannot permanently delete "${_party!.name}" because it has ${_party!.transactionCount} linked commercial transaction(s). '
            '\n\nERP accounting standards forbid erasing financial history to maintain balanced audit trails. '
            'Please use the "Archive" action instead to deactivate this profile safely.',
        confirmLabel: 'Archive Instead',
        cancelLabel: 'Close',
        isDanger: true,
        auditNote: 'Commercial transactions are permanently locked in the SQLite general ledger.',
      ).then((archiveInstead) {
        if (archiveInstead == true) {
          _toggleArchive();
        }
      });
      return;
    }

    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Profile?',
      message: 'Are you sure you want to delete "${_party!.name}" (${_party!.code})? '
          'Since this profile has no transaction history, it can be safely removed.',
      confirmLabel: 'Delete Profile',
      isDanger: true,
    );

    if (confirm == true) {
      try {
        await widget.repository.deleteParty(_party!.id!);
        if (mounted) {
          AppToast.showSuccess(context, 'Profile removed successfully.');
          widget.onBack();
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Delete failed: $e');
        }
      }
    }
  }

  void _printStatement() {
    if (_party == null) return;
    final statementData = PrintingService.instance.receiptFromPartyStatement(
      _party!,
      _ledger,
      isReprint: true,
    );
    showDialog(
      context: context,
      builder: (_) => ReceiptModal(
        receiptData: statementData,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(24),
        child: const AppTableSkeleton(rowCount: 8, columnCount: 5),
      );
    }

    if (_errorMessage != null || _party == null) {
      return Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Profile not found', style: AppTypography.display),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to directory',
                icon: 'arrow',
                onClick: widget.onBack,
              ),
            ],
          ),
        ),
      );
    }

    final p = _party!;
    final isCustomer = p.type == 'Customer';
    final balAbs = p.currentBalance.abs();
    final balDirection = p.balanceDirection;
    final isSettled = balAbs <= 0.01;

    // Badges
    final badgeTone = p.isArchived
        ? BadgeTone.neutral
        : isSettled
            ? BadgeTone.green
            : (balDirection == 'Receivable' ? BadgeTone.amber : BadgeTone.blue);

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                // Top Navigation Back Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: widget.onBack,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcons.icon('arrow', size: 14, color: AppColors.brandPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Back to ${p.type}s Directory',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        AppButton(
                          label: 'Print Statement',
                          icon: 'print',
                          variant: ButtonVariant.secondary,
                          onClick: _printStatement,
                          tooltip: 'Print or export thermal customer statement',
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: p.isArchived ? 'Restore' : 'Archive',
                          icon: 'more',
                          variant: ButtonVariant.secondary,
                          onClick: _toggleArchive,
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'Edit',
                          icon: 'settings',
                          variant: ButtonVariant.secondary,
                          onClick: _editProfile,
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'Delete',
                          icon: 'trash',
                          variant: ButtonVariant.danger,
                          onClick: _deleteProfile,
                          tooltip: 'Delete unused profile (protected if transactions exist)',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isCustomer ? AppColors.brandLight : AppColors.amberLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCustomer ? const Color(0x33184EAB) : const Color(0x33D97706),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join(''),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isCustomer ? AppColors.brandPrimary : AppColors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Name, Code, Badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AppBadge(label: p.code, tone: BadgeTone.neutral),
                                const SizedBox(width: 6),
                                AppBadge(label: p.isArchived ? 'Archived' : p.type, tone: badgeTone),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (p.contactPerson != null && p.contactPerson!.isNotEmpty) ...[
                                  AppIcons.icon('users', size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.contactPerson!,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                AppIcons.icon('truck', size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 5),
                                Text(
                                  p.phone,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                if (p.address != null && p.address!.isNotEmpty) ...[
                                  const SizedBox(width: 16),
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      p.address!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Balance Highlight Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AppColors.greenBg
                              : (balDirection == 'Receivable' ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSettled
                                ? AppColors.greenBorder
                                : (balDirection == 'Receivable' ? const Color(0xFFFED7AA) : const Color(0xFFBFDBFE)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isSettled
                                  ? 'ACCOUNT SETTLED'
                                  : (balDirection == 'Receivable' ? 'CURRENT RECEIVABLE' : 'CURRENT PAYABLE'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isSettled
                                    ? AppColors.green
                                    : (balDirection == 'Receivable' ? AppColors.amber : AppColors.brandPrimary),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Rs ${_currencyFormat.format(balAbs)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: isSettled
                                    ? AppColors.green
                                    : (balDirection == 'Receivable' ? const Color(0xFF9A3412) : AppColors.brandPrimary),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSettled
                                  ? 'Balance is zero'
                                  : (balDirection == 'Receivable' ? 'Owed to factory' : 'Owed by factory'),
                              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metric Cards Strip
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 30) / 4;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: MiniMetric(
                            label: 'Opening balance',
                            value: 'Rs ${_currencyFormat.format(p.openingBalance)}',
                            hint: 'Effective ${p.openingBalanceDate} (${p.openingBalanceType})',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniMetric(
                            label: isCustomer ? 'Total sales invoiced' : 'Total purchases billed',
                            value: 'Rs ${_currencyFormat.format(_calculateTotalInvoiced())}',
                            hint: '${_transactions.length} commercial entries',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniMetric(
                            label: isCustomer ? 'Collected from customer' : 'Paid to supplier',
                            value: 'Rs ${_currencyFormat.format(_calculateTotalPaid())}',
                            hint: 'Traceable in cash / bank',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniMetric(
                            label: 'Ledger entries',
                            value: '${_ledger.length}',
                            hint: p.lastTransactionDate != null ? 'Last: ${p.lastTransactionDate}' : 'No transactions',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Tabs for Detail Views
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tab Bar Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabItem(0, 'Complete Ledger & Statement (${_ledger.length})', 'book'),
                              const SizedBox(width: 8),
                              _buildTabItem(1, 'Invoices & Vouchers (${_transactions.length})', 'receipt'),
                              const SizedBox(width: 8),
                              _buildTabItem(2, 'Tax & Profile Information', 'users'),
                            ],
                          ),
                        ),
                      ),

                      // Tab View Body
                      if (_activeTabIndex == 0) _buildLedgerTab(),
                      if (_activeTabIndex == 1) _buildTransactionsTab(),
                      if (_activeTabIndex == 2) _buildProfileInfoTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  double _calculateTotalInvoiced() {
    double total = 0.0;
    for (final t in _transactions) {
      final type = t['transaction_type'] as String;
      if (type.contains('Sale') || type.contains('Purchase')) {
        total += (t['amount'] as num).toDouble();
      }
    }
    return total;
  }

  double _calculateTotalPaid() {
    double total = 0.0;
    for (final t in _transactions) {
      final type = t['transaction_type'] as String;
      if (type.contains('Collection') || type.contains('Payment')) {
        total += (t['amount'] as num).toDouble();
      }
    }
    return total;
  }

  Widget _buildTabItem(int index, String label, String icon) {
    final active = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcons.icon(icon, size: 14, color: active ? AppColors.brandPrimary : AppColors.textMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.brandPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTab() {
    if (_ledger.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: AppEmptyState(
          icon: 'book',
          title: 'No Ledger Entries',
          message: 'This profile has no historical ledger movements yet.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 1000 ? constraints.maxWidth : 1000,
            ),
            child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2), // Date
            1: FlexColumnWidth(1.2), // Ref
            2: FlexColumnWidth(1.4), // Type
            3: FlexColumnWidth(2.8), // Description
            4: FlexColumnWidth(1.3), // Debit
            5: FlexColumnWidth(1.3), // Credit
            6: FlexColumnWidth(1.5), // Balance
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: AppColors.tableHeaderBg,
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
              ),
              children: const [
                _HeaderCell('DATE'),
                _HeaderCell('REFERENCE'),
                _HeaderCell('TYPE'),
                _HeaderCell('DESCRIPTION'),
                _HeaderCell('DEBIT (RS)', align: TextAlign.right),
                _HeaderCell('CREDIT (RS)', align: TextAlign.right),
                _HeaderCell('RUNNING BAL (RS)', align: TextAlign.right),
              ],
            ),
            ..._ledger.map((e) {
              final isOp = e.isOpeningBalance;
              return TableRow(
                decoration: BoxDecoration(
                  color: isOp ? const Color(0xFFFBFDFF) : Colors.transparent,
                  border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                children: [
                  _TableCell(e.entryDate.length > 16 ? e.entryDate.substring(0, 16) : e.entryDate),
                  _TableCell(e.referenceNo, isBold: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: AppBadge(
                      label: e.entryType,
                      tone: isOp
                          ? BadgeTone.neutral
                          : (e.debit > 0 ? BadgeTone.blue : BadgeTone.green),
                    ),
                  ),
                  _TableCell(e.description),
                  _TableCell(
                    e.debit > 0 ? _currencyFormat.format(e.debit) : '—',
                    align: TextAlign.right,
                    isTabular: true,
                  ),
                  _TableCell(
                    e.credit > 0 ? _currencyFormat.format(e.credit) : '—',
                    align: TextAlign.right,
                    isTabular: true,
                  ),
                  _TableCell(
                    'Rs ${_currencyFormat.format(e.runningBalance.abs())}',
                    align: TextAlign.right,
                    isTabular: true,
                    isBold: true,
                    textColor: e.runningBalance.abs() <= 0.01
                        ? AppColors.green
                        : (_party!.type == 'Customer'
                            ? (e.runningBalance > 0 ? AppColors.amber : AppColors.brandPrimary)
                            : (e.runningBalance > 0 ? AppColors.brandPrimary : AppColors.amber)),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  },
);
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: AppEmptyState(
          icon: 'receipt',
          title: 'No Commercial Invoices',
          message: 'No sales or purchase bills recorded yet for this profile.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
            ),
            child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4), // Voucher No
            1: FlexColumnWidth(1.4), // Date
            2: FlexColumnWidth(1.6), // Type
            3: FlexColumnWidth(1.5), // Total Amount
            4: FlexColumnWidth(1.3), // Paid Amount
            5: FlexColumnWidth(1.3), // Outstanding
            6: FlexColumnWidth(1.2), // Status
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: AppColors.tableHeaderBg,
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
              ),
              children: const [
                _HeaderCell('VOUCHER #'),
                _HeaderCell('DATE'),
                _HeaderCell('TYPE'),
                _HeaderCell('TOTAL AMOUNT', align: TextAlign.right),
                _HeaderCell('PAID', align: TextAlign.right),
                _HeaderCell('OUTSTANDING', align: TextAlign.right),
                _HeaderCell('STATUS'),
              ],
            ),
            ..._transactions.map((t) {
              final status = t['status'] as String;
              final tone = status == 'Paid'
                  ? BadgeTone.green
                  : status == 'Partial'
                      ? BadgeTone.amber
                      : BadgeTone.red;

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                children: [
                  _TableCell(t['transaction_no'] as String, isBold: true),
                  _TableCell(t['transaction_date'] as String),
                  _TableCell(t['transaction_type'] as String),
                  _TableCell('Rs ${_currencyFormat.format(t['amount'])}', align: TextAlign.right, isTabular: true),
                  _TableCell('Rs ${_currencyFormat.format(t['paid_amount'])}', align: TextAlign.right, isTabular: true),
                  _TableCell('Rs ${_currencyFormat.format(t['outstanding_amount'])}', align: TextAlign.right, isTabular: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: AppBadge(label: status, tone: tone),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  },
);
  }

  Widget _buildProfileInfoTab() {
    final p = _party!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Commercial Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    InfoRow(label: 'Party Code / ID', value: p.code),
                    InfoRow(label: 'Registered Name', value: p.name),
                    InfoRow(label: 'Contact Person', value: p.contactPerson ?? '—'),
                    InfoRow(label: 'Primary Phone', value: p.phone),
                    InfoRow(label: 'Secondary Phone', value: p.secondaryPhone ?? '—'),
                    InfoRow(label: 'Tax / NTN / STRN', value: p.taxId ?? 'Non-filer / Unregistered'),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Financial & System Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    InfoRow(label: 'Opening Balance', value: 'Rs ${_currencyFormat.format(p.openingBalance)}'),
                    InfoRow(label: 'Opening Direction', value: p.openingBalanceType),
                    InfoRow(label: 'Opening Date', value: p.openingBalanceDate),
                    InfoRow(label: 'Account Status', value: p.isArchived ? 'Archived' : 'Active (Operational)'),
                    InfoRow(label: 'Created Timestamp', value: p.createdAt.substring(0, 10)),
                    InfoRow(label: 'Last Profile Update', value: p.updatedAt.substring(0, 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Factory Site / Delivery Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(p.address ?? 'No physical delivery address configured.', style: AppTypography.body),
          const SizedBox(height: 16),
          const Text('Commercial Terms & Operational Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(p.notes ?? 'No special notes recorded.', style: AppTypography.body),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;
  const _HeaderCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        textAlign: align,
        style: AppTypography.tableHeader,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final bool isTabular;
  final TextAlign align;
  final Color? textColor;

  const _TableCell(
    this.text, {
    this.isBold = false,
    this.isTabular = false,
    this.align = TextAlign.left,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: textColor ?? AppColors.textPrimary,
          fontFeatures: isTabular ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );
  }
}
