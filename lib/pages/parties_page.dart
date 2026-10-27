import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/party.dart';
import '../repositories/party_repository.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/module_page.dart';
import '../components/party_form_dialog.dart';
import '../components/erp_operation_dialogs.dart';
import 'party_detail_page.dart';

class PartiesPage extends StatefulWidget {
  final String type; // 'Suppliers' or 'Customers'
  final PartyRepository? repository;

  const PartiesPage({super.key, required this.type, this.repository});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  late final PartyRepository _repository;
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Active', 'Outstanding', 'Archived'
  String _sortOption = 'Name (A-Z)'; // 'Name (A-Z)', 'Balance (Highest)', 'Recent Activity'

  List<Party> _parties = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedPartyId;

  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PartyRepository();
    _loadData();
  }

  @override
  void didUpdateWidget(PartiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _selectedPartyId = null;
      _loadData();
    }
  }

  String get _singularType => widget.type == 'Suppliers' ? 'Supplier' : 'Customer';

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parties = await _repository.getParties(
        type: _singularType,
        searchQuery: _searchQuery,
        statusFilter: _statusFilter,
        sortOption: _sortOption,
      );
      final stats = await _repository.getSummaryStats(_singularType);

      if (mounted) {
        setState(() {
          _parties = parties;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading $_singularType directory: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddDialog() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PartyFormDialog(
        type: _singularType,
        repository: _repository,
      ),
    );

    if (res == true) {
      await _loadData();
      if (mounted) {
        AppToast.showSuccess(context, 'New $_singularType profile registered successfully.');
      }
    }
  }

  Future<void> _openEditDialog(Party p) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PartyFormDialog(
        type: _singularType,
        partyToEdit: p,
        repository: _repository,
      ),
    );

    if (res == true) {
      await _loadData();
      if (mounted) {
        AppToast.showSuccess(context, 'Profile for "${p.name}" updated successfully.');
      }
    }
  }

  Future<void> _toggleArchive(Party p) async {
    final newState = !p.isArchived;
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: newState ? 'Archive Profile?' : 'Restore Profile?',
      message: newState
          ? 'Archiving "${p.name}" will hide them from active sales/purchase selectors. All historical ledger entries remain strictly preserved.'
          : 'Restore "${p.name}" to active status for current factory operations?',
      confirmLabel: newState ? 'Archive' : 'Restore',
      isDanger: newState,
      auditNote: 'Audit trails and historical accounting ledgers remain permanently intact.',
    );

    if (confirm == true) {
      await _repository.setArchived(p.id!, newState);
      await _loadData();
      if (mounted) {
        AppToast.showSuccess(
          context,
          newState ? 'Profile archived successfully.' : 'Profile restored to active status.',
        );
      }
    }
  }

  Future<void> _deleteParty(Party p) async {
    if (p.transactionCount > 0) {
      await showAppConfirmationDialog(
        context: context,
        title: 'Audit Trail Protected',
        message: 'Cannot permanently delete "${p.name}" because it has ${p.transactionCount} linked commercial transaction(s). '
            '\n\nERP accounting standards forbid erasing financial history to maintain balanced audit trails. '
            'Please use the "Archive" action instead to deactivate this profile safely.',
        confirmLabel: 'Archive Instead',
        cancelLabel: 'Close',
        isDanger: true,
        auditNote: 'Commercial transactions are permanently locked in the SQLite general ledger.',
      ).then((archiveInstead) {
        if (archiveInstead == true) {
          _toggleArchive(p);
        }
      });
      return;
    }

    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Profile?',
      message: 'Are you sure you want to delete "${p.name}" (${p.code})? '
          'Since this profile has no transaction history, it can be safely removed.',
      confirmLabel: 'Delete Profile',
      isDanger: true,
    );

    if (confirm == true) {
      try {
        await _repository.deleteParty(p.id!);
        await _loadData();
        if (mounted) {
          AppToast.showSuccess(context, 'Profile removed successfully.');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Delete failed: $e');
        }
      }
    }
  }

  void _exportStatement() {
    final headers = ['Code', 'Name', 'Phone', 'Address', 'Balance (Rs)', 'Status'];
    final rows = _parties.map((p) => [
      p.code,
      p.name,
      p.phone,
      p.address ?? 'Factory Trade Account',
      _currencyFormat.format(p.currentBalance),
      p.isArchived ? 'Archived' : 'Active',
    ]).toList();

    showDialog(
      context: context,
      builder: (ctx) => AppExportDialog(
        title: '${widget.type} Directory & Statement',
        subtitle: 'Factory ledger balances, trade accounts and verified contact directory.',
        headers: headers,
        rows: rows,
        filenamePrefix: '${widget.type}_Statement',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If a party profile is selected, show the full detail view
    if (_selectedPartyId != null) {
      return PartyDetailPage(
        partyId: _selectedPartyId!,
        repository: _repository,
        onBack: () {
          setState(() => _selectedPartyId = null);
          _loadData();
        },
      );
    }

    final isSupplier = widget.type == 'Suppliers';
    final totalCount = _stats['totalCount'] ?? _parties.length;
    final activeCount = _stats['activeCount'] ?? _parties.length;
    final totalBalance = (_stats['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final openingSum = (_stats['openingBalanceSum'] as num?)?.toDouble() ?? 0.0;
    final overdueCount = (_stats['overdueCount'] as num?)?.toInt() ?? 0;

    return ModulePage(
      title: widget.type,
      subtitle: 'Manage ${widget.type.toLowerCase()}, live ledger balances and audit trail history.',
      action: 'Add ${_singularType.toLowerCase()}',
      onAction: _openAddDialog,
      onExport: _exportStatement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Top Statistics Strip
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 900 ? 2 : 4;
              final width = (constraints.maxWidth - (count - 1) * 10) / count;
              final items = [
                MiniMetric(
                  label: 'Total ${widget.type.toLowerCase()}',
                  value: '$totalCount',
                  hint: '$activeCount operational • ${totalCount - activeCount} archived',
                ),
                MiniMetric(
                  label: isSupplier ? 'Total payables' : 'Total receivables',
                  value: 'Rs ${_currencyFormat.format(totalBalance)}',
                  hint: overdueCount > 0 ? '$overdueCount accounts overdue' : 'Reconciled with ledgers',
                ),
                MiniMetric(
                  label: isSupplier ? 'Paid this month' : 'Collected this month',
                  value: isSupplier ? 'Rs 97,000.00' : 'Rs 120,500.00',
                  hint: 'Traceable to bank & cash',
                ),
                MiniMetric(
                  label: 'Opening balances',
                  value: 'Rs ${_currencyFormat.format(openingSum)}',
                  hint: 'Non-revenue balance sheet',
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((m) => SizedBox(width: width, child: m)).toList(),
              );
            },
          ),
          const SizedBox(height: 14),

          // Main Directory Table Card
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
                // Filter and Search Toolbar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Search input
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                          child: TextField(
                            onChanged: (q) {
                              _searchQuery = q;
                              _loadData();
                            },
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search ${widget.type.toLowerCase()} by name, phone, code or address...',
                              hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textSubtle),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(9),
                                child: AppIcons.icon('search', size: 14, color: AppColors.textMuted),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 14, color: AppColors.textMuted),
                                      onPressed: () {
                                        setState(() => _searchQuery = '');
                                        _loadData();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Filter Pills
                      Wrap(
                        spacing: 6,
                        children: ['All', 'Active', 'Outstanding', 'Archived'].map((f) {
                          final selected = _statusFilter == f;
                          return InkWell(
                            onTap: () {
                              setState(() => _statusFilter = f);
                              _loadData();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.brandLight : const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: selected ? AppColors.brandPrimary : AppColors.border,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? AppColors.brandPrimary : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 12),

                      // Sort dropdown
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortOption,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: 'Name (A-Z)', child: Text('Sort: Name (A-Z)')),
                              DropdownMenuItem(value: 'Balance (Highest)', child: Text('Sort: Highest Balance')),
                              DropdownMenuItem(value: 'Recent Activity', child: Text('Sort: Recent Activity')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortOption = val);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: DangerNotice(
                      title: 'Directory Notice',
                      message: _errorMessage!,
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AppTableSkeleton(rowCount: 6, columnCount: 6),
                  )
                else if (_parties.isEmpty)
                  AppEmptyState(
                    icon: isSupplier ? 'truck' : 'users',
                    title: 'No ${widget.type.toLowerCase()} found',
                    message: _searchQuery.isNotEmpty
                        ? 'No ${_singularType.toLowerCase()} matched "$_searchQuery".'
                        : 'No ${widget.type.toLowerCase()} match the selected filter "$_statusFilter".',
                    actionLabel: _searchQuery.isNotEmpty ? 'Clear search' : 'Add ${_singularType.toLowerCase()}',
                    onAction: _searchQuery.isNotEmpty
                        ? () {
                            setState(() => _searchQuery = '');
                            _loadData();
                          }
                        : _openAddDialog,
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth > 980 ? constraints.maxWidth : 980,
                          ),
                          child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.6), // Profile Name & Code
                          1: FlexColumnWidth(1.8), // Phone / WhatsApp
                          2: FlexColumnWidth(1.6), // Current Balance
                          3: FlexColumnWidth(1.4), // Direction
                          4: FlexColumnWidth(1.5), // Last Activity
                          5: FlexColumnWidth(1.2), // Status
                          6: FixedColumnWidth(85), // Action
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: AppColors.tableHeaderBg,
                              border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
                            ),
                            children: [
                              _HeaderCell(_singularType.toUpperCase()),
                              const _HeaderCell('CONTACT / PHONE'),
                              const _HeaderCell('CURRENT BALANCE', align: TextAlign.right),
                              const _HeaderCell('DIRECTION'),
                              const _HeaderCell('LAST ACTIVITY'),
                              const _HeaderCell('STATUS'),
                              const _HeaderCell(''),
                            ],
                          ),
                          ..._parties.map((p) {
                            final balAbs = p.currentBalance.abs();
                            final isSettled = balAbs <= 0.01;
                            final dir = p.balanceDirection;

                            // Badge
                            final badgeTone = p.isArchived
                                ? BadgeTone.neutral
                                : isSettled
                                    ? BadgeTone.green
                                    : (dir == 'Receivable' ? BadgeTone.amber : BadgeTone.blue);

                            final initials = p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('');

                            return TableRow(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                              ),
                              children: [
                                // Name & Code
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isSupplier ? AppColors.amberLight : AppColors.brandLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initials,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isSupplier ? AppColors.amber : AppColors.brandPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                p.code,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  color: AppColors.textSubtle,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Phone / Contact
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.phone, style: AppTypography.body),
                                        if (p.contactPerson != null && p.contactPerson!.isNotEmpty) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            p.contactPerson!,
                                            style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                // Current Balance
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(
                                      'Rs ${_currencyFormat.format(balAbs)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        color: isSettled
                                            ? AppColors.green
                                            : (p.type == 'Customer'
                                                ? (p.currentBalance > 0 ? AppColors.amber : AppColors.brandPrimary)
                                                : (p.currentBalance > 0 ? AppColors.brandPrimary : AppColors.amber)),
                                      ),
                                    ),
                                  ),
                                ),

                                // Direction
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(
                                      isSettled ? 'Settled (Rs 0)' : dir,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isSettled ? AppColors.green : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),

                                // Last Activity Date
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(
                                      p.lastTransactionDate != null
                                          ? (p.lastTransactionDate!.length > 10
                                              ? p.lastTransactionDate!.substring(0, 10)
                                              : p.lastTransactionDate!)
                                          : '—',
                                      style: AppTypography.body,
                                    ),
                                  ),
                                ),

                                // Status Badge
                                InkWell(
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AppBadge(
                                        label: p.isArchived ? 'Archived' : (isSettled ? 'Settled' : p.status),
                                        tone: badgeTone,
                                      ),
                                    ),
                                  ),
                                ),

                                // Open Details & Actions
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'View Profile & Ledger',
                                        child: InkWell(
                                          onTap: () => setState(() => _selectedPartyId = p.id),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            alignment: Alignment.center,
                                            child: AppIcons.icon('arrow', size: 13, color: AppColors.brandPrimary),
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Profile options',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 160),
                                        icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                                        onSelected: (action) {
                                          if (action == 'view') {
                                            setState(() => _selectedPartyId = p.id);
                                          } else if (action == 'edit') {
                                            _openEditDialog(p);
                                          } else if (action == 'archive') {
                                            _toggleArchive(p);
                                          } else if (action == 'delete') {
                                            _deleteParty(p);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'view',
                                            child: Text('View Profile & Ledger', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit Profile Details', style: TextStyle(fontSize: 11.5)),
                                          ),
                                          PopupMenuItem(
                                            value: 'archive',
                                            child: Text(p.isArchived ? 'Restore to Active' : 'Archive Profile', style: const TextStyle(fontSize: 11.5)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete Profile', style: TextStyle(fontSize: 11.5, color: AppColors.danger)),
                                          ),
                                        ],
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
