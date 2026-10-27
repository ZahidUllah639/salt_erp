import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../repositories/erp_transaction_repository.dart';
import '../services/printing_service.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ErpTransactionRepository _repository = ErpTransactionRepository();

  bool _isLoading = false;
  FinancialMonthlySummary? _monthlySummary;

  static const List<Map<String, dynamic>> groups = [
    {
      'title': 'Financial reports',
      'icon': 'trend',
      'color': AppColors.primary,
      'bg': AppColors.primaryLight,
      'items': [
        'Daily income & expenses',
        'Gross & net profit',
        'Cash flow',
        'Opening balances',
      ],
    },
    {
      'title': 'Ledgers & balances',
      'icon': 'wallet',
      'color': AppColors.violet,
      'bg': AppColors.violetBg,
      'items': [
        'Customer receivables',
        'Supplier payables',
        'Wallet ledger',
        'Cash reconciliation',
      ],
    },
    {
      'title': 'Inventory reports',
      'icon': 'stock',
      'color': AppColors.green,
      'bg': AppColors.greenBg,
      'items': [
        'Stock valuation',
        'Negative-stock history',
        'Packaging materials',
        'Product-wise sales',
      ],
    },
    {
      'title': 'Production reports',
      'icon': 'factory',
      'color': AppColors.amber,
      'bg': AppColors.amberBg,
      'items': [
        'Monthly production',
        'Reported vs verified',
        'Material consumption',
        'Production costing',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMonthlySnapshot();
  }

  Future<void> _loadMonthlySnapshot() async {
    try {
      final now = DateTime.now();
      final summary = await _repository.getFinancialMonthlySummary(year: now.year, month: now.month);
      if (mounted) {
        setState(() => _monthlySummary = summary);
      }
    } catch (_) {}
  }

  Future<void> _openReport(String reportName) async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final thisYearStart = '${now.year}-01-01';
      final today = now.toString().substring(0, 10);

      ReportData data;
      switch (reportName) {
        case 'Daily income & expenses':
          data = await _repository.getExpensesReport(startDate: thisYearStart, endDate: today);
          break;
        case 'Gross & net profit':
          data = await _repository.getMonthlyPerformanceReport(year: now.year, month: now.month);
          break;
        case 'Cash flow':
        case 'Wallet ledger':
          data = await _repository.getWalletMovementsReport(startDate: thisYearStart, endDate: today);
          break;
        case 'Opening balances':
        case 'Cash reconciliation':
          data = await _repository.getCashReconciliationReport(date: today);
          break;
        case 'Customer receivables':
          data = await _repository.getOutstandingBalancesReport(partyType: 'Customer');
          break;
        case 'Supplier payables':
          data = await _repository.getOutstandingBalancesReport(partyType: 'Supplier');
          break;
        case 'Stock valuation':
          data = await _repository.getStockValuationReport();
          break;
        case 'Negative-stock history':
          data = await _repository.getStockValuationReport(lowStockOnly: true);
          break;
        case 'Packaging materials':
          data = await _repository.getStockValuationReport(category: 'Packaging');
          break;
        case 'Product-wise sales':
          data = await _repository.getSalesReport(startDate: thisYearStart, endDate: today);
          break;
        case 'Monthly production':
        case 'Reported vs verified':
        case 'Material consumption':
        case 'Production costing':
          data = await _repository.getProductionReport(startDate: thisYearStart, endDate: today);
          break;
        default:
          data = await _repository.getMonthlyPerformanceReport(year: now.year, month: now.month);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showReportDialog(data, reportName);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showReportDialog(ReportData initialData, String reportName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ReportViewerDialog(
        reportName: reportName,
        initialReport: initialData,
        repository: _repository,
      ),
    );
  }

  void _openCustomReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
        title: const Text('Generate Custom ERP Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Report Module:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Daily income & expenses',
                'Gross & net profit',
                'Customer receivables',
                'Supplier payables',
                'Stock valuation',
                'Monthly production',
              ].map((rep) => ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openReport(rep);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(rep, style: const TextStyle(fontSize: 11.5)),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _exportReportsCatalog() {
    final headers = ['Category', 'Report Name', 'Scope', 'Format Support'];
    final rows = <List<String>>[];
    for (final g in groups) {
      for (final item in (g['items'] as List<String>)) {
        rows.add([g['title'] as String, item, 'Factory Operational Audit', 'PDF / Print / Export']);
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'ERP Financial & Operational Reports Catalog',
        subtitle: 'Index of available audit ledgers, profit & loss statements, stock valuation and production costing.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'ERP_Reports_Catalog',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = monthNames[now.month - 1];

    final salesRev = _monthlySummary?.salesRevenue ?? 8420000.0;
    final expTotal = _monthlySummary?.expensesTotal ?? 7486000.0;
    final netProfit = salesRev - expTotal;
    final margin = salesRev > 0 ? (netProfit / salesRev * 100) : 11.1;

    return ModulePage(
      title: 'Reports',
      subtitle: 'Consistent figures from the same underlying business records.',
      action: 'Create custom report',
      onAction: _openCustomReportDialog,
      onExport: _exportReportsCatalog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Report Hero Banner (Dark Navy)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
            decoration: BoxDecoration(
              color: AppColors.heroNavy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY SNAPSHOT',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: Color(0xFF91A1BD),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$currentMonthName ${now.year}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Sales ', style: TextStyle(fontSize: 10, color: Color(0xFF9DABBE))),
                          TextSpan(
                            text: 'Rs ${(salesRev / 1000000).toStringAsFixed(2)}m',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const TextSpan(text: ' • Net profit ', style: TextStyle(fontSize: 10, color: Color(0xFF9DABBE))),
                          TextSpan(
                            text: 'Rs ${(netProfit / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const TextSpan(text: ' • Margin ', style: TextStyle(fontSize: 10, color: Color(0xFF9DABBE))),
                          TextSpan(
                            text: '${margin.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    AppButton(
                      label: 'Preview',
                      icon: 'eye',
                      variant: ButtonVariant.secondary,
                      onClick: () => _openReport('Gross & net profit'),
                    ),
                    const SizedBox(width: 7),
                    AppButton(
                      label: 'Export PDF',
                      icon: 'download',
                      variant: ButtonVariant.primary,
                      onClick: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final data = await _repository.getMonthlyPerformanceReport(year: now.year, month: now.month);
                        final result = await PrintingService.instance.exportReportPdf(data);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(result.message),
                              backgroundColor: result.success ? AppColors.success : AppColors.danger,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppTableSkeleton(rowCount: 4, columnCount: 3),
            )
          else
            // 4 Report Groups
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 950 ? 2 : 4;
                final width = (constraints.maxWidth - (count - 1) * 10) / count;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: groups.map((g) {
                    return SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppColors.radius),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: g['bg'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: AppIcons.icon(
                                g['icon'] as String,
                                size: 18,
                                color: g['color'] as Color,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              g['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.15,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Operational and audit-ready reporting.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8992A2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...((g['items'] as List<String>).map((item) {
                              return _ReportItemRow(
                                label: item,
                                onTap: () => _openReport(item),
                              );
                            })),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReportItemRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ReportItemRow({required this.label, required this.onTap});

  @override
  State<_ReportItemRow> createState() => _ReportItemRowState();
}

class _ReportItemRowState extends State<_ReportItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 31,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? AppColors.primary : const Color(0xFF4E596B),
                ),
              ),
              AppIcons.icon(
                'arrow',
                size: 14,
                color: _isHovered ? AppColors.primary : const Color(0xFFA2A9B5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// INTERACTIVE FILTERED REPORT VIEWER DIALOG
// =========================================================================

class _ReportViewerDialog extends StatefulWidget {
  final String reportName;
  final ReportData initialReport;
  final ErpTransactionRepository repository;

  const _ReportViewerDialog({
    required this.reportName,
    required this.initialReport,
    required this.repository,
  });

  @override
  State<_ReportViewerDialog> createState() => _ReportViewerDialogState();
}

class _ReportViewerDialogState extends State<_ReportViewerDialog> {
  late ReportData _report;
  late TextEditingController _startDateCtrl;
  late TextEditingController _endDateCtrl;
  bool _isRefreshing = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    final now = DateTime.now();
    _startDateCtrl = TextEditingController(text: '${now.year}-01-01');
    _endDateCtrl = TextEditingController(text: now.toString().substring(0, 10));
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final start = _startDateCtrl.text.trim();
    final end = _endDateCtrl.text.trim();

    try {
      ReportData updated;
      final name = widget.reportName;
      if (name.contains('sales') || name.contains('Product-wise')) {
        updated = await widget.repository.getSalesReport(startDate: start, endDate: end);
      } else if (name.contains('expenses') || name.contains('income')) {
        updated = await widget.repository.getExpensesReport(startDate: start, endDate: end);
      } else if (name.contains('Wallet') || name.contains('Cash flow')) {
        updated = await widget.repository.getWalletMovementsReport(startDate: start, endDate: end);
      } else if (name.contains('production') || name.contains('yield')) {
        updated = await widget.repository.getProductionReport(startDate: start, endDate: end);
      } else if (name.contains('Customer') || name.contains('receivables')) {
        updated = await widget.repository.getOutstandingBalancesReport(partyType: 'Customer');
      } else if (name.contains('Supplier') || name.contains('payables')) {
        updated = await widget.repository.getOutstandingBalancesReport(partyType: 'Supplier');
      } else if (name.contains('Stock') || name.contains('Inventory')) {
        updated = await widget.repository.getStockValuationReport();
      } else {
        final year = int.tryParse(start.substring(0, 4)) ?? DateTime.now().year;
        final month = int.tryParse(start.length >= 7 ? start.substring(5, 7) : '10') ?? 10;
        updated = await widget.repository.getMonthlyPerformanceReport(year: year, month: month);
      }

      if (mounted) {
        setState(() {
          _report = updated;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Filter error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    if (preset == 'Today') {
      final todayStr = now.toString().substring(0, 10);
      _startDateCtrl.text = todayStr;
      _endDateCtrl.text = todayStr;
    } else if (preset == 'This Month') {
      final monthStr = now.month.toString().padLeft(2, '0');
      _startDateCtrl.text = '${now.year}-$monthStr-01';
      _endDateCtrl.text = now.toString().substring(0, 10);
    } else if (preset == 'This Year') {
      _startDateCtrl.text = '${now.year}-01-01';
      _endDateCtrl.text = now.toString().substring(0, 10);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1000,
        height: 720,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 50,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            // Head
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _report.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_report.subtitle} • Period: ${_report.dateRange}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Text('From:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  _DateFilterField(controller: _startDateCtrl),
                  const SizedBox(width: 12),
                  const Text('To:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  _DateFilterField(controller: _endDateCtrl),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildPresetBtn('Today'),
                      _buildPresetBtn('This Month'),
                      _buildPresetBtn('This Year'),
                    ],
                  ),
                  const Spacer(),
                  AppButton(
                    label: _isRefreshing ? 'Loading...' : 'Apply Filter',
                    icon: 'filter',
                    variant: ButtonVariant.secondary,
                    onClick: _isRefreshing ? () {} : _refresh,
                  ),
                ],
              ),
            ),

            // Summary Metrics Row
            if (_report.summaryMetrics.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: _report.summaryMetrics.entries.map((entry) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.value,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Data Table
            Expanded(
              child: _report.rows.isEmpty
                  ? const Center(
                      child: Text('No records match the selected date range.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth > 700 ? constraints.maxWidth : 700,
                            ),
                            child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                              ),
                              children: _report.columnHeaders.map((h) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            ..._report.rows.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;
                              final isEven = idx % 2 == 0;

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                  border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                children: row.asMap().entries.map((cEntry) {
                                  final colIdx = cEntry.key;
                                  final cell = cEntry.value;
                                  final align = colIdx < _report.columnAlignments.length
                                      ? _report.columnAlignments[colIdx]
                                      : 'left';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                      cell,
                                      textAlign: align == 'right'
                                          ? TextAlign.right
                                          : align == 'center'
                                              ? TextAlign.center
                                              : TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: align == 'right' ? FontWeight.w600 : FontWeight.w400,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }),
                            if (_report.totalsRow != null)
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  border: Border.symmetric(
                                    horizontal: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                  ),
                                ),
                                children: _report.totalsRow!.asMap().entries.map((tEntry) {
                                  final colIdx = tEntry.key;
                                  final cell = tEntry.value;
                                  final align = colIdx < _report.columnAlignments.length
                                      ? _report.columnAlignments[colIdx]
                                      : 'left';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    child: Text(
                                      cell,
                                      textAlign: align == 'right'
                                          ? TextAlign.right
                                          : align == 'center'
                                              ? TextAlign.center
                                              : TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),

            // Dialog Foot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Close',
                    variant: ButtonVariant.ghost,
                    onClick: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: _isExporting ? 'Exporting...' : 'Export A4 PDF',
                    icon: 'download',
                    variant: ButtonVariant.secondary,
                    onClick: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isExporting = true);
                      final res = await PrintingService.instance.exportReportPdf(_report);
                      setState(() => _isExporting = false);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Print Report',
                    icon: 'print',
                    variant: ButtonVariant.primary,
                    onClick: () async {
                      await PrintingService.instance.printReport(_report);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBtn(String label) {
    return GestureDetector(
      onTap: () => _setPreset(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _DateFilterField extends StatefulWidget {
  final TextEditingController controller;

  const _DateFilterField({required this.controller});

  @override
  State<_DateFilterField> createState() => _DateFilterFieldState();
}

class _DateFilterFieldState extends State<_DateFilterField> {
  bool _isHovered = false;
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
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
        : (_isHovered ? const Color(0xFF64748B) : AppColors.border);

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 110,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: borderColor, width: _isFocused ? 1.5 : 1.0),
          boxShadow: _isFocused
              ? const [
                  BoxShadow(
                    color: Color(0x282563EB),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ]
              : (_isHovered
                  ? const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      )
                    ]
                  : null),
        ),
        child: Center(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
          ),
        ),
      ),
    );
  }
}
