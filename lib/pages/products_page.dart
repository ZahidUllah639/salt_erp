import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../repositories/erp_transaction_repository.dart';
import '../components/app_components.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';

class ProductsPage extends StatefulWidget {
  final ErpTransactionRepository? repository;

  const ProductsPage({super.key, this.repository});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final ErpTransactionRepository _repository;
  int _selected = 0;
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  String _dateFilter = 'This month';
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _numberFormat = NumberFormat('#,##0.##', 'en_US');

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
          _errorMessage = 'Failed to load products: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openAddProductDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => ProductFormDialog(
        onSave: (newProduct) async {
          try {
            final openingStock = double.tryParse(newProduct[5].replaceAll(',', '')) ?? 0.0;
            await _repository.createProduct(
              name: newProduct[0],
              code: newProduct[1],
              category: newProduct[2],
              baseUnit: newProduct[3],
              conversionDescription: newProduct[4],
              openingStock: openingStock,
            );
            await _loadData();
            if (mounted) {
              setState(() => _selected = 0);
              AppToast.showSuccess(context, 'New product "${newProduct[0]}" created and saved to database.');
            }
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Failed to create product: $e');
            }
          }
        },
      ),
    );
  }

  void _openEditProductDialog(Product product) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => ProductFormDialog(
        initialRow: [
          product.name,
          product.code,
          product.category,
          product.baseUnit,
          product.conversionDescription ?? '',
          _numberFormat.format(product.currentStock),
          product.status,
        ],
        onSave: (updated) async {
          try {
            await _repository.updateProduct(
              id: product.id,
              name: updated[0],
              category: updated[2],
              baseUnit: updated[3],
              conversionDescription: updated[4],
              status: updated[6],
            );
            await _loadData();
            if (mounted) {
              AppToast.showSuccess(context, 'Product "${updated[0]}" updated successfully.');
            }
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Failed to update product: $e');
            }
          }
        },
      ),
    );
  }

  void _duplicateProduct(Product product) {
    final copyName = "${product.name} (Copy)";
    final copyCode = "${product.code}-COPY";
    showDialog<bool>(
      context: context,
      builder: (ctx) => ProductFormDialog(
        initialRow: [
          copyName,
          copyCode,
          product.category,
          product.baseUnit,
          product.conversionDescription ?? '',
          '0',
          'Active',
        ],
        onSave: (saved) async {
          try {
            final openingStock = double.tryParse(saved[5].replaceAll(',', '')) ?? 0.0;
            await _repository.createProduct(
              name: saved[0],
              code: saved[1],
              category: saved[2],
              baseUnit: saved[3],
              conversionDescription: saved[4],
              openingStock: openingStock,
            );
            await _loadData();
            if (mounted) {
              setState(() => _selected = 0);
              AppToast.showSuccess(context, 'Product duplicated successfully as "${saved[0]}".');
            }
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Failed to duplicate product: $e');
            }
          }
        },
      ),
    );
  }

  void _exportProductCatalog() {
    final headers = [
      'Product Code',
      'Product Name',
      'Category',
      'Base Unit',
      'Conversion Formula',
      'Current Stock',
      'Catalog Status',
    ];
    final rows = _products.map((p) => [
      p.code,
      p.name,
      p.category,
      p.baseUnit,
      p.conversionDescription ?? 'Direct 1:1',
      _numberFormat.format(p.currentStock),
      p.status,
    ]).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'Product Catalog & Unit Specifications',
        subtitle: 'Complete list of registered commercial goods, raw salt reserves, and packaging items.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'Products_Catalog',
      ),
    );
  }

  void _openProductFilters() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          title: const Text('Filter Catalog Products', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
              const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['All', 'Active', 'Low stock', 'Archived'].map((st) {
                  final isSel = _statusFilter == st;
                  return ChoiceChip(
                    label: Text(st, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                    selected: isSel,
                    selectedColor: AppColors.brandLight,
                    onSelected: (_) {
                      setDialogState(() => _statusFilter = st);
                      setState(() => _statusFilter = st);
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
                  _statusFilter = 'All';
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

  void _openProductDateFilter() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
        title: const Text('Select Catalog Period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                AppToast.showInfo(context, 'Catalog filter set to: $period');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Product?',
      message: 'Are you sure you want to remove "${product.name}" (${product.code})? '
          'If this product has recorded stock movements or sales/purchases, deletion will be blocked to maintain General Ledger integrity.',
      confirmLabel: 'Delete Product',
      isDanger: true,
      auditNote: 'General Ledger stock movements and audit trail are strictly preserved.',
    );

    if (confirm == true) {
      try {
        await _repository.deleteProduct(product.id);
        await _loadData();
        if (mounted) {
          setState(() {
            if (_selected >= _products.length) {
              _selected = (_products.length - 1).clamp(0, 999);
            }
          });
          AppToast.showSuccess(context, 'Product "${product.name}" removed successfully.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Cannot delete product: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      if (_categoryFilter != 'All' && p.category.toLowerCase() != _categoryFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Low stock' && (p.currentStock > 100 || p.currentStock < 0)) return false;
        if (_statusFilter == 'Active' && p.status != 'Active') return false;
        if (_statusFilter == 'Archived' && p.status != 'Archived') return false;
      }

      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.code.toLowerCase().contains(_searchQuery) ||
          p.category.toLowerCase().contains(_searchQuery);
    }).toList();

    final selectedProduct = filteredProducts.isNotEmpty
        ? filteredProducts[_selected.clamp(0, filteredProducts.length - 1)]
        : (_products.isNotEmpty ? _products[0] : null);

    final totalCount = _products.length;
    final activeCount = _products.where((p) => p.status == 'Active').length;
    final finishedCount = _products.where((p) => p.category.toLowerCase().contains('finish')).length;
    final rawCount = _products.where((p) => p.category.toLowerCase().contains('raw')).length;
    final packagingCount = _products.where((p) => p.category.toLowerCase().contains('pack')).length;
    final lowStockCount = _products.where((p) => p.currentStock <= 100).length;

    return ModulePage(
      title: 'Products & Units',
      subtitle: 'Configure products, trading units and reliable stock conversions.',
      action: 'Add product',
      onAction: _openAddProductDialog,
      onExport: _exportProductCatalog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mini Stats (4 items calculated from real database)
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 900 ? 2 : 4;
              final width = (constraints.maxWidth - (count - 1) * 10) / count;
              final items = [
                MiniMetric(label: 'Total products', value: '$totalCount', hint: '$activeCount active in catalog'),
                MiniMetric(label: 'Finished products', value: '$finishedCount', hint: 'Commercial goods'),
                MiniMetric(label: 'Raw materials', value: '$rawCount', hint: 'Bulk salt reserves'),
                MiniMetric(label: 'Packaging items', value: '$packagingCount', hint: '$lowStockCount items low stock', alert: lowStockCount > 0),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((m) => SizedBox(width: width, child: m)).toList(),
              );
            },
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DangerNotice(
                title: 'Catalog Notice',
                message: _errorMessage!,
                actionLabel: 'Retry',
                onAction: _loadData,
              ),
            ),

          // Split Content (Table + Detail Panel)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppTableSkeleton(rowCount: 6, columnCount: 6),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 950;
                final tableWidget = _buildTableCard(filteredProducts);
                final detailWidget = selectedProduct != null
                    ? _buildDetailPanel(selectedProduct)
                    : const SizedBox.shrink();

                if (isCompact) {
                  return Column(
                    children: [
                      tableWidget,
                      const SizedBox(height: 12),
                      detailWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tableWidget),
                    const SizedBox(width: 12),
                    SizedBox(width: 300, child: detailWidget),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableCard(List<Product> filteredProducts) {
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
          AppToolbar(
            placeholder: 'Search products or SKU...',
            onSearch: (q) => setState(() {
              _searchQuery = q.trim().toLowerCase();
              _selected = 0;
            }),
            onFilter: _openProductFilters,
            onDateFilter: _openProductDateFilter,
            filterCount: (_categoryFilter != 'All' ? 1 : 0) + (_statusFilter != 'All' ? 1 : 0),
            activeDateLabel: _dateFilter,
          ),
          if (filteredProducts.isEmpty)
            AppEmptyState(
              icon: 'search',
              title: 'No products match your search',
              message: _searchQuery.isNotEmpty
                  ? 'No products match "$_searchQuery". Check spelling or clear your filter.'
                  : 'No products recorded in the database catalog.',
              actionLabel: _searchQuery.isNotEmpty ? 'Clear search' : 'Add product',
              onAction: _searchQuery.isNotEmpty
                  ? () => setState(() {
                        _searchQuery = '';
                        _selected = 0;
                      })
                  : _openAddProductDialog,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth > 750 ? constraints.maxWidth : 750,
                    ),
                    child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.2),
                    1: FlexColumnWidth(1.4),
                    2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(2.2),
                    4: FlexColumnWidth(1.2),
                    5: FlexColumnWidth(1.0),
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
                        _HeaderCell('TYPE'),
                        _HeaderCell('BASE UNIT'),
                        _HeaderCell('CONVERSION'),
                        _HeaderCell('AVAILABLE'),
                        _HeaderCell('STATUS'),
                      ],
                    ),
                    // Rows
                    ...filteredProducts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final p = entry.value;
                      final isSelected = _selected == index;
                      final isLow = p.currentStock <= 100 && p.currentStock >= 0;
                      final isNegative = p.currentStock < 0;

                      return TableRow(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                          border: Border(
                            bottom: const BorderSide(color: AppColors.borderLight),
                            left: isSelected
                                ? const BorderSide(color: AppColors.brandPrimary, width: 3)
                                : BorderSide.none,
                          ),
                        ),
                        children: [
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
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
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(p.category, style: AppTypography.body),
                            ),
                          ),
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(p.baseUnit, style: AppTypography.body),
                            ),
                          ),
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(p.conversionDescription ?? '—', style: AppTypography.body),
                            ),
                          ),
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Text(
                                _numberFormat.format(p.currentStock),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isNegative ? AppColors.danger : (isLow ? AppColors.warning : AppColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                          _buildClickableCell(
                            index,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AppBadge(
                                  label: isNegative ? 'Negative' : (isLow ? 'Low stock' : p.status),
                                  tone: isNegative ? BadgeTone.red : (isLow ? BadgeTone.amber : BadgeTone.green),
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
    );
  }

  Widget _buildClickableCell(int index, Widget child) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = index),
        child: child,
      ),
    );
  }

  Widget _buildDetailPanel(Product p) {
    final initials = p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detail Top
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isNotEmpty ? initials : 'PR',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRODUCT DETAILS',
                      style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.code,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF778195),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Conversion Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FF),
              border: Border.all(color: const Color(0xFFDCE8FB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STOCK CONVERSION FORMULA',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D7B92),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.conversionDescription != null && p.conversionDescription!.isNotEmpty
                      ? p.conversionDescription!
                      : 'No conversion formula registered.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stock Configuration
          const Text(
            'Stock configuration',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          InfoRow(label: 'Base stock unit', value: p.baseUnit),
          InfoRow(label: 'Category', value: p.category),
          InfoRow(label: 'Available stock', value: '${_numberFormat.format(p.currentStock)} ${p.baseUnit}'),
          InfoRow(label: 'Average unit cost', value: 'Rs ${p.averageCost.toStringAsFixed(2)}'),
          InfoRow(label: 'Catalog status', value: p.status),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Duplicate',
                  variant: ButtonVariant.secondary,
                  onClick: () => _duplicateProduct(p),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: AppButton(
                  label: 'Edit product',
                  variant: ButtonVariant.primary,
                  onClick: () => _openEditProductDialog(p),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'View stock ledger & history',
            variant: ButtonVariant.secondary,
            icon: 'history',
            onClick: () => _openStockProfile(p),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Delete product',
            variant: ButtonVariant.danger,
            icon: 'warning',
            onClick: () => _deleteProduct(p),
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
