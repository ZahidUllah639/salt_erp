import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';
import '../repositories/erp_transaction_repository.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  final _repository = ErpTransactionRepository();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  String _statusFilter = 'All';
  bool _isLoading = true;

  List<ProductionBatch> _batches = [];
  List<Product> _products = [];

  static const List<List<String>> costRows = [
    ["Raw salt", "10 kg × Rs 5.10", "Rs 51.00"],
    ["Empty packets", "10 × Rs 2.00", "Rs 20.00"],
    ["Outer wrapping", "1 × Rs 7.00", "Rs 7.00"],
    ["Electricity", "Allocation", "Rs 10.00"],
    ["Labour", "Allocation", "Rs 9.00"],
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _repository.getProductionBatches();
      final products = await _repository.getProducts();

      if (mounted) {
        setState(() {
          _batches = batches;
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Failed to load production batches: $e');
      }
    }
  }

  void _openRecordProductionDialog() {
    final finishedNames = _products
        .where((p) => p.category == 'Finished goods')
        .map((p) => p.name)
        .toList();
    showDialog<bool>(
      context: context,
      builder: (ctx) => ProductionBatchDialog(
        products: finishedNames.isNotEmpty ? finishedNames : null,
        onSave: (batchData) async {
          await _handleSaveBatch(batchData);
        },
      ),
    );
  }

  void _exportProductionLog() {
    final headers = [
      'Batch Identifier',
      'Date / Shift',
      'Finished Product',
      'Shift',
      'Reported Output',
      'Verified Output',
      'Labour & Power Cost',
      'Status',
    ];
    final rows = _batches.map((b) {
      final prod = _products.firstWhere(
        (p) => p.id == b.finishedProductId,
        orElse: () => _products.first,
      );
      return [
        b.batchNo,
        b.batchDate,
        prod.name,
        b.shift,
        '${b.reportedQty.toStringAsFixed(0)} pkts',
        '${b.verifiedQty.toStringAsFixed(0)} pkts',
        'Rs ${b.totalCost.toStringAsFixed(0)}',
        b.status,
      ];
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'Production Batches & Manufacturing Yield Log',
        subtitle: 'Audit record of factory production shifts, recipe consumption, and unit output.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'Production_Batches',
      ),
    );
  }

  Future<void> _handleSaveBatch(Map<String, dynamic> data) async {
    try {
      final productName = data['product'] as String? ?? 'HGM Pink Salt 800g × 24';
      final shift = data['shift'] as String? ?? 'Morning Shift';
      final producedQty = (data['producedQty'] as num?)?.toDouble() ?? 600.0;
      final rawSaltKg = (data['rawSaltKg'] as num?)?.toDouble() ?? 620.0;
      final packetsUsed = (data['packetsUsed'] as num?)?.toDouble() ?? 600.0;
      final labourCost = (data['labourCost'] as num?)?.toDouble() ?? 5400.0;

      // Find finished product
      final finishedProduct = _products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName.toLowerCase()) || p.category == 'Finished goods',
        orElse: () => _products.isNotEmpty ? _products.first : const Product(
          id: 1,
          code: 'FG-080024',
          name: 'HGM Pink Salt 800g × 24',
          category: 'Finished goods',
          baseUnit: 'Packet',
          currentStock: 0,
          averageCost: 76.4,
          createdAt: '',
          updatedAt: '',
        ),
      );

      // Find raw salt & packaging
      final rawSaltProd = _products.firstWhere(
        (p) => p.category == 'Raw salt' || p.name.toLowerCase().contains('raw'),
        orElse: () => _products.first,
      );
      final pkgProd = _products.firstWhere(
        (p) => p.category == 'Packaging' || p.name.toLowerCase().contains('packet'),
        orElse: () => _products.first,
      );

      final dateStr = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      final newBatch = await _repository.createProductionBatch(
        finishedProductId: finishedProduct.id,
        batchDate: dateStr,
        shift: shift,
        reportedQty: producedQty,
        verifiedQty: producedQty,
        rejectedQty: 0.0,
        consumedItems: [
          {
            'product_id': rawSaltProd.id,
            'item_type': 'Raw Material',
            'quantity_consumed': rawSaltKg,
            'unit_cost': rawSaltProd.averageCost,
          },
          {
            'product_id': pkgProd.id,
            'item_type': 'Packaging',
            'quantity_consumed': packetsUsed,
            'unit_cost': pkgProd.averageCost,
          },
        ],
        allocationLaborCost: labourCost,
        allocationPowerCost: 1500.0,
        notes: 'Desktop production terminal batch run',
      );

      if (mounted) {
        AppToast.showSuccess(context, 'Production batch "${newBatch.batchNo}" recorded and stock updated.');
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to record batch: $e');
      }
    }
  }

  void _openBatchFilters() {
    final nextFilter = _statusFilter == 'All'
        ? 'Verified'
        : (_statusFilter == 'Verified' ? 'Discrepancy' : 'All');
    setState(() => _statusFilter = nextFilter);
    AppToast.showInfo(context, 'Production batches filtered by: $nextFilter');
  }

  Future<void> _verifyBatch(ProductionBatch batch) async {
    try {
      // Re-verify batch with zero rejection
      await _repository.updateProductionBatch(
        batchId: batch.id,
        newReportedQty: batch.reportedQty,
        newVerifiedQty: batch.reportedQty,
        newRejectedQty: 0.0,
        newConsumedItems: batch.consumedItems.map((ci) => {
          'product_id': ci.productId,
          'item_type': ci.itemType,
          'quantity_consumed': ci.quantityConsumed,
          'unit_cost': ci.unitCost,
        }).toList(),
        allocationLaborCost: 5400.0,
        newNotes: 'Batch verified and reconciled with warehouse stock by terminal operator',
        reason: 'Physical count verified discrepancy resolved',
      );
      if (mounted) {
        AppToast.showSuccess(context, 'Batch ${batch.batchNo} output verified and reconciled with stock.');
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to verify batch: $e');
      }
    }
  }

  Future<void> _cancelBatch(ProductionBatch batch) async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Cancel Production Batch?',
      message: 'Are you sure you want to cancel and reverse "${batch.batchNo}"? '
          'Finished goods will be deducted from inventory and raw materials returned to stock in the audit trail.',
      confirmLabel: 'Cancel Batch',
      isDanger: true,
      auditNote: 'General ledger journal reversal will be created automatically.',
    );

    if (confirm == true) {
      try {
        await _repository.cancelProductionBatch(
          batchId: batch.id,
          reason: 'Desktop operator cancellation',
        );
        if (mounted) {
          AppToast.showSuccess(context, 'Production batch ${batch.batchNo} reversed successfully.');
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Failed to reverse batch: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: 'Packaging & Production',
      subtitle: 'Record batches, recipe consumption and verified output.',
      action: 'Record production',
      onAction: _openRecordProductionDialog,
      onExport: _exportProductionLog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Production Grid (Flow + Recipe)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 950;
              final flowWidget = _buildFlowCard();
              final recipeWidget = _buildRecipeCard();

              if (isCompact) {
                return Column(
                  children: [
                    flowWidget,
                    const SizedBox(height: 12),
                    recipeWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: flowWidget),
                  const SizedBox(width: 12),
                  SizedBox(width: 320, child: recipeWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Batches Table Card
          _buildBatchesTableCard(),
        ],
      ),
    );
  }

  Widget _buildFlowCard() {
    // Dynamic stock calculations from loaded products
    double rawStock = 0.0;
    double finishedStock = 0.0;
    double negativeStock = 0.0;

    for (final p in _products) {
      if (p.category == 'Raw salt') {
        rawStock += p.currentStock;
      } else if (p.category == 'Finished goods') {
        if (p.currentStock < 0) {
          negativeStock += p.currentStock;
        } else {
          finishedStock += p.currentStock;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Live Inventory & Production Reconciliation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time physical stock tracking and batch output synchronization',
                        style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppBadge(
                  label: negativeStock < 0 ? 'Deficit detected' : 'Stock balanced',
                  tone: negativeStock < 0 ? BadgeTone.amber : BadgeTone.green,
                ),
              ],
            ),
          ),

          // Flow Steps
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(
                children: [
                  _buildTrackStep('Raw salt available', NumberFormat('#,##0').format(rawStock), 'kg'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(fontSize: 18, color: Color(0xFF9BA4B3))),
                  ),
                  _buildTrackStep(
                    'Order deficit',
                    negativeStock < 0 ? NumberFormat('#,##0').format(negativeStock.abs()) : '0',
                    'packets',
                    isNegative: negativeStock < 0,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('+', style: TextStyle(fontSize: 18, color: Color(0xFF9BA4B3))),
                  ),
                  _buildTrackStep(
                    'Batches recorded',
                    '${_batches.where((b) => b.status != 'Cancelled').length}',
                    'runs',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('=', style: TextStyle(fontSize: 18, color: Color(0xFF9BA4B3))),
                  ),
                  _buildTrackStep(
                    'Finished stock',
                    NumberFormat('#,##0').format(finishedStock),
                    'units',
                    isPositive: finishedStock > 0,
                  ),
                ],
              ),
            ),
          ),

          // Audit note
          Container(
            margin: const EdgeInsets.fromLTRB(18, 2, 18, 16),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FAF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                AppIcons.icon('check', size: 17, color: const Color(0xFF29784B)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'All batch production directly credits finished goods inventory while deducting raw salt and packaging materials via atomic SQLite stock movements.',
                    style: TextStyle(fontSize: 9, color: Color(0xFF29784B), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackStep(String label, String value, String unit, {bool isNegative = false, bool isPositive = false}) {
    Color bg = const Color(0xFFF7F8FA);
    Color border = AppColors.border;
    Color valColor = AppColors.text;

    if (isNegative) {
      bg = const Color(0xFFFFF5F3);
      border = const Color(0xFFF7D5CF);
      valColor = AppColors.red;
    } else if (isPositive) {
      bg = const Color(0xFFF0FBF5);
      border = const Color(0xFFCFEBDC);
      valColor = AppColors.green;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF748094))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(unit, style: const TextStyle(fontSize: 8, color: Color(0xFF8E98A7))),
        ],
      ),
    );
  }

  Widget _buildRecipeCard() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Head
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cost recipe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '10 kg salt packet • v4 standard',
                        style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Standard BOM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Cost rows
          ...costRows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r[0], style: const TextStyle(fontSize: 9, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(r[1], style: const TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      ],
                    ),
                    Text(
                      r[2],
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ],
                ),
              )),

          // Cost Total
          Container(
            margin: const EdgeInsets.fromLTRB(18, 7, 18, 0),
            padding: const EdgeInsets.only(top: 9),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Text(
                    'Total unit production cost',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
                Text(
                  'Rs 97.00',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF174FAE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesTableCard() {
    final filteredBatches = _batches.where((b) {
      if (_statusFilter == 'All') return true;
      return b.status == _statusFilter;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Head
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Recent production batches',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reported, verified and corrected factory output',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                    ),
                  ],
                ),
                AppButton(
                  label: _statusFilter == 'All' ? 'Filters' : 'Filter: $_statusFilter',
                  icon: 'filter',
                  variant: ButtonVariant.secondary,
                  onClick: _openBatchFilters,
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: AppTableSkeleton(rowCount: 6, columnCount: 6),
            )
          else if (filteredBatches.isEmpty)
            AppEmptyState(
              icon: 'truck',
              title: 'No production batches found',
              message: _statusFilter == 'All'
                  ? 'No production batches recorded yet.'
                  : 'No batches match filter "$_statusFilter".',
              actionLabel: _statusFilter == 'All' ? null : 'Clear filter',
              onAction: _statusFilter == 'All' ? null : () => setState(() => _statusFilter = 'All'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth > 860 ? constraints.maxWidth : 860,
                    ),
                    child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.6),
                    2: FlexColumnWidth(2.0),
                    3: FlexColumnWidth(1.0),
                    4: FlexColumnWidth(1.0),
                    5: FlexColumnWidth(1.0),
                    6: FlexColumnWidth(1.2),
                    7: FlexColumnWidth(1.2),
                    8: FixedColumnWidth(44),
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
                        _HeaderCell('BATCH'),
                        _HeaderCell('DATE / SHIFT'),
                        _HeaderCell('FINISHED PRODUCT'),
                        _HeaderCell('REPORTED'),
                        _HeaderCell('VERIFIED'),
                        _HeaderCell('REJECTED'),
                        _HeaderCell('COST'),
                        _HeaderCell('STATUS'),
                        _HeaderCell(''),
                      ],
                    ),
                    ...filteredBatches.map((b) {
                      final isVerified = b.status == 'Verified';
                      final isCancelled = b.status == 'Cancelled';

                      // Find product name
                      String prodName = 'Finished Product #${b.finishedProductId}';
                      final match = _products.where((p) => p.id == b.finishedProductId).toList();
                      if (match.isNotEmpty) prodName = match.first.name;

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.borderLight),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              b.batchNo,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                color: isCancelled ? AppColors.textMuted : const Color(0xFF273246),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text('${b.batchDate.substring(0, 10)} • ${b.shift}', style: const TextStyle(fontSize: 10.5, color: AppColors.textTable)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(prodName, style: const TextStyle(fontSize: 10.5, color: AppColors.textTable)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text('${b.reportedQty.toStringAsFixed(0)} pkts', style: const TextStyle(fontSize: 10.5, color: AppColors.textTable)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              '${b.verifiedQty.toStringAsFixed(0)} pkts',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF273246)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(b.rejectedQty.toStringAsFixed(0), style: const TextStyle(fontSize: 10.5, color: AppColors.textTable)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text('Rs ${_currencyFormat.format(b.totalCost)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textTable)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AppBadge(
                                label: b.status,
                                tone: isCancelled
                                    ? BadgeTone.neutral
                                    : (isVerified ? BadgeTone.green : BadgeTone.amber),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            child: !isCancelled
                                ? PopupMenuButton<String>(
                                    tooltip: 'Batch actions',
                                    icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                                    onSelected: (action) {
                                      if (action == 'verify') {
                                        _verifyBatch(b);
                                      } else if (action == 'cancel') {
                                        _cancelBatch(b);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      if (!isVerified)
                                        const PopupMenuItem(
                                          value: 'verify',
                                          child: Text('Verify & Reconcile Output', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                        ),
                                      const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel & Reverse Batch', style: TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  )
                                : const SizedBox(width: 24),
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
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textHeader,
        ),
      ),
    );
  }
}
