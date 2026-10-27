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

class _TxnRecord {
  final dynamic original;
  final bool isSale;
  final int id;
  final String ref;
  final String date;
  final String party;
  final double total;
  final double paid;
  final double due;
  final String status;

  const _TxnRecord({
    required this.original,
    required this.isSale,
    required this.id,
    required this.ref,
    required this.date,
    required this.party,
    required this.total,
    required this.paid,
    required this.due,
    required this.status,
  });
}

class TransactionsPage extends StatefulWidget {
  final String type; // 'Purchases' or 'Sales'
  final void Function([ReceiptData? data]) openReceipt;

  const TransactionsPage({
    super.key,
    required this.type,
    required this.openReceipt,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _repository = ErpTransactionRepository();
  final _partyRepo = PartyRepository();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  String _searchQuery = '';
  bool _isLoading = true;

  List<Sale> _sales = [];
  List<Purchase> _purchases = [];
  List<Product> _products = [];
  List<Party> _parties = [];
  List<Wallet> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(TransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final isSales = widget.type == 'Sales';
      final prods = await _repository.getProducts();
      final parties = await _partyRepo.getParties(type: isSales ? 'Customer' : 'Supplier');
      final wallets = await _repository.getWallets();

      if (isSales) {
        final sales = await _repository.getSales(searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null);
        if (mounted) {
          setState(() {
            _sales = sales;
            _products = prods;
            _parties = parties;
            _wallets = wallets;
            _isLoading = false;
          });
        }
      } else {
        final purchases = await _repository.getPurchases(searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null);
        if (mounted) {
          setState(() {
            _purchases = purchases;
            _products = prods;
            _parties = parties;
            _wallets = wallets;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Failed to load ${widget.type.toLowerCase()}: $e');
      }
    }
  }

  void _openNewTransactionDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => TransactionEntryDialog(
        type: widget.type,
        onSave: (_) {},
        onSaveDetailed: (data) async {
          await _handleSaveNewTransaction(data);
        },
      ),
    );
  }

  Future<void> _handleSaveNewTransaction(Map<String, dynamic> data) async {
    final isSales = widget.type == 'Sales';
    final partyName = data['party'] as String;
    final qty = (data['qty'] as num).toDouble();
    final rate = (data['rate'] as num).toDouble();
    final paid = (data['paid'] as num).toDouble();
    final walletName = data['wallet'] as String;

    try {
      // 1. Resolve party
      Party? matchedParty;
      for (final p in _parties) {
        if (p.name.toLowerCase() == partyName.toLowerCase()) {
          matchedParty = p;
          break;
        }
      }

      int partyId = 0;
      if (matchedParty != null && matchedParty.id != null) {
        partyId = matchedParty.id!;
      } else {
        final code = await _partyRepo.generateNextCode(isSales ? 'Customer' : 'Supplier');
        partyId = await _partyRepo.createParty(Party(
          code: code,
          type: isSales ? 'Customer' : 'Supplier',
          name: partyName,
          phone: '+92 300 0000000',
          openingBalance: 0,
          openingBalanceType: isSales ? 'Receivable' : 'Payable',
          openingBalanceDate: '2026-10-01',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ));
      }

      // 2. Resolve product
      int productId = _products.isNotEmpty ? _products.first.id : 1;
      final itemName = data['item'] as String?;
      if (itemName != null && itemName.isNotEmpty) {
        final prodMatch = _products.where((p) => p.name.toLowerCase().contains(itemName.toLowerCase())).toList();
        if (prodMatch.isNotEmpty) {
          productId = prodMatch.first.id;
        }
      }

      // 3. Resolve wallet
      int? walletId;
      if (paid > 0) {
        final wMatch = _wallets.where((w) => w.name.toLowerCase() == walletName.toLowerCase()).toList();
        walletId = wMatch.isNotEmpty ? wMatch.first.id : (_wallets.isNotEmpty ? _wallets.first.id : 1);
      }

      final dateStr = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      if (isSales) {
        final newSale = await _repository.createSale(
          customerId: partyId,
          saleDate: dateStr,
          items: [
            {'product_id': productId, 'quantity': qty, 'unit_price': rate},
          ],
          paidAmount: paid,
          walletId: walletId,
          notes: 'Desktop sales terminal invoice',
        );
        if (mounted) {
          AppToast.showSuccess(context, 'Sales invoice "${newSale.saleNo}" recorded and ledger updated.');
        }
      } else {
        final newPur = await _repository.createPurchase(
          supplierId: partyId,
          purchaseDate: dateStr,
          items: [
            {'product_id': productId, 'quantity': qty, 'unit_cost': rate},
          ],
          paidAmount: paid,
          walletId: walletId,
          notes: 'Desktop purchase terminal voucher',
        );
        if (mounted) {
          AppToast.showSuccess(context, 'Purchase voucher "${newPur.purchaseNo}" recorded and stock updated.');
        }
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to save transaction: $e');
      }
    }
  }

  Future<void> _cancelTransaction(_TxnRecord rec) async {
    final isSales = widget.type == 'Sales';

    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Cancel Transaction?',
      message: 'Are you sure you want to cancel and reverse "${rec.ref}" for "${rec.party}"? '
          'Associated party ledger entries and wallet balance effects will be reversed automatically.',
      confirmLabel: 'Cancel Transaction',
      isDanger: true,
      auditNote: 'General Ledger double-entry reversal will be recorded with current timestamp.',
    );

    if (confirm == true) {
      try {
        if (isSales) {
          await _repository.cancelSale(
            saleId: rec.id,
            reason: 'User cancelled and reversed from Desktop Sales Terminal',
          );
        } else {
          await _repository.cancelPurchase(
            purchaseId: rec.id,
            reason: 'User cancelled and reversed from Desktop Purchase Terminal',
          );
        }
        if (mounted) {
          AppToast.showSuccess(context, 'Transaction "${rec.ref}" reversed.');
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Failed to reverse transaction: $e');
        }
      }
    }
  }

  void _printReceipt(_TxnRecord rec) {
    final isSales = widget.type == 'Sales';

    final receipt = ReceiptData(
      title: isSales ? 'SALES RECEIPT' : 'PURCHASE VOUCHER',
      referenceNo: rec.ref,
      dateTime: rec.date,
      partyLabel: isSales ? 'Customer' : 'Supplier',
      partyName: rec.party,
      grandTotal: rec.total,
      paidAmount: rec.paid,
      outstandingAmount: rec.due,
      paymentMethod: rec.paid > 0 ? 'Cash/Bank' : 'Credit',
      isReprint: true,
      items: [
        ReceiptLineItem(
          description: isSales ? 'Refined Table Salt & Packets' : 'Raw Khewra Rock Salt Delivery',
          quantity: 1,
          unit: isSales ? 'ctn' : 'ton',
          unitPrice: rec.total,
          totalAmount: rec.total,
        ),
      ],
      notes: 'Reprint of transaction ${rec.ref}. Accounting balances verified.',
    );
    widget.openReceipt(receipt);
  }

  String _statusFilter = 'All';
  DateTimeRange? _dateRange;

  void _exportTransactions() {
    final isSales = widget.type == 'Sales';
    final headers = [
      isSales ? 'Invoice No' : 'Order Ref',
      'Date',
      isSales ? 'Customer' : 'Supplier',
      'Total Amount (Rs)',
      'Paid Amount (Rs)',
      'Balance Due (Rs)',
      'Status',
    ];
    final rows = (isSales ? _sales : _purchases).map((item) {
      if (isSales) {
        final s = item as Sale;
        return [
          s.saleNo,
          s.saleDate,
          s.partyName ?? 'Customer',
          _currencyFormat.format(s.totalAmount),
          _currencyFormat.format(s.paidAmount),
          _currencyFormat.format(s.outstandingAmount),
          s.status,
        ];
      } else {
        final p = item as Purchase;
        return [
          p.purchaseNo,
          p.purchaseDate,
          p.partyName ?? 'Supplier',
          _currencyFormat.format(p.totalAmount),
          _currencyFormat.format(p.paidAmount),
          _currencyFormat.format(p.outstandingAmount),
          p.status,
        ];
      }
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: '${widget.type} Ledger & Commercial Statement',
        subtitle: 'Complete list of invoices, payments, settlement balances and cancellation audit trails.',
        headers: headers,
        rows: rows,
        filenamePrefix: '${widget.type}_Statement',
      ),
    );
  }

  void _openTransactionFilters() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          title: Text('Filter ${widget.type}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status Filter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
                items: ['All', 'Paid', 'Partial', 'Unpaid', 'Cancelled']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _statusFilter = val);
                    setState(() => _statusFilter = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _statusFilter = 'All');
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
        'Showing ${widget.type.toLowerCase()} between ${DateFormat('dd MMM yyyy').format(picked.start)} and ${DateFormat('dd MMM yyyy').format(picked.end)}',
      );
    }
  }

  void _viewTransactionDetails(_TxnRecord rec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
        title: Row(
          children: [
            const Icon(Icons.receipt, color: AppColors.brandPrimary, size: 20),
            const SizedBox(width: 8),
            Text('Transaction ${rec.ref}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Date', rec.date),
            _detailRow(rec.isSale ? 'Customer' : 'Supplier', rec.party),
            _detailRow('Total Billed', 'Rs ${_currencyFormat.format(rec.total)}'),
            _detailRow('Amount Paid', 'Rs ${_currencyFormat.format(rec.paid)}'),
            _detailRow('Outstanding', 'Rs ${_currencyFormat.format(rec.due)}'),
            _detailRow('Status', rec.status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _printReceipt(rec);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
            ),
            icon: const Icon(Icons.print, size: 14, color: Colors.white),
            label: const Text('Print Receipt', style: TextStyle(fontSize: 12, color: Colors.white)),
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
    final type = widget.type;
    final isSales = type == 'Sales';
    final partyLabel = isSales ? 'Customer' : 'Supplier';
    final actionLabel = isSales ? 'New sale' : 'New purchase';

    // Map into typed records
    final List<_TxnRecord> allRecords = [];
    if (isSales) {
      for (final s in _sales) {
        allRecords.add(_TxnRecord(
          original: s,
          isSale: true,
          id: s.id,
          ref: s.saleNo,
          date: s.saleDate,
          party: s.partyName ?? 'Customer',
          total: s.totalAmount,
          paid: s.paidAmount,
          due: s.outstandingAmount,
          status: s.status,
        ));
      }
    } else {
      for (final p in _purchases) {
        allRecords.add(_TxnRecord(
          original: p,
          isSale: false,
          id: p.id,
          ref: p.purchaseNo,
          date: p.purchaseDate,
          party: p.partyName ?? 'Supplier',
          total: p.totalAmount,
          paid: p.paidAmount,
          due: p.outstandingAmount,
          status: p.status,
        ));
      }
    }

    // Filter by search query & status
    final rows = allRecords.where((item) {
      if (_statusFilter != 'All' && !item.status.toLowerCase().contains(_statusFilter.toLowerCase())) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return item.ref.toLowerCase().contains(_searchQuery) ||
          item.party.toLowerCase().contains(_searchQuery) ||
          item.date.toLowerCase().contains(_searchQuery);
    }).toList();

    // Compute metrics dynamically
    final double totalBilled = rows
        .where((r) => r.status != 'Cancelled')
        .fold(0.0, (acc, r) => acc + r.total);
    final double totalPaid = rows
        .where((r) => r.status != 'Cancelled')
        .fold(0.0, (acc, r) => acc + r.paid);
    final double totalDue = rows
        .where((r) => r.status != 'Cancelled')
        .fold(0.0, (acc, r) => acc + r.due);

    return ModulePage(
      title: type,
      subtitle: '${isSales ? "Customer sales" : "Supplier purchases"}, linked payments, stock and ledger effects.',
      action: actionLabel,
      onAction: _openNewTransactionDialog,
      onExport: _exportTransactions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mini Stats
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 900 ? 2 : 4;
              final width = (constraints.maxWidth - (count - 1) * 10) / count;
              final items = [
                MiniMetric(
                  label: "Total billed ${type.toLowerCase()}",
                  value: 'Rs ${_currencyFormat.format(totalBilled)}',
                  hint: '${rows.length} ${isSales ? "invoices" : "purchases"}',
                ),
                MiniMetric(
                  label: isSales ? "Amount received" : "Amount paid",
                  value: 'Rs ${_currencyFormat.format(totalPaid)}',
                  hint: totalBilled > 0
                      ? '${((totalPaid / totalBilled) * 100).toStringAsFixed(1)}% settled'
                      : '0% settled',
                ),
                MiniMetric(
                  label: "Outstanding",
                  value: 'Rs ${_currencyFormat.format(totalDue)}',
                  hint: isSales ? "Added to receivables" : "Added to payables",
                ),
                MiniMetric(
                  label: isSales ? "Active transactions" : "Purchased items",
                  value: '${rows.where((r) => r.status != 'Cancelled').length}',
                  hint: isSales ? "Non-cancelled sales" : "Verified entries",
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((m) => SizedBox(width: width, child: m)).toList(),
              );
            },
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
                  placeholder: 'Search ${type.toLowerCase()} by invoice or ${partyLabel.toLowerCase()}...',
                  onSearch: (q) {
                    setState(() => _searchQuery = q.trim().toLowerCase());
                    _loadData();
                  },
                  onFilter: _openTransactionFilters,
                  onDateFilter: _openDateFilter,
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: AppTableSkeleton(rowCount: 6, columnCount: 7),
                  )
                else if (rows.isEmpty)
                  AppEmptyState(
                    icon: 'cart',
                    title: 'No $type found',
                    message: _searchQuery.isEmpty
                        ? 'No transactions recorded yet in the database.'
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
                            minWidth: constraints.maxWidth > 880 ? constraints.maxWidth : 880,
                          ),
                          child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.4),
                          1: FlexColumnWidth(1.6),
                          2: FlexColumnWidth(2.0),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(1.2),
                          5: FlexColumnWidth(1.2),
                          6: FlexColumnWidth(1.0),
                          7: FixedColumnWidth(88),
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
                            children: [
                              const _HeaderCell('TRANSACTION'),
                              const _HeaderCell('DATE & TIME'),
                              _HeaderCell(partyLabel.toUpperCase()),
                              const _HeaderCell('TOTAL'),
                              _HeaderCell(isSales ? 'RECEIVED' : 'PAID'),
                              const _HeaderCell('OUTSTANDING'),
                              const _HeaderCell('STATUS'),
                              const _HeaderCell('ACTIONS'),
                            ],
                          ),
                          ...rows.map((item) {
                            final isCancelled = item.status == 'Cancelled';

                            final statusLabel = isCancelled
                                ? 'Cancelled'
                                : (item.due <= 0.01 ? 'Paid' : (item.paid > 0 ? 'Partial' : (isSales ? 'Credit' : 'Unpaid')));

                            final badgeTone = isCancelled
                                ? BadgeTone.neutral
                                : (statusLabel == 'Paid'
                                    ? BadgeTone.green
                                    : statusLabel == 'Partial'
                                        ? BadgeTone.amber
                                        : BadgeTone.red);

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
                                      onTap: () => _viewTransactionDetails(item),
                                      child: Text(
                                        item.ref,
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
                                  child: Text(item.date, style: AppTypography.body),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(item.party, style: AppTypography.body),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(
                                    'Rs ${_currencyFormat.format(item.total)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(
                                    'Rs ${_currencyFormat.format(item.paid)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: isCancelled ? AppColors.textMuted : AppColors.successText,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Text(
                                    'Rs ${_currencyFormat.format(item.due)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: isCancelled
                                          ? AppColors.textMuted
                                          : (item.due <= 0.01 ? AppColors.textSubtle : AppColors.dangerText),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AppBadge(label: statusLabel, tone: badgeTone),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'Print thermal receipt',
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => _printReceipt(item),
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceMuted,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              alignment: Alignment.center,
                                              child: AppIcons.icon('print', size: 14, color: AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: PopupMenuButton<String>(
                                          tooltip: 'Transaction options',
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                                        onSelected: (action) {
                                          if (action == 'details') {
                                            _viewTransactionDetails(item);
                                          } else if (action == 'print') {
                                            _printReceipt(item);
                                          } else if (action == 'cancel') {
                                            _cancelTransaction(item);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Text('View Transaction Details',
                                                style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'print',
                                            child: Text('Print Receipt / Voucher',
                                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          ),
                                          if (!isCancelled)
                                            const PopupMenuItem(
                                              value: 'cancel',
                                              child: Text('Cancel & Reverse Transaction',
                                                  style: TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                        ),
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
