import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/erp_models.dart';
import '../components/app_components.dart';
import '../components/app_icons.dart';
import '../components/receipt_modal.dart';
import '../components/erp_operation_dialogs.dart';
import 'dashboard_page.dart';
import 'products_page.dart';
import 'stock_page.dart';
import 'production_page.dart';
import 'parties_page.dart';
import 'transactions_page.dart';
import 'daily_records_page.dart';
import 'wallets_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class NavGroup {
  final String title;
  final List<NavItem> items;
  const NavGroup({required this.title, required this.items});
}

class NavItem {
  final String label;
  final String icon;
  final bool hasBadge;
  final String? badgeValue;
  const NavItem(this.label, this.icon, {this.hasBadge = false, this.badgeValue});
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _currentPage = 'Dashboard';
  bool _isCollapsed = false;
  bool _showReceipt = false;
  ReceiptData? _activeReceiptData;
  bool _showUserMenu = false;
  bool _showNotifications = false;
  String _userName = 'Adnan Khan';
  String _userRole = 'Owner & Managing Director';

  void _openProfileDialog() {
    setState(() {
      _showUserMenu = false;
      _showNotifications = false;
    });
    showDialog<bool>(
      context: context,
      builder: (ctx) => UserProfileDialog(
        initialName: _userName,
        initialRole: _userRole,
        onSave: (updated) {
          setState(() {
            _userName = updated['name'] ?? _userName;
            _userRole = updated['role'] ?? _userRole;
          });
          AppToast.showSuccess(context, 'User profile updated successfully.');
        },
      ),
    );
  }

