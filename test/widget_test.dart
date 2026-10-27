import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/main.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/repositories/party_repository.dart';
import 'package:saltflow/theme/app_theme.dart';
import 'package:saltflow/pages/parties_page.dart';
import 'package:saltflow/models/party.dart';
import 'package:saltflow/models/ledger_entry.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_widget_test_');
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

  testWidgets('SaltFlow app - Dashboard', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SaltFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('SaltFlow'), findsOneWidget);
    expect(find.text('FACTORY ERP'), findsOneWidget);
    expect(find.text('Good morning, Adnan'), findsOneWidget);
    expect(find.text('Today\'s sales'), findsOneWidget);
  });

  testWidgets('SaltFlow app - Products & Search', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SaltFlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Products & Units').first);
    await pumpUntilFound(tester, find.text('HGM Pink Salt 800g × 24'));
    await tester.pumpAndSettle();

    expect(find.text('Configure products, trading units and reliable stock conversions.'), findsOneWidget);
    expect(find.text('HGM Pink Salt 800g × 24'), findsWidgets);

    final searchField = find.byType(TextField).last;
    await tester.enterText(searchField, 'NonExistentSaltItemXYZ');
    await tester.pumpAndSettle();
    expect(find.text('No products match your search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await pumpUntilFound(tester, find.text('HGM Pink Salt 800g × 24'));
    await tester.pumpAndSettle();
    expect(find.text('HGM Pink Salt 800g × 24'), findsWidgets);
  });

  testWidgets('SaltFlow app - Wallets', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SaltFlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash & Wallets').first);
    await pumpUntilFound(tester, find.text('Cash in Hand'));
    await tester.pumpAndSettle();

    expect(find.text('Day-End Cash Reconciliation'), findsOneWidget);
    expect(find.text('Cash in Hand'), findsWidgets);
  });

  testWidgets('SaltFlow app - Settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SaltFlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Automatic backups'), findsOneWidget);

    await tester.tap(find.text('Business profile'));
    await tester.pumpAndSettle();

    expect(find.text('Factory Site Address'), findsOneWidget);
    expect(find.text('Anwar Salt Factory (Pvt) Ltd'), findsWidgets);

    // Let sqflite internal lock timer settle
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('SaltFlow app - Customers & Suppliers Directory with Detail & Ledger', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockRepo = _MockPartyRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PartiesPage(type: 'Customers', repository: mockRepo),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify customers in directory
    expect(find.text('Al-Madina Traders'), findsWidgets);
    expect(find.text('Usman General Store'), findsWidgets);
    expect(find.text('CUS-0142'), findsOneWidget);

    // Open Al-Madina Traders detail view
    await tester.tap(find.text('CUS-0142'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Back to Customers Directory'), findsOneWidget);
    expect(find.text('CURRENT RECEIVABLE'), findsOneWidget);
    expect(find.textContaining('Complete Ledger & Statement'), findsOneWidget);
    expect(find.text('SAL-10482'), findsWidgets);

    // Navigate back to directory
    await tester.tap(find.text('Back to Customers Directory'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Al-Madina Traders'), findsWidgets);
  });
}

class _MockPartyRepository extends PartyRepository {
  @override
  Future<List<Party>> getParties({required String type, String? searchQuery, String? statusFilter, String? sortOption}) async {
    return [
      const Party(
        id: 1,
        code: 'CUS-0142',
        type: 'Customer',
        name: 'Al-Madina Traders',
        phone: '+92 300 778 5421',
        openingBalance: 182500.0,
        openingBalanceDate: '2026-10-01',
        createdAt: '2026-10-18',
        updatedAt: '2026-10-18',
        currentBalance: 182500.0,
        balanceDirection: 'Receivable',
      ),
      const Party(
        id: 2,
        code: 'CUS-0098',
        type: 'Customer',
        name: 'Usman General Store',
        phone: '+92 321 550 4418',
        openingBalance: 32000.0,
        openingBalanceDate: '2026-10-01',
        createdAt: '2026-10-18',
        updatedAt: '2026-10-18',
        currentBalance: 68000.0,
        balanceDirection: 'Receivable',
      ),
    ];
  }

  @override
  Future<Party?> getPartyById(int id) async {
    return const Party(
      id: 1,
      code: 'CUS-0142',
      type: 'Customer',
      name: 'Al-Madina Traders',
      phone: '+92 300 778 5421',
      openingBalance: 182500.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18',
      updatedAt: '2026-10-18',
      currentBalance: 182500.0,
      balanceDirection: 'Receivable',
    );
  }

  @override
  Future<List<LedgerEntry>> getPartyLedger(int partyId) async {
    return const [
      LedgerEntry(
        id: 1,
        partyId: 1,
        entryDate: '2026-10-26 11:42:00',
        referenceNo: 'SAL-10482',
        entryType: 'Sale Invoice',
        description: '50 Cartons HGM Pink Salt',
        debit: 48500.0,
        credit: 0.0,
        runningBalance: 182500.0,
        createdAt: '2026-10-26',
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getPartyTransactions(int partyId) async {
    return [
      {
        'transaction_no': 'SAL-10482',
        'transaction_date': '2026-10-26',
        'transaction_type': 'Sale Invoice',
        'amount': 48500.0,
        'paid_amount': 48500.0,
        'outstanding_amount': 0.0,
        'status': 'Paid',
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> getSummaryStats(String type) async {
    return {
      'totalCount': 2,
      'activeCount': 2,
      'totalBalance': 250500.0,
      'openingBalanceSum': 214500.0,
      'overdueCount': 0,
      'overdueAmount': 0.0,
    };
  }
}
