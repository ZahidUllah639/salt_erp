import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../models/party.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';
import '../repositories/erp_transaction_repository.dart';
import '../repositories/party_repository.dart';

class DailyRecordsPage extends StatefulWidget {
  const DailyRecordsPage({super.key});

  @override
  State<DailyRecordsPage> createState() => _DailyRecordsPageState();
}

class _DailyRecordsPageState extends State<DailyRecordsPage> {
  final _repository = ErpTransactionRepository();
  final _partyRepo = PartyRepository();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  String _searchQuery = '';
  bool _isLoading = true;

  List<DailyRecord> _records = [];
  List<Wallet> _wallets = [];
  List<Party> _parties = [];

  static const List<List<String>> actions = [
    ["Add expense", "wallet"],
    ["Receive money", "cash"],
    ["Customer collection", "users"],
    ["Supplier payment", "truck"],
    ["Wallet transfer", "arrow"],
    ["Add adjustment", "settings"],
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await _repository.getDailyRecords(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final wallets = await _repository.getWallets();
      final custs = await _partyRepo.getParties(type: 'Customer');
      final supps = await _partyRepo.getParties(type: 'Supplier');
      final parties = [...custs, ...supps];

      if (mounted) {
        setState(() {
          _records = records;
          _wallets = wallets;
          _parties = parties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Failed to load daily records: $e');
      }
    }
  }

  void _openVoucherDialog([String defaultType = 'Add expense']) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => DailyVoucherDialog(
        defaultType: defaultType,
        onSave: (_) {},
        onSaveDetailed: (data) async {
          await _handleSaveVoucher(data);
        },
      ),
    );
  }

  Future<void> _handleSaveVoucher(Map<String, dynamic> data) async {
    try {
      final rawType = data['type'] as String;
      final desc = data['desc'] as String;
      final partyName = data['party'] as String;
      final amount = (data['amount'] as num).toDouble();
      final walletName = data['wallet'] as String;

      // Map record type
      String recordType = 'Expense';
      if (rawType.contains('collection')) {
        recordType = 'Customer Collection';
      } else if (rawType.contains('payment')) {
        recordType = 'Supplier Payment';
      } else if (rawType.contains('Receive')) {
        recordType = 'Income';
      } else if (rawType.contains('transfer')) {
        recordType = 'Wallet Transfer';
      } else if (rawType.contains('adjustment')) {
        recordType = 'Stock Adjustment';
      }

      // Map category
      String category = 'Operations';
      if (recordType == 'Expense') category = 'Operating Expense';
      if (recordType == 'Income') category = 'Operating Income';
      if (recordType == 'Customer Collection') category = 'Customer Accounts Receivable';
      if (recordType == 'Supplier Payment') category = 'Supplier Accounts Payable';
      if (recordType == 'Wallet Transfer') category = 'Internal Inter-Wallet Transfer';

      // Resolve party
      int? partyId;
      if (recordType == 'Customer Collection' || recordType == 'Supplier Payment') {
        final partyType = recordType == 'Customer Collection' ? 'Customer' : 'Supplier';
        Party? match;
        for (final p in _parties) {
          if (p.name.toLowerCase() == partyName.toLowerCase()) {
            match = p;
            break;
          }
        }
        if (match != null && match.id != null) {
          partyId = match.id!;
        } else {
          final code = await _partyRepo.generateNextCode(partyType);
          partyId = await _partyRepo.createParty(Party(
            code: code,
            type: partyType,
            name: partyName,
            phone: '+92 300 0000000',
            openingBalance: 0,
            openingBalanceType: partyType == 'Customer' ? 'Receivable' : 'Payable',
            openingBalanceDate: '2026-10-01',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ));
        }
      }

      // Resolve wallet
      final matchedWallet = _wallets.firstWhere(
        (w) => w.name.toLowerCase() == walletName.toLowerCase(),
        orElse: () => _wallets.isNotEmpty
            ? _wallets.first
            : const Wallet(
                id: 1,
                name: 'Cash in Hand',
                type: 'Cash',
                balance: 0,
                createdAt: '',
                updatedAt: '',
              ),
      );

      int? srcWalletId;
      int? destWalletId;

      if (recordType == 'Expense' || recordType == 'Supplier Payment') {
        srcWalletId = matchedWallet.id;
      } else if (recordType == 'Income' || recordType == 'Customer Collection') {
        destWalletId = matchedWallet.id;
      } else if (recordType == 'Wallet Transfer') {
        srcWalletId = matchedWallet.id;
        final otherWallets = _wallets.where((w) => w.id != matchedWallet.id).toList();
        destWalletId = otherWallets.isNotEmpty ? otherWallets.first.id : matchedWallet.id;
      }

      final dateStr = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      final newRecord = await _repository.createDailyRecord(
        recordType: recordType,
        recordDate: dateStr,
        category: category,
        description: desc,
        partyId: partyId,
        sourceWalletId: srcWalletId,
        destinationWalletId: destWalletId,
        amount: amount,
        notes: 'Desktop financial terminal entry: $partyName',
      );

      if (mounted) {
        AppToast.showSuccess(context, 'Financial record "${newRecord.recordNo}" posted to general ledger.');
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to save financial record: $e');
      }
    }
  }

