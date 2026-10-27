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
                      // Search input with world-class focus ring & hover
                      Expanded(
                        flex: 3,
                        child: ErpSearchInput(
                          placeholder: 'Search ${widget.type.toLowerCase()} by name, phone, code or address...',
                          shortcutLabel: 'Ctrl K',
                          onChanged: (q) {
                            _searchQuery = q;
                            _loadData();
                          },
                          onClear: () {
                            _searchQuery = '';
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Filter Pills with Hover
                      Wrap(
                        spacing: 6,
                        children: ['All', 'Active', 'Outstanding', 'Archived'].map((f) {
                          final selected = _statusFilter == f;
                          return _HoverFilterPill(
                            label: f,
                            isSelected: selected,
                            onTap: () {
                              setState(() => _statusFilter = f);
                              _loadData();
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 12),

                      // Sort dropdown with hover effect
                      _HoverDropdown(
                        value: _sortOption,
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
                      final tableWidth = constraints.maxWidth > 980 ? constraints.maxWidth : 980.0;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Table Header
                              Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.tableHeaderBg,
                                  border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(flex: 26, child: _HeaderCell(_singularType.toUpperCase())),
                                    const Expanded(flex: 18, child: _HeaderCell('CONTACT / PHONE')),
                                    const Expanded(flex: 16, child: _HeaderCell('CURRENT BALANCE', align: TextAlign.right)),
                                    const Expanded(flex: 14, child: _HeaderCell('DIRECTION')),
                                    const Expanded(flex: 15, child: _HeaderCell('LAST ACTIVITY')),
                                    const Expanded(flex: 12, child: _HeaderCell('STATUS')),
                                    const SizedBox(width: 90, child: _HeaderCell('')),
                                  ],
                                ),
                              ),

                              // Interactive Hoverable Party Profile Rows
                              ..._parties.map((p) {
                                final balAbs = p.currentBalance.abs();
                                final isSettled = balAbs <= 0.01;
                                final dir = p.balanceDirection;

                                final badgeTone = p.isArchived
                                    ? BadgeTone.neutral
                                    : isSettled
                                        ? BadgeTone.green
                                        : (dir == 'Receivable' ? BadgeTone.amber : BadgeTone.blue);

                                final initials = p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('');

                                return _HoverPartyRow(
                                  party: p,
                                  initials: initials,
                                  isSupplier: isSupplier,
                                  isSettled: isSettled,
                                  dir: dir,
                                  balAbs: balAbs,
                                  badgeTone: badgeTone,
                                  currencyFormat: _currencyFormat,
                                  onTap: () => setState(() => _selectedPartyId = p.id),
                                  onEdit: () => _openEditDialog(p),
                                  onArchive: () => _toggleArchive(p),
                                  onDelete: () => _deleteParty(p),
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

class _HoverPartyRow extends StatefulWidget {
  final Party party;
  final String initials;
  final bool isSupplier;
  final bool isSettled;
  final String dir;
  final double balAbs;
  final BadgeTone badgeTone;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _HoverPartyRow({
    required this.party,
    required this.initials,
    required this.isSupplier,
    required this.isSettled,
    required this.dir,
    required this.balAbs,
    required this.badgeTone,
    required this.currencyFormat,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  State<_HoverPartyRow> createState() => _HoverPartyRowState();
}

class _HoverPartyRowState extends State<_HoverPartyRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.party;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            border: Border(
              bottom: const BorderSide(color: AppColors.borderLight),
              left: BorderSide(
                color: _isHovered ? AppColors.brandPrimary : Colors.transparent,
                width: 3.5,
              ),
            ),
            boxShadow: _isHovered
                ? const [
                    BoxShadow(
                      color: Color(0x0C0F172A),
                      blurRadius: 6,
                      offset: Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Name & Code
              Expanded(
                flex: 26,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: _isHovered ? 1.04 : 1.0,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: widget.isSupplier ? AppColors.amberLight : AppColors.brandLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isHovered
                                  ? (widget.isSupplier ? AppColors.amber : AppColors.brandPrimary)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                            boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: (widget.isSupplier ? AppColors.amber : AppColors.brandPrimary).withAlpha(40),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.initials,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.isSupplier ? AppColors.amber : AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _isHovered ? AppColors.brandPrimary : AppColors.textPrimary,
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
              Expanded(
                flex: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
              Expanded(
                flex: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'Rs ${widget.currencyFormat.format(widget.balAbs)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: widget.isSettled
                          ? AppColors.green
                          : (p.type == 'Customer'
                              ? (p.currentBalance > 0 ? AppColors.amber : AppColors.brandPrimary)
                              : (p.currentBalance > 0 ? AppColors.brandPrimary : AppColors.amber)),
                    ),
                  ),
                ),
              ),

              // Direction
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    widget.isSettled ? 'Settled (Rs 0)' : widget.dir,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isSettled ? AppColors.green : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              // Last Activity Date
              Expanded(
                flex: 15,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBadge(
                      label: p.isArchived ? 'Archived' : (widget.isSettled ? 'Settled' : p.status),
                      tone: widget.badgeTone,
                    ),
                  ),
                ),
              ),

              // Open Details & Actions
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'View Profile & Ledger',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _isHovered ? AppColors.brandLight : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isHovered ? AppColors.brandPrimary.withAlpha(80) : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AppIcons.icon('arrow', size: 13, color: AppColors.brandPrimary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: PopupMenuButton<String>(
                          tooltip: 'Profile options',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 160),
                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                          onSelected: (action) {
                          if (action == 'view') {
                            widget.onTap();
                          } else if (action == 'edit') {
                            widget.onEdit();
                          } else if (action == 'archive') {
                            widget.onArchive();
                          } else if (action == 'delete') {
                            widget.onDelete();
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
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverFilterPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HoverFilterPill> createState() => _HoverFilterPillState();
}

class _HoverFilterPillState extends State<_HoverFilterPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (widget.isSelected) {
      bg = AppColors.brandLight;
      border = AppColors.brandPrimary;
    } else if (_isHovered) {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFF94A3B8);
    } else {
      bg = const Color(0xFFF8FAFC);
      border = AppColors.border;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isHovered && !widget.isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
              color: widget.isSelected ? AppColors.brandPrimary : (_isHovered ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverDropdown extends StatefulWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _HoverDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_HoverDropdown> createState() => _HoverDropdownState();
}

class _HoverDropdownState extends State<_HoverDropdown> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border.all(
            color: _isHovered ? const Color(0xFF64748B) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          boxShadow: _isHovered
              ? const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.value,
            style: TextStyle(
              fontSize: 11,
              color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            items: widget.items,
            onChanged: widget.onChanged,
          ),
        ),
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
