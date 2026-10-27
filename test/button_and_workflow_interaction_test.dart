import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/main.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/components/erp_operation_dialogs.dart';
import 'package:saltflow/components/party_form_dialog.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 40));
    if (tester.any(finder)) return;
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  }
}

Future<void> settleAsync(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
}

Future<void> closeDialog(WidgetTester tester) async {
  final closeBtn = find.text('Close');
  if (closeBtn.evaluate().isNotEmpty) {
    await tester.tap(closeBtn.last);
  } else {
    final closeIcon = find.byIcon(Icons.close);
    if (closeIcon.evaluate().isNotEmpty) {
      await tester.tap(closeIcon.last);
    }
  }
  await settleAsync(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_button_test_');
    dbPath = p.join(tempDir.path, 'test_anwar_salt.db');
    final dbService = DatabaseService.createTestingInstance(dbPath);
    await dbService.database;
    DatabaseService.setTestingInstance(dbService);
  });

  tearDown(() async {
    DatabaseService.setTestingInstance(null);
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget createTestApp() {
    return const SaltFlowApp();
  }

  group('SaltFlow ERP - Comprehensive Button & Popup Verification Suite', () {
    testWidgets('1. Sidebar Navigation - tests all 12 modules switch and render properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      final modules = [
        {'nav': 'Products & Units', 'verify': 'Add product'},
        {'nav': 'Stock Management', 'verify': 'Stock adjustment'},
        {'nav': 'Packaging & Production', 'verify': 'Record production'},
        {'nav': 'Purchases', 'verify': 'New purchase'},
        {'nav': 'Sales', 'verify': 'New sale'},
        {'nav': 'Suppliers', 'verify': 'Add supplier'},
        {'nav': 'Customers', 'verify': 'Add customer'},
        {'nav': 'Daily Records', 'verify': 'Add daily record'},
        {'nav': 'Cash & Wallets', 'verify': 'Transfer money'},
        {'nav': 'Reports', 'verify': 'Create custom report'},
        {'nav': 'Settings', 'verify': 'Settings'},
        {'nav': 'Dashboard', 'verify': 'Today\'s sales'},
      ];

      for (final m in modules) {
        final navFinder = find.widgetWithText(MouseRegion, m['nav']!);
        expect(navFinder, findsWidgets);
        await tester.tap(navFinder.first);
        await pumpUntilFound(tester, find.text(m['verify']!));
        if (m['nav'] == 'Cash & Wallets') {
          await pumpUntilFound(tester, find.text('Cash in Hand'));
        }
        await settleAsync(tester);
        expect(find.text(m['verify']!), findsWidgets, reason: 'Failed navigating to ${m['nav']}');
      }

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    });

    testWidgets('2. Top Header Buttons - Notifications Bell and User Profile Popups', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Tap Notification Bell
      final bellFinder = find.byTooltip('2 Active Stock Alerts');
      expect(bellFinder, findsOneWidget);
      await tester.tap(bellFinder);
      await settleAsync(tester);
      expect(find.textContaining('Operational Alerts'), findsOneWidget);

      // Close notification popover by tapping close icon
      final closeBell = find.descendant(
        of: find.byType(NotificationPopover),
        matching: find.byIcon(Icons.close),
      );
      if (closeBell.evaluate().isNotEmpty) {
        await tester.tap(closeBell);
      } else {
        await tester.tapAt(const Offset(100, 100));
      }
      await settleAsync(tester);
      expect(find.textContaining('Operational Alerts'), findsNothing);

      // Tap User Profile Button
      final userProfileFinder = find.text('Adnan Khan');
      expect(userProfileFinder, findsWidgets);
      await tester.tap(userProfileFinder.first);
      await settleAsync(tester);
      expect(find.text('View & Edit Profile'), findsOneWidget);

      // Tap 'View & Edit Profile' to open UserProfileDialog
      await tester.tap(find.text('View & Edit Profile'));
      await settleAsync(tester);
      expect(find.byType(UserProfileDialog), findsOneWidget);
      expect(find.textContaining('Managing Director'), findsWidgets);

      // Close profile dialog
      await closeDialog(tester);
      expect(find.byType(UserProfileDialog), findsNothing);
    });

    testWidgets('3. Products Page - Add Product, Export, Filters and Details', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Products
      await tester.tap(find.widgetWithText(MouseRegion, 'Products & Units').first);
      await pumpUntilFound(tester, find.text('Add product'));
      await settleAsync(tester);

      // Test "Add product" button -> opens ProductFormDialog
      await tester.tap(find.text('Add product'));
      await settleAsync(tester);
      expect(find.byType(ProductFormDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(ProductFormDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      final exportBtn = find.text('Export');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Product Catalog & Unit Specifications'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test "Filters" button -> opens Filter Catalog Products dialog
      final filtersBtn = find.text('Filters');
      expect(filtersBtn, findsOneWidget);
      await tester.tap(filtersBtn);
      await settleAsync(tester);
      expect(find.text('Filter Catalog Products'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settleAsync(tester);
      expect(find.text('Filter Catalog Products'), findsNothing);
    });

    testWidgets('4. Stock Page - Stock Adjustment, Stock Profile Dialog & Row Clicks', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Stock Management
      await tester.tap(find.widgetWithText(MouseRegion, 'Stock Management').first);
      await pumpUntilFound(tester, find.text('Stock adjustment'));
      await settleAsync(tester);

      // Test "Stock adjustment" button -> opens StockAdjustmentDialog
      await tester.tap(find.text('Stock adjustment'));
      await settleAsync(tester);
      expect(find.byType(StockAdjustmentDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(StockAdjustmentDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Stock Valuation & Inventory Balances'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test clicking on a table row item -> opens StockProfileDialog
      await pumpUntilFound(tester, find.text('HGM Pink Salt 800g × 24'));
      final saltProduct = find.text('HGM Pink Salt 800g × 24');
      expect(saltProduct, findsWidgets);
      await tester.tap(saltProduct.first);
      await settleAsync(tester);
      expect(find.byType(StockProfileDialog), findsOneWidget);
      expect(find.textContaining('STOCK MOVEMENT LEDGER'), findsOneWidget);

      // Close StockProfileDialog
      await closeDialog(tester);
      expect(find.byType(StockProfileDialog), findsNothing);
    });

    testWidgets('5. Packaging & Production Page - Record Production & Export', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Packaging & Production
      await tester.tap(find.widgetWithText(MouseRegion, 'Packaging & Production').first);
      await pumpUntilFound(tester, find.text('Record production'));
      await settleAsync(tester);

      // Test "Record production" button -> opens ProductionBatchDialog
      await tester.tap(find.text('Record production'));
      await settleAsync(tester);
      expect(find.byType(ProductionBatchDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(ProductionBatchDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Production Batches & Manufacturing Yield Log'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);
    });

    testWidgets('6. Commercial Pages (Sales & Purchases) - New Sale, Export & Filters', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Sales
      await tester.tap(find.widgetWithText(MouseRegion, 'Sales').first);
      await pumpUntilFound(tester, find.text('New sale'));
      await settleAsync(tester);

      // Test "New sale" button -> opens TransactionEntryDialog
      await tester.tap(find.text('New sale'));
      await settleAsync(tester);
      expect(find.byType(TransactionEntryDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(TransactionEntryDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Sales Ledger & Commercial Statement'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test "Filters" button -> opens Filter Sales dialog
      await tester.tap(find.text('Filters'));
      await settleAsync(tester);
      expect(find.text('Filter Sales'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settleAsync(tester);
      expect(find.text('Filter Sales'), findsNothing);
    });

    testWidgets('7. Parties Pages (Customers & Suppliers) - Add Party, Detail View & Back', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Customers
      await tester.tap(find.widgetWithText(MouseRegion, 'Customers').first);
      await pumpUntilFound(tester, find.text('Add customer'));
      await pumpUntilFound(tester, find.text('Al-Madina Traders'));
      await settleAsync(tester);

      // Test "Add customer" button -> opens PartyFormDialog
      await tester.tap(find.text('Add customer'));
      await settleAsync(tester);
      expect(find.byType(PartyFormDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(PartyFormDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Customers Directory & Statement'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test clicking on customer row -> opens PartyDetailPage
      final customerItem = find.text('Al-Madina Traders');
      expect(customerItem, findsWidgets);
      await tester.tap(customerItem.first);
      await pumpUntilFound(tester, find.text('Back to Customers Directory'));
      await settleAsync(tester);
      expect(find.text('Back to Customers Directory'), findsOneWidget);
      expect(find.text('Al-Madina Traders'), findsWidgets);

      // Test "Back to Customers Directory" button
      await tester.tap(find.text('Back to Customers Directory'));
      await pumpUntilFound(tester, find.text('Add customer'));
      await settleAsync(tester);
      expect(find.text('Back to Customers Directory'), findsNothing);
      expect(find.text('Add customer'), findsOneWidget);
    });

    testWidgets('8. Daily Records Page - Add Daily Record, Quick Actions, Filters & Details', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Daily Records
      await tester.tap(find.widgetWithText(MouseRegion, 'Daily Records').first);
      await pumpUntilFound(tester, find.text('Add daily record'));
      await settleAsync(tester);

      // Test "Add daily record" button -> opens DailyVoucherDialog
      await tester.tap(find.text('Add daily record'));
      await settleAsync(tester);
      expect(find.byType(DailyVoucherDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(DailyVoucherDialog), findsNothing);

      // Test Quick Action: "Receive money"
      await tester.tap(find.text('Receive money'));
      await settleAsync(tester);
      expect(find.byType(DailyVoucherDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Daily General Cash Book & Vouchers'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test "Filters" button -> opens Filter Daily Records dialog
      await tester.tap(find.text('Filters'));
      await settleAsync(tester);
      expect(find.text('Filter Daily Records'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settleAsync(tester);
      expect(find.text('Filter Daily Records'), findsNothing);
    });

    testWidgets('9. Cash & Wallets Page - Transfer Money, Wallet Ledger & Export', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Cash & Wallets
      await tester.tap(find.widgetWithText(MouseRegion, 'Cash & Wallets').first);
      await pumpUntilFound(tester, find.text('Cash in Hand'));
      await settleAsync(tester);

      // Test "Transfer money" button -> opens WalletTransferDialog
      await tester.tap(find.text('Transfer money'));
      await settleAsync(tester);
      expect(find.byType(WalletTransferDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(WalletTransferDialog), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('Cash & Wallet Accounts Statement'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test Wallet card "Ledger" button
      final ledgerBtn = find.text('Ledger');
      expect(ledgerBtn, findsWidgets);
      await tester.tap(ledgerBtn.first);
      await pumpUntilFound(tester, find.textContaining('Wallet Ledger:'));
      await settleAsync(tester);
      expect(find.textContaining('Wallet Ledger:'), findsOneWidget);
      await tester.tap(find.text('Close ledger'));
      await settleAsync(tester);
      expect(find.textContaining('Wallet Ledger:'), findsNothing);
    });

    testWidgets('10. Reports Page - Create Custom Report, Export Catalog & Report Preview', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Reports
      await tester.tap(find.widgetWithText(MouseRegion, 'Reports').first);
      await pumpUntilFound(tester, find.text('Create custom report'));
      await settleAsync(tester);

      // Test "Create custom report" button -> opens Generate Custom ERP Report dialog
      await tester.tap(find.text('Create custom report'));
      await settleAsync(tester);
      expect(find.text('Generate Custom ERP Report'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.text('Generate Custom ERP Report'), findsNothing);

      // Test "Export" button -> opens AppExportDialog
      await tester.tap(find.text('Export'));
      await settleAsync(tester);
      expect(find.byType(AppExportDialog), findsOneWidget);
      expect(find.text('ERP Financial & Operational Reports Catalog'), findsOneWidget);
      await closeDialog(tester);
      expect(find.byType(AppExportDialog), findsNothing);

      // Test Monthly Snapshot "Preview" button -> opens report dialog
      await tester.tap(find.text('Preview'));
      await pumpUntilFound(tester, find.textContaining('Monthly Business Performance'));
      await settleAsync(tester);
      expect(find.textContaining('Monthly Business Performance'), findsWidgets);
      await closeDialog(tester);
    });

    testWidgets('11. Settings Page - Tabs, Staff Member Dialog & Backup Services', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await settleAsync(tester);

      // Navigate to Settings
      await tester.tap(find.widgetWithText(MouseRegion, 'Settings').first);
      await pumpUntilFound(tester, find.text('Backup & recovery'));
      await settleAsync(tester);

      // Switch to 'Users & permissions' tab
      await tester.tap(find.text('Users & permissions'));
      await settleAsync(tester);
      expect(find.text('Add staff user'), findsOneWidget);

      // Tap 'Add staff user' -> opens StaffUserDialog
      await tester.tap(find.text('Add staff user'));
      await settleAsync(tester);
      expect(find.byType(StaffUserDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleAsync(tester);
      expect(find.byType(StaffUserDialog), findsNothing);

      // Switch to 'Business profile' tab
      await tester.tap(find.text('Business profile'));
      await settleAsync(tester);
      expect(find.text('Factory Legal & Commercial Profile'), findsOneWidget);

      // Switch to 'Thermal printing' tab
      await tester.tap(find.text('Thermal printing'));
      await settleAsync(tester);
      expect(find.text('Test print'), findsOneWidget);

      // Switch back to 'Backup & recovery'
      await tester.tap(find.text('Backup & recovery'));
      await settleAsync(tester);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Open backup folder'), findsOneWidget);
    });
  });
}