  void _handleGlobalSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    for (final group in navGroups) {
      for (final item in group.items) {
        if (item.label.toLowerCase().contains(q)) {
          setState(() => _currentPage = item.label);
          AppToast.showSuccess(context, 'Navigated to ${item.label}');
          return;
        }
      }
    }
  }

  void _openReceipt([ReceiptData? data]) {
    setState(() {
      _activeReceiptData = data;
      _showReceipt = true;
    });
  }

  static const List<NavGroup> navGroups = [
    NavGroup(
      title: 'OVERVIEW',
      items: [
        NavItem('Dashboard', 'grid'),
      ],
    ),
    NavGroup(
      title: 'OPERATIONS',
      items: [
        NavItem('Products & Units', 'box'),
        NavItem('Stock Management', 'stock', hasBadge: true, badgeValue: '2'),
        NavItem('Packaging & Production', 'factory'),
      ],
    ),
    NavGroup(
      title: 'COMMERCIAL',
      items: [
        NavItem('Purchases', 'cart'),
        NavItem('Sales', 'sale'),
        NavItem('Suppliers', 'truck'),
        NavItem('Customers', 'users'),
      ],
    ),
    NavGroup(
      title: 'FINANCE & AUDIT',
      items: [
        NavItem('Daily Records', 'calendar'),
        NavItem('Cash & Wallets', 'wallet'),
        NavItem('Reports', 'report'),
      ],
    ),
    NavGroup(
      title: 'SYSTEM',
      items: [
        NavItem('Settings', 'settings'),
      ],
    ),
  ];

  String _getSectionName(String page) {
    for (final group in navGroups) {
      for (final item in group.items) {
        if (item.label == page) return group.title;
      }
    }
    return 'ERP';
  }

  Widget _buildContent() {
    switch (_currentPage) {
      case 'Dashboard':
        return DashboardPage(
          setPage: (p) => setState(() => _currentPage = p),
          openReceipt: () => _openReceipt(),
        );
      case 'Products & Units':
        return const ProductsPage();
      case 'Stock Management':
        return const StockPage();
      case 'Packaging & Production':
        return const ProductionPage();
      case 'Suppliers':
      case 'Customers':
        return PartiesPage(type: _currentPage);
      case 'Purchases':
      case 'Sales':
        return TransactionsPage(
          type: _currentPage,
          openReceipt: _openReceipt,
        );
      case 'Daily Records':
        return const DailyRecordsPage();
      case 'Cash & Wallets':
        return const WalletsPage();
      case 'Reports':
        return const ReportsPage();
      case 'Settings':
      default:
        return SettingsPage(
          openReceipt: () => _openReceipt(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = _isCollapsed ? 74.0 : 252.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Row(
            children: [
              // Enterprise Desktop Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
                decoration: const BoxDecoration(
                  color: AppColors.sidebarNavy,
                  border: Border(
                    right: BorderSide(color: Color(0xFF1E293B)),
                  ),
                ),
                child: Column(
                  children: [
                    // Refined Corporate Brand Header
                    AppBrandLogo(
                      isCollapsed: _isCollapsed,
                      onTap: () => setState(() => _currentPage = 'Dashboard'),
                    ),

                    // Nav List with Module Groups
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        children: [
                          for (final group in navGroups) ...[
                            if (!_isCollapsed) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                                child: Text(
                                  group.title,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(
                                  color: Color.fromRGBO(255, 255, 255, 0.08),
                                  height: 1,
                                ),
                              ),
                            ],
                            for (final item in group.items) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: _SidebarNavButton(
                                  label: item.label,
                                  icon: item.icon,
                                  isActive: _currentPage == item.label,
                                  hasBadge: item.hasBadge,
                                  badgeValue: item.badgeValue,
                                  isCollapsed: _isCollapsed,
                                  onTap: () => setState(() => _currentPage = item.label),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // Sidebar Footer (DB Status + Collapse Toggle)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.07)),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Sync Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 255, 255, 0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.greenIndicator,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.greenIndicator.withAlpha(90),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isCollapsed) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Database Online',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'Auto-backup synced',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Collapse Sidebar Button
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                              child: Container(
                                height: 34,
                                padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 10),
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(255, 255, 255, 0.02),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _isCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                                      size: 16,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    if (!_isCollapsed) ...[
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Collapse Sidebar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Application Window
              Expanded(
                child: Column(
                  children: [
                    // Top Bar
                    Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Breadcrumb Navigation
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getSectionName(_currentPage),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppColors.textSubtle,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentPage,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          // Top Actions (Search, Notifications, Profile)
                          Row(
                            children: [
                              // Global Search
                              Container(
                                width: 240,
                                height: 35,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    AppIcons.icon('search', size: 15, color: AppColors.textSubtle),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        onSubmitted: _handleGlobalSearch,
                                        decoration: const InputDecoration(
                                          hintText: 'Search ERP (press Enter)...',
                                          hintStyle: TextStyle(
                                            color: AppColors.textSubtle,
                                            fontSize: 11.5,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: AppColors.borderStrong),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: AppColors.shadowSm,
                                      ),
                                      child: const Text(
                                        'Ctrl K',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Notification Bell with Badge
                              Tooltip(
                                message: '2 Active Stock Alerts',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _showNotifications = !_showNotifications;
                                      _showUserMenu = false;
                                    }),
                                    child: Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: _showNotifications ? AppColors.surfaceMuted : Colors.white,
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AppIcons.icon('bell', size: 17, color: AppColors.textSecondary),
                                          Positioned(
                                            top: 7,
                                            right: 7,
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: AppColors.danger,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 1.2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // User Profile AK
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _showUserMenu = !_showUserMenu;
                                    _showNotifications = false;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                                    decoration: BoxDecoration(
                                      color: _showUserMenu ? AppColors.surfaceMuted : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 33,
                                          height: 33,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _userName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join(''),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _userName,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              _userRole,
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Page Body with Smooth Transition
                    Expanded(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, AppMotion.page),
                          switchInCurve: AppMotion.easeOut,
                          switchOutCurve: AppMotion.easeIn,
                          transitionBuilder: (child, animation) {
                            if (AppMotion.isReducedMotion(context)) return child;
                            return FadeTransition(
                              opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.015),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(parent: animation, curve: AppMotion.easeOut)),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<String>(_currentPage),
                            child: _buildContent(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // User Info Dropdown with smooth animated entrance
          if (_showUserMenu) ...[
            GestureDetector(
              onTap: () => setState(() => _showUserMenu = false),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: 65,
              right: 28,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    boxShadow: AppColors.shadowLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.brandLight,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'AK',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Adnan Khan',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Owner & Managing Director',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: AppColors.borderLight),
                      const Text(
                        'Anwar Salt Factory (Pvt) Ltd',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Industrial Estate, Peshawar',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'System: SaltFlow Desktop v2.4.0',
                        style: TextStyle(fontSize: 9.5, color: AppColors.textSubtle),
                      ),
                      const Divider(height: 18, color: AppColors.borderLight),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _openProfileDialog,
                          child: Row(
                            children: const [
                              Icon(Icons.person_outline, size: 15, color: AppColors.brandPrimary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'View & Edit Profile',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentPage = 'Settings';
                              _showUserMenu = false;
                            });
                          },
                          child: Row(
                            children: const [
                              Icon(Icons.settings_outlined, size: 14, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Factory Settings',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
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
            ),
          ],

          // Active Operational Alerts Notification Popover
          if (_showNotifications) ...[
            GestureDetector(
              onTap: () => setState(() => _showNotifications = false),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: 65,
              right: 185,
              child: NotificationPopover(
                onNavigate: (page) => setState(() {
                  _currentPage = page;
                  _showNotifications = false;
                }),
                onClose: () => setState(() => _showNotifications = false),
              ),
            ),
          ],


          // Modal Overlay
          if (_showReceipt)
            ReceiptModal(
              receiptData: _activeReceiptData,
              onClose: () => setState(() {
                _showReceipt = false;
                _activeReceiptData = null;
              }),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavButton extends StatefulWidget {
  final String label;
  final String icon;
  final bool isActive;
  final bool hasBadge;
  final String? badgeValue;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarNavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.hasBadge,
    this.badgeValue,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarNavButton> createState() => _SidebarNavButtonState();
}

class _SidebarNavButtonState extends State<_SidebarNavButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = const Color(0xFF94A3B8);

    if (widget.isActive) {
      bg = AppColors.brandPrimary;
      fg = Colors.white;
    } else if (_isHovered) {
      bg = const Color(0xFF1E293B);
      fg = const Color(0xFFF1F5F9);
    }

    return Tooltip(
      message: widget.isCollapsed ? widget.label : '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1.0,
            duration: AppMotion.duration(context, AppMotion.micro),
            curve: AppMotion.easeOut,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.easeOut,
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: AppColors.brandPrimary.withAlpha(50),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  // Active Left Bar Indicator with smooth expansion
                  AnimatedContainer(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    curve: AppMotion.easeOut,
                    width: (widget.isActive && !widget.isCollapsed) ? 3.0 : 0.0,
                    height: (widget.isActive && !widget.isCollapsed) ? 16.0 : 0.0,
                    margin: EdgeInsets.only(right: (widget.isActive && !widget.isCollapsed) ? 8.0 : 0.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF93C5FD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppIcons.icon(
                    widget.icon,
                    size: 17,
                    color: fg,
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                    if (widget.hasBadge)
                      AnimatedScale(
                        scale: widget.hasBadge ? 1.0 : 0.0,
                        duration: AppMotion.duration(context, AppMotion.fast),
                        curve: AppMotion.easeOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.badgeValue ?? '!',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

