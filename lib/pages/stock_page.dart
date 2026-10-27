import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../repositories/erp_transaction_repository.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';

class StockPage extends StatefulWidget {
  final ErpTransactionRepository? repository;

  const StockPage({super.key, this.repository});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final ErpTransactionRepository _repository;
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _healthFilter = 'All';
  String _dateFilter = 'This month';
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final _numberFormat = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ErpTransactionRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stock balances: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openStockProfile(Product p) {
    showDialog(
      context: context,
      builder: (ctx) => StockProfileDialog(
        product: p,
        repository: _repository,
        onStockAdjusted: _loadData,
      ),
    );
  }

  void _openStockAdjustmentDialog([String? defaultProduct]) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => StockAdjustmentDialog(
        products: _products.map((p) => p.name).toList(),
        initialProduct: defaultProduct,
        onSave: (adj) async {
          final productName = adj['product'] as String;
          final isPositive = adj['isPositive'] as bool;
          final qty = adj['quantity'] as double;
          final reason = adj['reason'] as String;
          final memo = adj['notes'] as String?;

          final p = _products.firstWhere(
            (item) => item.name == productName,
            orElse: () => _products.first,
          );

          try {
            final newCount = isPositive ? (p.currentStock + qty) : (p.currentStock - qty);
            final fullReason = '$reason${memo != null && memo.isNotEmpty ? " • $memo" : ""}';
            await _repository.createStockAdjustment(
              productId: p.id,
              adjustmentDate: DateTime.now().toIso8601String().substring(0, 10),
              adjustmentType: isPositive ? 'Physical Count Discrepancy' : 'Damage',
              countedQuantity: newCount,
              reason: fullReason,
              operatorName: 'Warehouse Supervisor',
            );
            await _loadData();
            if (mounted) {
              AppToast.showSuccess(
                context,
                'Stock adjustment of ${isPositive ? "+" : "-"}${_numberFormat.format(qty)} ${p.baseUnit} recorded for "${p.name}".',
              );
            }
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Failed to post stock adjustment: $e');
            }
          }
        },
      ),
    );
  }

  void _reviewMovements() {
    final negativeItems = _products.where((p) => p.currentStock < 0).toList();
    setState(() {
      _healthFilter = 'Negative';
      _searchQuery = '';
    });
    if (negativeItems.isNotEmpty) {
      _openStockProfile(negativeItems.first);
      AppToast.showInfo(
        context,
        'Opened stock profile for "${negativeItems.first.name}". Record manufacturing shifts to resolve negative deficit.',
      );
    } else {
      AppToast.showSuccess(context, 'Inventory reconciled: No negative stock balances detected.');
    }
  }

  void _exportStockReport() {
    final headers = [
      'Product Code',
      'Product Name',
      'Category',
      'Available Stock',
      'Base Unit',
      'Average Cost (Rs)',
      'Stock Value (Rs)',
      'Health Status',
    ];
    final rows = _products.map((p) {
      final isNegative = p.currentStock < 0;
      final isLow = p.currentStock <= 100 && !isNegative;
      final status = isNegative ? 'Negative' : (isLow ? 'Low' : 'Healthy');
      final val = p.currentStock * p.averageCost;
      return [
        p.code,
        p.name,
        p.category,
        _numberFormat.format(p.currentStock),
        p.baseUnit,
        p.averageCost.toStringAsFixed(2),
        _currencyFormat.format(val),
        status,
      ];
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'Stock Valuation & Inventory Balances',
        subtitle: 'Complete list of raw salt, packaging materials, and finished goods inventory.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'Stock_Valuation',
      ),
    );
  }

  void _openFiltersModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          title: const Text('Filter Stock Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['All', 'Finished goods', 'Raw salt', 'Packaging'].map((cat) {
                  final isSel = _categoryFilter == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                    selected: isSel,
                    selectedColor: AppColors.brandLight,
                    onSelected: (_) {
                      setDialogState(() => _categoryFilter = cat);
                      setState(() => _categoryFilter = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Stock Health Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['All', 'Healthy', 'Low', 'Negative'].map((h) {
                  final isSel = _healthFilter == h;
                  return ChoiceChip(
                    label: Text(h, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                    selected: isSel,
                    selectedColor: h == 'Negative' ? const Color(0xFFFEE2E2) : AppColors.brandLight,
                    onSelected: (_) {
                      setDialogState(() => _healthFilter = h);
                      setState(() => _healthFilter = h);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _categoryFilter = 'All';
                  _healthFilter = 'All';
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDateFilterModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
        title: const Text('Select Accounting Period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['This month', 'Today', 'This week', 'This quarter', 'All time'].map((period) {
            final isSel = _dateFilter == period;
            return ListTile(
              dense: true,
              title: Text(period, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
              trailing: isSel ? const Icon(Icons.check, size: 16, color: AppColors.brandPrimary) : null,
              onTap: () {
                setState(() => _dateFilter = period);
                Navigator.of(ctx).pop();
                AppToast.showInfo(context, 'Stock ledger period set to: $period');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      if (_categoryFilter != 'All' && p.category.toLowerCase() != _categoryFilter.toLowerCase()) {
        return false;
      }
      final isNegative = p.currentStock < 0;
      final isLow = p.currentStock <= 100 && !isNegative;
      final isHealthy = !isNegative && !isLow;

      if (_healthFilter == 'Negative' && !isNegative) return false;
      if (_healthFilter == 'Low' && !isLow) return false;
      if (_healthFilter == 'Healthy' && !isHealthy) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final health = isNegative ? 'negative' : (isLow ? 'low' : 'healthy');
      return p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          health.contains(q);
    }).toList();

    final negativeItems = _products.where((p) => p.currentStock < 0).toList();
    final totalValue = _products.fold<double>(
      0.0,
      (sum, p) => sum + (p.currentStock > 0 ? p.currentStock * p.averageCost : 0.0),
    );
    final rawSaltStock = _products
        .where((p) => p.category.toLowerCase().contains('raw'))
        .fold<double>(0.0, (sum, p) => sum + p.currentStock);
    final finishedStock = _products
        .where((p) => p.category.toLowerCase().contains('finish'))
        .fold<double>(0.0, (sum, p) => sum + p.currentStock);
    final lowStockCount = _products.where((p) => p.currentStock <= 100).length;

    final filterCount = (_categoryFilter != 'All' ? 1 : 0) + (_healthFilter != 'All' ? 1 : 0);

    return ModulePage(
      title: 'Stock Management',
      subtitle: 'One source of truth for every material and finished product.',
      action: 'Stock adjustment',
      onAction: () => _openStockAdjustmentDialog(),
      onExport: _exportStockReport,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Danger Notice (shown only when negative stock exists)
          if (negativeItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DangerNotice(
                title: '${negativeItems.length} product(s) have negative stock',
                message: 'Sales were recorded before production. Record pending production shifts to reconcile inventory without modifying original sales vouchers.',
                actionLabel: 'Review movements',
                onAction: _reviewMovements,
              ),
            ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DangerNotice(
                title: 'Stock Notice',
                message: _errorMessage!,
                actionLabel: 'Retry',
                onAction: _loadData,
              ),
            ),

          // Mini stats (4 cards calculated from real database)
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 900 ? 2 : 4;
              final width = (constraints.maxWidth - (count - 1) * 10) / count;
              final items = [
                MiniMetric(
                  label: 'Total stock value',
                  value: 'Rs ${_currencyFormat.format(totalValue)}',
                  hint: '${_products.length} catalog items evaluated',
                ),
                MiniMetric(
                  label: 'Raw salt reserve',
                  value: '${_numberFormat.format(rawSaltStock)} kg',
                  hint: 'Bulk warehouse stock',
                ),
                MiniMetric(
                  label: 'Finished goods',
                  value: '${_numberFormat.format(finishedStock)} units',
                  hint: negativeItems.isNotEmpty ? '${negativeItems.length} negative balance' : 'Reconciled',
                  alert: negativeItems.isNotEmpty,
                ),
                MiniMetric(
                  label: 'Low-stock items',
                  value: '$lowStockCount',
                  hint: lowStockCount > 0 ? 'Reorder action required' : 'Stock levels adequate',
                  alert: lowStockCount > 0,
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
                  placeholder: 'Search stock by product, SKU, or health status...',
                  onSearch: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                  onFilter: _openFiltersModal,
                  onDateFilter: _openDateFilterModal,
                  filterCount: filterCount,
                  activeDateLabel: _dateFilter,
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppTableSkeleton(rowCount: 6, columnCount: 7),
                  )
                else if (filteredProducts.isEmpty)
                  AppEmptyState(
                    icon: 'search',
                    title: 'No inventory items found',
                    message: _searchQuery.isNotEmpty
                        ? 'No products match "$_searchQuery".'
                        : (_categoryFilter != 'All' || _healthFilter != 'All'
                            ? 'No products match the selected filters.'
                            : 'No inventory items recorded in database.'),
                    actionLabel: _searchQuery.isNotEmpty || filterCount > 0 ? 'Clear filters' : 'Adjust stock',
                    onAction: _searchQuery.isNotEmpty || filterCount > 0
                        ? () => setState(() {
                              _searchQuery = '';
                              _categoryFilter = 'All';
                              _healthFilter = 'All';
                            })
                        : () => _openStockAdjustmentDialog(),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth > 900 ? constraints.maxWidth : 900,
                          ),
                          child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.2),
                          1: FlexColumnWidth(1.3),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(1.1),
                          5: FlexColumnWidth(1.2),
                          6: FlexColumnWidth(1.0),
                          7: FixedColumnWidth(48),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          // Header
                          const TableRow(
                            decoration: BoxDecoration(
                              color: AppColors.tableHeaderBg,
                              border: Border.symmetric(
                                horizontal: BorderSide(color: AppColors.border),
                              ),
                            ),
                            children: [
                              _HeaderCell('PRODUCT'),
                              _HeaderCell('CATEGORY'),
                              _HeaderCell('AVAILABLE'),
                              _HeaderCell('BASE UNIT'),
                              _HeaderCell('AVG. COST'),
                              _HeaderCell('STOCK VALUE'),
                              _HeaderCell('HEALTH'),
                              _HeaderCell(''),
                            ],
                          ),
                          // Rows
                          ...filteredProducts.map((p) {
                            final isNegative = p.currentStock < 0;
                            final isLow = p.currentStock <= 100 && !isNegative;
                            final isHealthy = !isNegative && !isLow;
                            final badgeTone = isHealthy
                                ? BadgeTone.green
                                : isNegative
                                    ? BadgeTone.red
                                    : BadgeTone.amber;

                            final stockValue = p.currentStock * p.averageCost;

                            return TableRow(
                              decoration: BoxDecoration(
                                color: isNegative ? const Color(0xFFFEF2F2) : Colors.transparent,
                                border: Border(
                                  bottom: const BorderSide(color: AppColors.borderLight),
                                  left: isNegative
                                      ? const BorderSide(color: AppColors.danger, width: 3)
                                      : BorderSide.none,
                                ),
                              ),
                              children: [
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.brandPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          p.code,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: AppColors.textSubtle,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(p.category, style: AppTypography.body),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(
                                      _numberFormat.format(p.currentStock),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        color: isNegative ? AppColors.danger : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(p.baseUnit, style: AppTypography.body),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text('Rs ${p.averageCost.toStringAsFixed(2)}', style: AppTypography.body),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(
                                      'Rs ${_currencyFormat.format(stockValue)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        color: isNegative ? AppColors.danger : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _openStockProfile(p),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AppBadge(
                                        label: isNegative ? 'Negative' : (isLow ? 'Low' : 'Healthy'),
                                        tone: badgeTone,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                  child: Tooltip(
                                    message: 'View full stock profile and movement history for ${p.name}',
                                    child: InkWell(
                                      onTap: () => _openStockProfile(p),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        child: AppIcons.icon('arrow', size: 15, color: AppColors.brandPrimary),
                                      ),
                                    ),
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
