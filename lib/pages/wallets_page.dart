import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/erp_operation_dialogs.dart';
import '../repositories/erp_transaction_repository.dart';

class WalletsPage extends StatefulWidget {
  const WalletsPage({super.key});

  @override
  State<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends State<WalletsPage> {
  final _repository = ErpTransactionRepository();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  final TextEditingController _countedController = TextEditingController();
  bool _isLoading = true;

  List<Wallet> _wallets = [];
  Map<int, Map<String, double>> _flows = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _countedController.addListener(_onCountedChanged);
  }

  void _onCountedChanged() {
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wallets = await _repository.getWallets();
      final flows = <int, Map<String, double>>{};
      for (final w in wallets) {
        flows[w.id] = await _repository.getWalletFlow(w.id);
      }

      if (mounted) {
        setState(() {
          _wallets = wallets;
          _flows = flows;
          _isLoading = false;

          // Set default counted amount to primary cash wallet
          final cashWallet = wallets.firstWhere(
            (w) => w.type == 'Cash',
            orElse: () => wallets.isNotEmpty
                ? wallets.first
                : const Wallet(
                    id: 1,
                    name: 'Cash in Hand',
                    type: 'Cash',
                    balance: 0,
                    createdAt: '',
                    updatedAt: '',
                  ),
          );
          if (_countedController.text.isEmpty) {
            _countedController.text = NumberFormat('#,##0').format(cashWallet.balance.toInt());
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Failed to load wallet balances: $e');
      }
    }
  }

  int get _countedAmount {
    final cleaned = _countedController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  int get _expectedClosing {
    final cashWallet = _wallets.firstWhere(
      (w) => w.type == 'Cash',
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
    return cashWallet.balance.toInt();
  }

  int get _difference => _countedAmount - _expectedClosing;

  void _openTransferDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => WalletTransferDialog(
        walletNames: _wallets.map((w) => w.name).toList(),
        onSave: (data) async {
          final from = data['from'] as String;
          final to = data['to'] as String;
          final amount = data['amount'] as double;

          try {
            final srcWallet = _wallets.firstWhere((w) => w.name == from);
            final destWallet = _wallets.firstWhere((w) => w.name == to);

            final dateStr = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

            await _repository.createDailyRecord(
              recordType: 'Wallet Transfer',
              recordDate: dateStr,
              category: 'Inter-Wallet Transfer',
              description: 'Transfer from $from to $to',
              sourceWalletId: srcWallet.id,
              destinationWalletId: destWallet.id,
              amount: amount,
              notes: 'Internal cash transfer',
            );

            if (mounted) {
              AppToast.showSuccess(context, 'Transferred Rs ${_currencyFormat.format(amount)} from $from to $to.');
            }
            await _loadData();
          } catch (e) {
            if (mounted) {
              AppToast.showError(context, 'Transfer failed: $e');
            }
          }
        },
      ),
    );
  }

  Future<void> _viewWalletLedger(Wallet wallet) async {
    final entries = await _repository.getWalletLedger(wallet.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Ledger: ${wallet.name}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Current balance: Rs ${_currencyFormat.format(wallet.balance)} • ${entries.length} entries',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.borderLight),
              Container(
                constraints: const BoxConstraints(maxHeight: 380),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: entries.isEmpty
                    ? const Center(
                        child: Text('No ledger entries recorded for this wallet yet.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        separatorBuilder: (context, index) => const Divider(height: 12, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final isIn = e['direction'] == 'IN';
                          final amt = (e['amount'] as num).toDouble();
                          final runBal = (e['running_balance'] as num).toDouble();
                          final ref = (e['reference_no'] as String?) ?? 'REC';
                          final desc = (e['description'] as String?) ?? 'Transaction';
                          final date = (e['entry_date'] as String?) ?? '';

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$ref • $desc',
                                        style: const TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$date • Bal after: Rs ${_currencyFormat.format(runBal)}',
                                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIn ? "+" : "−"}Rs ${_currencyFormat.format(amt)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isIn ? AppColors.successText : AppColors.dangerText,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Close ledger',
                  variant: ButtonVariant.secondary,
                  onClick: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _completeReconciliation() {
    if (_difference == 0) {
      AppToast.showSuccess(context, 'Daily cash drawer is perfectly balanced with expected closing of Rs ${_currencyFormat.format(_expectedClosing)}.');
    } else if (_difference > 0) {
      AppToast.showWarning(context, 'Cash drawer has a cash surplus of +Rs ${_currencyFormat.format(_difference)} logged in audit trail.');
    } else {
      AppToast.showError(context, 'Cash drawer discrepancy: Short of -Rs ${_currencyFormat.format(_difference.abs())} recorded.');
    }
  }

  void _exportWalletsReport() {
    final headers = ['Wallet Name', 'Account Type', 'Current Balance (Rs)', 'Status'];
    final rows = _wallets.map((w) => [
      w.name,
      w.type,
      _currencyFormat.format(w.balance),
      w.balance >= 0 ? 'Normal' : 'Overdrawn',
    ]).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: 'Cash & Wallet Accounts Statement',
        subtitle: 'Live cash drawer balances, bank accounts and mobile money balances.',
        headers: headers,
        rows: rows,
        filenamePrefix: 'Wallets_Balance_Statement',
      ),
    );
  }

  @override
  void dispose() {
    _countedController.removeListener(_onCountedChanged);
    _countedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: 'Cash & Wallets',
      subtitle: 'Balances carry forward and every movement remains traceable.',
      action: 'Transfer money',
      onAction: _openTransferDialog,
      onExport: _exportWalletsReport,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wallet Cards Grid
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppTableSkeleton(rowCount: 2, columnCount: 3),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 950 ? 2 : 4;
                final width = (constraints.maxWidth - (count - 1) * 10) / count;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _wallets.asMap().entries.map((entry) {
                    final i = entry.key;
                    final w = entry.value;
                    final flow = _flows[w.id] ?? {'in': 0.0, 'out': 0.0};

                    Color stripeColor = AppColors.primary;
                    Color iconColor = AppColors.primary;
                    Color iconBg = AppColors.primaryLight;
                    String iconName = 'cash';

                    if (i == 1) {
                      stripeColor = AppColors.violet;
                      iconColor = AppColors.violet;
                      iconBg = AppColors.violetBg;
                      iconName = 'sale';
                    } else if (i == 2) {
                      stripeColor = const Color(0xFF16A168);
                      iconColor = AppColors.green;
                      iconBg = AppColors.greenBg;
                      iconName = 'wallet';
                    } else if (i == 3) {
                      stripeColor = const Color(0xFFD97706);
                      iconColor = AppColors.amber;
                      iconBg = AppColors.amberBg;
                      iconName = 'cash';
                    }

                    return SizedBox(
                      width: width,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 3,
                                child: Container(color: stripeColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: iconBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: AppIcons.icon(iconName, size: 17, color: iconColor),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      w.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.text,
                                                      ),
                                                    ),
                                                    Text(
                                                      w.type,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 8.5, color: Color(0xFF768092)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppBadge(
                                          label: w.balance >= 0 ? 'Normal' : 'Overdrawn',
                                          tone: w.balance >= 0 ? BadgeTone.green : BadgeTone.red,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Rs ${_currencyFormat.format(w.balance)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildFlowItem(
                                            'Total in',
                                            'Rs ${_currencyFormat.format(flow['in'] ?? 0.0)}',
                                            AppColors.green,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildFlowItem(
                                            'Total out',
                                            'Rs ${_currencyFormat.format(flow['out'] ?? 0.0)}',
                                            AppColors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppButton(
                                            label: 'Transfer',
                                            icon: 'arrow',
                                            variant: ButtonVariant.secondary,
                                            onClick: _openTransferDialog,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AppButton(
                                            label: 'Ledger',
                                            icon: 'book',
                                            variant: ButtonVariant.secondary,
                                            onClick: () => _viewWalletLedger(w),
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
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 14),

          // Day-End Cash Reconciliation
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Day-End Cash Reconciliation',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Count physical cash in the drawer and match with the system balance',
                          style: TextStyle(fontSize: 10, color: Color(0xFF768092)),
                        ),
                      ],
                    ),
                    AppBadge(
                      label: _difference == 0
                          ? 'Balanced'
                          : (_difference > 0 ? 'Surplus (+Rs $_difference)' : 'Short (-Rs ${_difference.abs()})'),
                      tone: _difference == 0
                          ? BadgeTone.green
                          : (_difference > 0 ? BadgeTone.amber : BadgeTone.red),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recon Grid (4 steps)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 30) / 4;

                      Color diffColor = AppColors.green;
                      String diffText = 'Rs 0';
                      String diffStatus = 'Matches expected';

                      if (_difference > 0) {
                        diffColor = AppColors.amber;
                        diffText = '+Rs ${_currencyFormat.format(_difference)}';
                        diffStatus = 'Cash surplus';
                      } else if (_difference < 0) {
                        diffColor = AppColors.red;
                        diffText = '-Rs ${_currencyFormat.format(_difference.abs())}';
                        diffStatus = 'Discrepancy shortfall';
                      }

                      return Row(
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildReconInfo('Opening cash in drawer', 'Rs 268,450.00'),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildReconInfo('Expected drawer closing', 'Rs ${_currencyFormat.format(_expectedClosing)}.00'),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Counted cash in drawer',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF768092)),
                                ),
                                const SizedBox(height: 5),
                                _DrawerCountField(controller: _countedController),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Drawer difference',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF768092)),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  diffText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: diffColor,
                                  ),
                                ),
                                Text(
                                  diffStatus,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: diffColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Recon Footer
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            AppIcons.icon('check', size: 16, color: AppColors.green),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Balances never reset; today’s closing balance becomes tomorrow’s opening balance.',
                                style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        label: 'Complete reconciliation',
                        variant: ButtonVariant.primary,
                        onClick: _completeReconciliation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF768092)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReconInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF768092)),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _DrawerCountField extends StatefulWidget {
  final TextEditingController controller;

  const _DrawerCountField({required this.controller});

  @override
  State<_DrawerCountField> createState() => _DrawerCountFieldState();
}

class _DrawerCountFieldState extends State<_DrawerCountField> {
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
        : (_isHovered ? const Color(0xFF64748B) : const Color(0xFFD3D8E0));

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 28,
        width: 140,
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
        child: Row(
          children: [
            const Text(
              'Rs ',
              style: TextStyle(fontSize: 11, color: Color(0xFF768092), fontWeight: FontWeight.w500),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.text,
                ),
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
          ],
        ),
      ),
    );
  }
}