  Future<void> _cancelRecord(DailyRecord rec) async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Cancel Financial Record?',
      message: 'Are you sure you want to cancel and reverse "${rec.recordNo}" (${rec.recordType})? '
          'Double-entry reversing adjustment will be posted to the ledger automatically.',
      confirmLabel: 'Cancel Record',
      isDanger: true,
      auditNote: 'Reversing entry created in General Ledger with audit timestamp.',
    );

    if (confirm == true) {
      try {
        await _repository.cancelDailyRecord(
          recordId: rec.id,
          reason: 'Desktop operator cancellation',
        );
        if (mounted) {
          AppToast.showSuccess(context, 'Financial record "${rec.recordNo}" reversed.');
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Failed to reverse record: $e');
        }
      }
    }
  }

  String _typeFilter = 'All';
  DateTimeRange? _dateRange;

  void _exportDailyRecords() {
    final headers = [
      'Record No',
      'Date & Time',
      'Record Type',
      'Category & Description',
      'Party',
      'Wallet / Account',
      'Money In (Rs)',
      'Money Out (Rs)',
      'Status',
    ];
    final rows = _records.map((r) {
      final isMoneyIn = r.recordType == 'Income' || r.recordType == 'Customer Collection';
      final isMoneyOut = r.recordType == 'Expense' || r.recordType == 'Supplier Payment';
      String walletDisplay = 'Cash in Hand';
      if (r.sourceWalletId != null) {
        final match = _wallets.where((w) => w.id == r.sourceWalletId).toList();
        if (match.isNotEmpty) walletDisplay = match.first.name;
      } else if (r.destinationWalletId != null) {
        final match = _wallets.where((w) => w.id == r.destinationWalletId).toList();
        if (match.isNotEmpty) walletDisplay = match.first.name;
      }
      return [
        r.recordNo,
        r.recordDate,
        r.recordType,
        '${r.category} - ${r.description}',
        r.partyId != null ? 'Linked Party #${r.partyId}' : '—',
        walletDisplay,
        isMoneyIn ? _currencyFormat.format(r.amount) : '0.00',
        isMoneyOut ? _currencyFormat.format(r.amount) : '0.00',
        r.status,
      ];
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'Daily General Cash Book & Vouchers',
        subtitle: 'Complete accounting log of operational expenses, customer receipts, and supplier payouts.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'Daily_Records_Audit',
      ),
    );
  }

  void _openRecordFilters() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          title: const Text('Filter Daily Records', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErpDropdownField<String>(
                label: 'Record Type',
                value: _typeFilter,
                items: const ['All', 'Expense', 'Income', 'Customer Collection', 'Supplier Payment', 'Wallet Transfer', 'Stock Adjustment'],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _typeFilter = val);
                    setState(() => _typeFilter = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _typeFilter = 'All');
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
              ),
              child: const Text('Apply', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDateFilter() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _dateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      AppToast.showInfo(
        context,
        'Showing records between ${DateFormat('dd MMM yyyy').format(picked.start)} and ${DateFormat('dd MMM yyyy').format(picked.end)}',
      );
    }
  }

  void _viewRecordDetails(DailyRecord r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.brandPrimary, size: 20),
            const SizedBox(width: 8),
            Text('Daily Voucher ${r.recordNo}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Date & Time', r.recordDate),
            _detailRow('Type', r.recordType),
            _detailRow('Category', r.category),
            _detailRow('Description', r.description),
            _detailRow('Amount', 'Rs ${_currencyFormat.format(r.amount)}'),
            _detailRow('Status', r.status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _records.where((r) {
      if (_typeFilter != 'All' && !r.recordType.toLowerCase().contains(_typeFilter.toLowerCase())) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return r.recordNo.toLowerCase().contains(_searchQuery) ||
          r.recordType.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery) ||
          r.category.toLowerCase().contains(_searchQuery);
    }).toList();

    // Financial totals
    double moneyIn = 0.0;
    double moneyOut = 0.0;
    for (final r in filteredRows) {
      if (r.status == 'Cancelled') continue;
      if (r.recordType == 'Income' || r.recordType == 'Customer Collection') {
        moneyIn += r.amount;
      } else if (r.recordType == 'Expense' || r.recordType == 'Supplier Payment') {
        moneyOut += r.amount;
      }
    }

    final double totalWalletBalance = _wallets.fold(0.0, (acc, w) => acc + w.balance);
    final double openingEstimated = totalWalletBalance - moneyIn + moneyOut;

    return ModulePage(
      title: 'Daily Records',
      subtitle: 'All daily money movements, with the correct wallet and accounting effect.',
      action: 'Add daily record',
      onAction: () => _openVoucherDialog('Add expense'),
      onExport: _exportDailyRecords,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Actions Grid (6 buttons)
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 1100 ? 3 : 6;
              final width = (constraints.maxWidth - (count - 1) * 8) / count;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions.map((a) {
                  return SizedBox(
                    width: width,
                    child: InkWell(
                      onTap: () => _openVoucherDialog(a[0]),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: AppIcons.icon(a[1], size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a[0],
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF344054),
                                ),
                              ),
                            ),
                            AppIcons.icon('arrow', size: 14, color: const Color(0xFFA2A9B5)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),

          // Day Summary Banner (Dark Navy)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.summaryNavy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SummaryBlock('Opening balance', 'Rs ${_currencyFormat.format(openingEstimated)}', Colors.white),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('+', style: TextStyle(fontSize: 16, color: Color(0xFF64718A))),
                  ),
                  _SummaryBlock('Money in', 'Rs ${_currencyFormat.format(moneyIn)}', const Color(0xFF6EE7A2)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('−', style: TextStyle(fontSize: 16, color: Color(0xFF64718A))),
                  ),
                  _SummaryBlock('Money out', 'Rs ${_currencyFormat.format(moneyOut)}', const Color(0xFFFDA4A4)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('=', style: TextStyle(fontSize: 16, color: Color(0xFF64718A))),
                  ),
                  _SummaryBlock('Current wallets', 'Rs ${_currencyFormat.format(totalWalletBalance)}', Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Table Card
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
                AppToolbar(
                  placeholder: 'Search daily records by transaction, party or category...',
                  onSearch: (q) {
                    setState(() => _searchQuery = q.trim().toLowerCase());
                    _loadData();
                  },
                  onFilter: _openRecordFilters,
                  onDateFilter: _openDateFilter,
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: AppTableSkeleton(rowCount: 6, columnCount: 6),
                  )
                else if (filteredRows.isEmpty)
                  AppEmptyState(
                    icon: 'calendar',
                    title: 'No daily records found',
                    message: _searchQuery.isEmpty
                        ? 'No financial entries recorded yet.'
                        : 'No transactions match "$_searchQuery".',
                    actionLabel: _searchQuery.isEmpty ? null : 'Clear search',
                    onAction: _searchQuery.isEmpty
                        ? null
                        : () {
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth > 850 ? constraints.maxWidth : 850,
                          ),
                          child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.4),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(2.0),
                          3: FlexColumnWidth(1.6),
                          4: FlexColumnWidth(1.2),
                          5: FlexColumnWidth(1.2),
                          6: FlexColumnWidth(1.3),
                          7: FixedColumnWidth(44),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: AppColors.tableHeaderBg,
                              border: Border.symmetric(
                                horizontal: BorderSide(color: AppColors.border),
                              ),
                            ),
                            children: const [
                              _HeaderCell('TRANSACTION'),
                              _HeaderCell('DATE & TIME'),
                              _HeaderCell('CATEGORY & DESCRIPTION'),
                              _HeaderCell('TYPE / PARTY'),
                              _HeaderCell('MONEY IN'),
                              _HeaderCell('MONEY OUT'),
                              _HeaderCell('STATUS / WALLET'),
                              _HeaderCell(''),
                            ],
                          ),
                          ...filteredRows.map((r) {
                            final isCancelled = r.status == 'Cancelled';
                            final isMoneyIn = r.recordType == 'Income' || r.recordType == 'Customer Collection';
                            final isMoneyOut = r.recordType == 'Expense' || r.recordType == 'Supplier Payment';

                            // Determine wallet name
                            String walletDisplay = 'Cash in Hand';
                            if (r.sourceWalletId != null) {
                              final match = _wallets.where((w) => w.id == r.sourceWalletId).toList();
                              if (match.isNotEmpty) walletDisplay = match.first.name;
                            } else if (r.destinationWalletId != null) {
                              final match = _wallets.where((w) => w.id == r.destinationWalletId).toList();
                              if (match.isNotEmpty) walletDisplay = match.first.name;
                            }

                            return TableRow(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.borderLight),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => _viewRecordDetails(r),
                                      child: Text(
                                        r.recordNo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          decoration: isCancelled ? TextDecoration.lineThrough : TextDecoration.underline,
                                          color: isCancelled ? AppColors.textMuted : AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(r.recordDate, style: AppTypography.body),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.category,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        r.description,
                                        style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(r.recordType, style: AppTypography.body),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(
                                    isMoneyIn ? 'Rs ${_currencyFormat.format(r.amount)}' : '—',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isMoneyIn ? FontWeight.w700 : FontWeight.w400,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: isCancelled
                                          ? AppColors.textMuted
                                          : (isMoneyIn ? AppColors.successText : AppColors.textSubtle),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(
                                    isMoneyOut ? 'Rs ${_currencyFormat.format(r.amount)}' : '—',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isMoneyOut ? FontWeight.w700 : FontWeight.w400,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: isCancelled
                                          ? AppColors.textMuted
                                          : (isMoneyOut ? AppColors.dangerText : AppColors.textSubtle),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: isCancelled
                                      ? const AppBadge(label: 'Cancelled', tone: BadgeTone.neutral)
                                      : Text(walletDisplay, style: AppTypography.body),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Record options',
                                    icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                                    onSelected: (action) {
                                      if (action == 'details') {
                                        _viewRecordDetails(r);
                                      } else if (action == 'cancel') {
                                        _cancelRecord(r);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Text('View Details',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      if (!isCancelled)
                                        const PopupMenuItem(
                                          value: 'cancel',
                                          child: Text('Cancel & Reverse Entry',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.danger,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryBlock(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF9AA8C0), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: AppTypography.tableHeader,
      ),
    );
  }
}
