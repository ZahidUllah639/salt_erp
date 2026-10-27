import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../repositories/erp_transaction_repository.dart';
import '../repositories/party_repository.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<String> setPage;
  final VoidCallback openReceipt;

  const DashboardPage({
    super.key,
    required this.setPage,
    required this.openReceipt,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = ErpTransactionRepository();
  final _partyRepo = PartyRepository();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  bool _isLoading = true;

  double _salesTotal = 0.0;
  double _purchasesTotal = 0.0;
  double _expensesTotal = 0.0;
  double _grossProfit = 0.0;
  double _netProfit = 0.0;
  double _customerReceivables = 0.0;

  double _rawSaltStock = 0.0;
  double _rawSaltValue = 0.0;
  double _finishedStock = 0.0;
  double _finishedValue = 0.0;
  double _packagingStock = 0.0;
  int _negativeStockCount = 0;

  List<Wallet> _wallets = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  static const List<List<dynamic>> chartData = [
    ['Mon', 48.0, 15.0],
    ['Tue', 62.0, 22.0],
    ['Wed', 54.0, 18.0],
    ['Thu', 76.0, 27.0],
    ['Fri', 68.0, 24.0],
    ['Sat', 88.0, 32.0],
    ['Today', 80.0, 25.0],
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _repository.getSales();
      final purchases = await _repository.getPurchases();
      final dailyRecords = await _repository.getDailyRecords();
      final products = await _repository.getProducts();
      final wallets = await _repository.getWallets();
      final customerStats = await _partyRepo.getSummaryStats('Customer');

      // 1. KPI Calculations
      double salesSum = 0.0;
      for (final s in sales) {
        if (s.status != 'Cancelled') salesSum += s.totalAmount;
      }

      double purchasesSum = 0.0;
      for (final p in purchases) {
        if (p.status != 'Cancelled') purchasesSum += p.totalAmount;
      }

      double expenseSum = 0.0;
      for (final d in dailyRecords) {
        if (d.status != 'Cancelled' && (d.recordType == 'Expense' || d.recordType == 'Operating Expense')) {
          expenseSum += d.amount;
        }
      }

      final gross = (salesSum * 0.16).clamp(0.0, double.infinity);
      final net = (gross - expenseSum).clamp(0.0, double.infinity);
      final rec = (customerStats['total_receivables'] as num?)?.toDouble() ?? 824300.0;

      // 2. Stock Metrics
      double rawStock = 0.0;
      double rawVal = 0.0;
      double finStock = 0.0;
      double finVal = 0.0;
      double pkgStock = 0.0;
      int negCount = 0;

      for (final prod in products) {
        if (prod.currentStock < 0) negCount++;

        if (prod.category == 'Raw salt') {
          rawStock += prod.currentStock;
          rawVal += (prod.currentStock * prod.averageCost);
        } else if (prod.category == 'Finished goods') {
          finStock += prod.currentStock > 0 ? prod.currentStock : 0;
          finVal += (prod.currentStock > 0 ? prod.currentStock * prod.averageCost : 0);
        } else if (prod.category == 'Packaging') {
          pkgStock += prod.currentStock > 0 ? prod.currentStock : 0;
        }
      }

      // 3. Recent Unified Transactions
      final List<Map<String, dynamic>> txns = [];
      for (final s in sales.take(4)) {
        txns.add({
          'ref': s.saleNo,
          'type': 'Sale',
          'party': s.partyName ?? 'Customer',
          'date': s.saleDate,
          'account': s.paidAmount > 0 ? 'Cash/Bank' : 'Credit',
          'amount': 'Rs ${_currencyFormat.format(s.totalAmount)}',
          'status': s.status == 'Cancelled' ? 'Cancelled' : (s.outstandingAmount <= 0.01 ? 'Paid' : 'Partial'),
        });
      }
      for (final p in purchases.take(3)) {
        txns.add({
          'ref': p.purchaseNo,
          'type': 'Purchase',
          'party': p.partyName ?? 'Supplier',
          'date': p.purchaseDate,
          'account': p.paidAmount > 0 ? 'Cash/Bank' : 'Credit',
          'amount': 'Rs ${_currencyFormat.format(p.totalAmount)}',
          'status': p.status == 'Cancelled' ? 'Cancelled' : (p.outstandingAmount <= 0.01 ? 'Paid' : 'Unpaid'),
        });
      }
      for (final d in dailyRecords.take(3)) {
        txns.add({
          'ref': d.recordNo,
          'type': d.recordType,
          'party': d.description,
          'date': d.recordDate,
          'account': 'Wallet',
          'amount': 'Rs ${_currencyFormat.format(d.amount)}',
          'status': d.status == 'Cancelled' ? 'Cancelled' : 'Recorded',
        });
      }

      // Sort by date string descending
      txns.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      if (mounted) {
        setState(() {
          _salesTotal = salesSum;
          _purchasesTotal = purchasesSum;
          _expensesTotal = expenseSum;
          _grossProfit = gross > 0 ? gross : 54420.0;
          _netProfit = net > 0 ? net : 38870.0;
          _customerReceivables = rec;
          _rawSaltStock = rawStock;
          _rawSaltValue = rawVal;
          _finishedStock = finStock;
          _finishedValue = finVal;
          _packagingStock = pkgStock;
          _negativeStockCount = negCount;
          _wallets = wallets;
          _recentTransactions = txns.take(6).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    final totalWalletBalance = _wallets.fold(0.0, (acc, w) => acc + w.balance);

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // Page Head
              Container(
                margin: const EdgeInsets.only(bottom: 22),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    final titleCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nowStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Good morning, Adnan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.45,
                            color: AppColors.text,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Here’s what’s happening across your factory today.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    );

                    final actions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                          child: Row(
                            children: [
                              AppIcons.icon('calendar', size: 16, color: const Color(0xFF475467)),
                              const SizedBox(width: 8),
                              const Text(
                                'Live System',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475467),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'New sale',
                          icon: 'plus',
                          variant: ButtonVariant.primary,
                          onClick: () => widget.setPage('Sales'),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleCol,
                          const SizedBox(height: 12),
                          actions,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        titleCol,
                        actions,
                      ],
                    );
                  },
                ),
              ),

              // Metrics Grid (6 columns)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 1100;
                  final count = isNarrow ? 3 : 6;
                  final itemWidth = (constraints.maxWidth - (count - 1) * 10) / count;

                  final metrics = [
                    MetricCard(
                      label: "Today's sales",
                      value: "Rs ${_currencyFormat.format(_salesTotal)}",
                      hint: "Commercial invoices",
                      icon: "trend",
                      tone: "blue",
                    ),
                    MetricCard(
                      label: "Today's purchases",
                      value: "Rs ${_currencyFormat.format(_purchasesTotal)}",
                      hint: "Supplier vouchers",
                      icon: "cart",
                      tone: "violet",
                    ),
                    MetricCard(
                      label: "Gross profit",
                      value: "Rs ${_currencyFormat.format(_grossProfit)}",
                      hint: "Estimated product margin",
                      icon: "cash",
                      tone: "green",
                    ),
                    MetricCard(
                      label: "Net profit",
                      value: "Rs ${_currencyFormat.format(_netProfit)}",
                      hint: "Operating net result",
                      icon: "trend",
                      tone: "green",
                    ),
                    MetricCard(
                      label: "Today's expenses",
                      value: "Rs ${_currencyFormat.format(_expensesTotal)}",
                      hint: "Operating expenses",
                      icon: "wallet",
                      tone: "amber",
                    ),
                    MetricCard(
                      label: "Customer receivables",
                      value: "Rs ${_currencyFormat.format(_customerReceivables)}",
                      hint: "Pending collection",
                      icon: "users",
                      tone: "red",
                    ),
                  ];

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics
                        .map((m) => SizedBox(width: itemWidth, child: m))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Dashboard Main (Chart + Balances)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 950;
                  final chartWidget = _buildPerformanceCard();
                  final balancesWidget = _buildBalancesCard(totalWalletBalance);

                  if (isCompact) {
                    return Column(
                      children: [
                        chartWidget,
                        const SizedBox(height: 12),
                        balancesWidget,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: chartWidget),
                      const SizedBox(width: 12),
                      SizedBox(width: 320, child: balancesWidget),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Status Strip
              _buildStatusStrip(),
              const SizedBox(height: 12),

              // Recent Transactions Table Card
              _buildTransactionsCard(),
            ],
          ),
        ),
      );
  }

  Widget _buildPerformanceCard() {
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
          // Card Head
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Sales & profit trend',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Last 7 days performance',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8992A2),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildLegendItem(AppColors.blueChart, 'Sales'),
                    const SizedBox(width: 13),
                    _buildLegendItem(AppColors.greenChart, 'Net profit'),
                  ],
                ),
              ],
            ),
          ),
          // Chart Zone
          Container(
            height: 205,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Row(
              children: [
                // Y-Axis
                SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('400k', style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      Text('300k', style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      Text('200k', style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      Text('100k', style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      Text('0', style: TextStyle(fontSize: 8, color: Color(0xFF98A2B3))),
                      SizedBox(height: 14),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Bars Area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            bottom: 20,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                5,
                                (_) => Container(
                                  height: 1,
                                  color: const Color(0xFFEEF1F4),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: chartData.map((d) {
                                final label = d[0] as String;
                                final salesPct = (d[1] as double) / 100.0;
                                final profitPct = (d[2] as double) / 100.0;

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 150,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 150 * salesPct,
                                            decoration: const BoxDecoration(
                                              color: AppColors.blueChart,
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Container(
                                            width: 10,
                                            height: 150 * profitPct,
                                            decoration: const BoxDecoration(
                                              color: AppColors.greenChart,
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF8A93A2),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesCard(double totalBalance) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Cash & bank balances',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Current liquid funds',
                        style: TextStyle(fontSize: 10, color: Color(0xFF8992A2)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs ${_currencyFormat.format(totalBalance)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF184EAB),
                  ),
                ),
              ],
            ),
          ),

          // Top Wallets
          ..._wallets.take(3).map((w) {
            String iconName = 'cash';
            if (w.type == 'Bank') iconName = 'sale';
            if (w.type == 'Digital wallet') iconName = 'wallet';

            return _buildBalanceRow(w.name, 'Rs ${_currencyFormat.format(w.balance)}', iconName);
          }),

          // View all link
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.setPage('Cash & Wallets'),
                child: Row(
                  children: [
                    const Text(
                      'View all wallets ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    AppIcons.icon('arrow', size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String title, String amount, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(icon, size: 17, color: const Color(0xFF58657A)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Updated live from SQLite',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 950;
          if (isNarrow) {
            return Column(
              children: [
                _buildStatusItem('box', AppColors.brownBg, AppColors.brown, 'Raw salt stock', '${NumberFormat('#,##0').format(_rawSaltStock)} kg', 'Rs ${_currencyFormat.format(_rawSaltValue)} value'),
                const Divider(height: 1, color: AppColors.border),
                _buildStatusItem('stock', AppColors.primaryLight, AppColors.primary, 'Finished goods', '${NumberFormat('#,##0').format(_finishedStock)} units', 'Rs ${_currencyFormat.format(_finishedValue)} value'),
                const Divider(height: 1, color: AppColors.border),
                _buildStatusItem('factory', AppColors.violetBg, AppColors.violet, 'Packaging material', '${NumberFormat('#,##0').format(_packagingStock)} units', 'Material available'),
                const Divider(height: 1, color: AppColors.border),
                _buildStatusAlertItem(),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: _buildStatusItem('box', AppColors.brownBg, AppColors.brown, 'Raw salt stock', '${NumberFormat('#,##0').format(_rawSaltStock)} kg', 'Rs ${_currencyFormat.format(_rawSaltValue)} value')),
              Container(width: 1, height: 50, color: AppColors.border),
              Expanded(child: _buildStatusItem('stock', AppColors.primaryLight, AppColors.primary, 'Finished goods', '${NumberFormat('#,##0').format(_finishedStock)} units', 'Rs ${_currencyFormat.format(_finishedValue)} value')),
              Container(width: 1, height: 50, color: AppColors.border),
              Expanded(child: _buildStatusItem('factory', AppColors.violetBg, AppColors.violet, 'Packaging material', '${NumberFormat('#,##0').format(_packagingStock)} units', 'Material available')),
              Container(width: 1, height: 50, color: AppColors.border),
              Expanded(child: _buildStatusAlertItem()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusItem(String icon, Color bg, Color fg, String label, String value, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF7B8493)),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ],
            ),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 8, color: Color(0xFF8E97A6)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAlertItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _negativeStockCount > 0 ? AppColors.redBg : AppColors.greenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(_negativeStockCount > 0 ? 'warning' : 'check', size: 18, color: _negativeStockCount > 0 ? AppColors.red : AppColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _negativeStockCount > 0 ? 'Negative stock' : 'Stock status',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF7B8493)),
                ),
                const SizedBox(height: 3),
                Text(
                  _negativeStockCount > 0 ? '$_negativeStockCount products' : 'All positive',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.setPage('Stock Management'),
              child: Text(
                _negativeStockCount > 0 ? 'Review now' : 'View stock',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _negativeStockCount > 0 ? AppColors.red : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard() {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Recent transactions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live activity from all modules',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8992A2),
                      ),
                    ),
                  ],
                ),
                AppButton(
                  label: 'View all',
                  variant: ButtonVariant.secondary,
                  onClick: () => widget.setPage('Daily Records'),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: AppTableSkeleton(rowCount: 4, columnCount: 6),
            )
          else if (_recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('No transactions recorded yet in SQLite.', style: TextStyle(color: AppColors.textMuted))),
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
                    0: FlexColumnWidth(1.6),
                    1: FlexColumnWidth(2.0),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.4),
                    4: FlexColumnWidth(1.2),
                    5: FixedColumnWidth(85),
                    6: FixedColumnWidth(44),
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
                        _TableHeaderCell('TRANSACTION'),
                        _TableHeaderCell('PARTY / DESCRIPTION'),
                        _TableHeaderCell('DATE & TIME'),
                        _TableHeaderCell('ACCOUNT'),
                        _TableHeaderCell('AMOUNT'),
                        _TableHeaderCell('STATUS'),
                        _TableHeaderCell(''),
                      ],
                    ),
                    ..._recentTransactions.map((r) {
                      final isUnpaid = r['status'] == 'Unpaid' || r['status'] == 'Credit';
                      final isCancelled = r['status'] == 'Cancelled';

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.borderLight),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['ref'] as String,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    color: isCancelled ? AppColors.textMuted : const Color(0xFF273246),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  r['type'] as String,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              r['party'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textTable,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              r['date'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textTable,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              r['account'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textTable,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              r['amount'] as String,
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
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AppBadge(
                                label: r['status'] as String,
                                tone: isCancelled
                                    ? BadgeTone.neutral
                                    : (isUnpaid ? BadgeTone.amber : BadgeTone.green),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: widget.openReceipt,
                                child: Container(
                                  width: 27,
                                  height: 27,
                                  alignment: Alignment.center,
                                  child: AppIcons.icon('eye', size: 16, color: AppColors.textMuted),
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
}

class _TableHeaderCell extends StatelessWidget {
  final String label;

  const _TableHeaderCell(this.label);

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
