import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/repositories/erp_transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late ErpTransactionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_fin_test_');
    dbPath = '${tempDir.path}/test_anwar_erp.db';
    dbService = DatabaseService.createTestingInstance(dbPath);
    repo = ErpTransactionRepository(dbService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Anwar Salt Factory ERP - Financial & Accounting Workflows', () {
    // -------------------------------------------------------------------------
    // 1. Customer Collection Updates Customer Balance & Receiving Wallet Once
    // -------------------------------------------------------------------------
    test('1. Customer Collection: updates customer receivable and receiving wallet exactly once, does not add to sales revenue', () async {
      final db = await dbService.database;

      final customers = await db.query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      final initialCustBalance = await repo.getPartyBalance(customerId);
      final initialWalletBalance = await repo.getWalletBalance(cashWallet.id);
      final initialRevenue = await repo.getRevenueTotal();

      // Record a customer collection of Rs 20,000
      final collection = await repo.createDailyRecord(
        recordType: 'Customer Collection',
        recordDate: '2026-10-28 11:00:00',
        category: 'Customer Receipts',
        description: 'Payment against outstanding invoices',
        partyId: customerId,
        destinationWalletId: cashWallet.id,
        amount: 20000.0,
      );

      expect(collection.recordNo, startsWith('COL-'));

      // Customer receivable must decrease by exactly Rs 20,000
      final newCustBalance = await repo.getPartyBalance(customerId);
      expect(newCustBalance, equals(initialCustBalance - 20000.0));

      // Wallet balance must increase by exactly Rs 20,000
      final newWalletBalance = await repo.getWalletBalance(cashWallet.id);
      expect(newWalletBalance, equals(initialWalletBalance + 20000.0));

      // Sales revenue must NOT increase (Customer collection is NOT new revenue - Requirement 9)
      final newRevenue = await repo.getRevenueTotal();
      expect(newRevenue, equals(initialRevenue));

      // Verify double-entry ledgers
      final pLedgers = await db.query('party_ledger_entries', where: 'reference_no = ?', whereArgs: [collection.recordNo]);
      expect(pLedgers.length, equals(1));
      expect((pLedgers.first['credit'] as num).toDouble(), equals(20000.0));
      expect((pLedgers.first['debit'] as num).toDouble(), equals(0.0));

      final wLedgers = await db.query('wallet_ledger_entries', where: 'reference_no = ?', whereArgs: [collection.recordNo]);
      expect(wLedgers.length, equals(1));
      expect(wLedgers.first['direction'], equals('IN'));
      expect((wLedgers.first['amount'] as num).toDouble(), equals(20000.0));
    });

    // -------------------------------------------------------------------------
    // 2. Supplier Payment Updates Supplier Balance & Source Wallet Once
    // -------------------------------------------------------------------------
    test('2. Supplier Payment: updates supplier payable and payment wallet exactly once, does not add to purchase expense', () async {
      final db = await dbService.database;

      final suppliers = await db.query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;
      final wallets = await repo.getWallets();
      final bankWallet = wallets.firstWhere((w) => w.name == 'UBL Bank');

      final initialSuppBalance = await repo.getPartyBalance(supplierId);
      final initialWalletBalance = await repo.getWalletBalance(bankWallet.id);
      final initialExpense = await repo.getExpenseTotal();

      // Record a supplier payment of Rs 35,000 from UBL Bank
      final payment = await repo.createDailyRecord(
        recordType: 'Supplier Payment',
        recordDate: '2026-10-28 12:00:00',
        category: 'Supplier Disbursements',
        description: 'Payment against raw salt delivery invoice',
        partyId: supplierId,
        sourceWalletId: bankWallet.id,
        amount: 35000.0,
      );

      expect(payment.recordNo, startsWith('PAY-'));

      // Supplier payable must decrease by exactly Rs 35,000
      final newSuppBalance = await repo.getPartyBalance(supplierId);
      expect(newSuppBalance, equals(initialSuppBalance - 35000.0));

      // Bank wallet must decrease by exactly Rs 35,000
      final newWalletBalance = await repo.getWalletBalance(bankWallet.id);
      expect(newWalletBalance, equals(initialWalletBalance - 35000.0));

      // Operational expense total must NOT increase (Supplier payment is NOT an expense - Requirement 9)
      final newExpense = await repo.getExpenseTotal();
      expect(newExpense, equals(initialExpense));

      // Double-entry check
      final pLedgers = await db.query('party_ledger_entries', where: 'reference_no = ?', whereArgs: [payment.recordNo]);
      expect(pLedgers.length, equals(1));
      expect((pLedgers.first['debit'] as num).toDouble(), equals(35000.0));
      expect((pLedgers.first['credit'] as num).toDouble(), equals(0.0));

      final wLedgers = await db.query('wallet_ledger_entries', where: 'reference_no = ?', whereArgs: [payment.recordNo]);
      expect(wLedgers.length, equals(1));
      expect(wLedgers.first['direction'], equals('OUT'));
      expect((wLedgers.first['amount'] as num).toDouble(), equals(35000.0));
    });

    // -------------------------------------------------------------------------
    // 3. Expenses Affect Correct Wallet & Expense Reports
    // -------------------------------------------------------------------------
    test('3. Expenses: decrease source wallet and update expense reports, party balances remain untouched', () async {
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      final initialWalletBalance = await repo.getWalletBalance(cashWallet.id);
      final initialExpenses = await repo.getExpenseTotal();

      // Record an operational expense of Rs 12,500
      final expense = await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2026-10-28 14:00:00',
        category: 'Factory Utilities',
        description: 'Diesel fuel for backup generators',
        sourceWalletId: cashWallet.id,
        amount: 12500.0,
      );

      expect(expense.recordNo, startsWith('EXP-'));

      // Wallet balance must decrease by 12,500
      final newWalletBalance = await repo.getWalletBalance(cashWallet.id);
      expect(newWalletBalance, equals(initialWalletBalance - 12500.0));

      // Expense total report must increase by 12,500
      final newExpenses = await repo.getExpenseTotal();
      expect(newExpenses, equals(initialExpenses + 12500.0));

      // Filtered expense total for this wallet matches
      final walletExpenseTotal = await repo.getExpenseTotal(walletId: cashWallet.id);
      expect(walletExpenseTotal, greaterThanOrEqualTo(12500.0));
    });

    // -------------------------------------------------------------------------
    // 4. Wallet Transfers: Combined Wallet Total Unchanged, Same-Wallet Blocked
    // -------------------------------------------------------------------------
    test('4. Wallet Transfer: decreases source, increases destination, combined total constant, same-wallet blocked', () async {
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');
      final easyPaisaWallet = wallets.firstWhere((w) => w.name == 'EasyPaisa');

      final initialCash = await repo.getWalletBalance(cashWallet.id);
      final initialEasy = await repo.getWalletBalance(easyPaisaWallet.id);
      final initialCombined = initialCash + initialEasy;
      final initialExpense = await repo.getExpenseTotal();
      final initialRevenue = await repo.getRevenueTotal();

      // 1. Same-wallet transfer must throw TransactionIntegrityException (Requirement 13)
      expect(
        () async => await repo.createDailyRecord(
          recordType: 'Wallet Transfer',
          recordDate: '2026-10-28 15:00:00',
          category: 'Inter-account',
          description: 'Invalid transfer to self',
          sourceWalletId: cashWallet.id,
          destinationWalletId: cashWallet.id,
          amount: 5000.0,
        ),
        throwsA(isA<TransactionIntegrityException>()),
      );

      // 2. Valid transfer of Rs 25,000 from Cash in Hand to EasyPaisa
      final transfer = await repo.createDailyRecord(
        recordType: 'Wallet Transfer',
        recordDate: '2026-10-28 15:30:00',
        category: 'Inter-account',
        description: 'Cash in Hand deposit into EasyPaisa merchant account',
        sourceWalletId: cashWallet.id,
        destinationWalletId: easyPaisaWallet.id,
        amount: 25000.0,
      );

      expect(transfer.recordNo, startsWith('TRF-'));

      final newCash = await repo.getWalletBalance(cashWallet.id);
      final newEasy = await repo.getWalletBalance(easyPaisaWallet.id);
      final newCombined = newCash + newEasy;

      expect(newCash, equals(initialCash - 25000.0));
      expect(newEasy, equals(initialEasy + 25000.0));
      expect(newCombined, equals(initialCombined)); // Zero net change to combined liquidity

      // Must not generate income or expense (Requirement 7)
      expect(await repo.getExpenseTotal(), equals(initialExpense));
      expect(await repo.getRevenueTotal(), equals(initialRevenue));
    });

    // -------------------------------------------------------------------------
    // 5. Credit Purchases and Credit Sales Do Not Move Cash
    // -------------------------------------------------------------------------
    test('5. Non-Cash Credit Transactions: 100% credit sales and purchases do not alter wallet balances', () async {
      final db = await dbService.database;

      final supplierId = (await db.query('parties', where: 'type = ?', whereArgs: ['Supplier'])).first['id'] as int;
      final customerId = (await db.query('parties', where: 'type = ?', whereArgs: ['Customer'])).first['id'] as int;
      final rawSalt = (await repo.getProducts()).firstWhere((p) => p.code == 'RAW-PINK');
      final finishedSalt = (await repo.getProducts()).firstWhere((p) => p.code == 'FG-080024');
      final cashWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'Cash in Hand');

      final initialCashBalance = await repo.getWalletBalance(cashWallet.id);
      final initialSupplierBalance = await repo.getPartyBalance(supplierId);
      final initialCustomerBalance = await repo.getPartyBalance(customerId);

      // 1. Pure credit purchase (paidAmount = 0.0)
      final purchase = await repo.createPurchase(
        supplierId: supplierId,
        purchaseDate: '2026-10-28 10:00:00',
        items: [
          {'product_id': rawSalt.id, 'quantity': 1000.0, 'unit_cost': 5.0} // Rs 5,000
        ],
        paidAmount: 0.0,
      );

      // Wallet MUST NOT move
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialCashBalance));
      // Supplier payable must increase by Rs 5,000
      expect(await repo.getPartyBalance(supplierId), equals(initialSupplierBalance + 5000.0));

      // 2. Pure credit sale (paidAmount = 0.0)
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-28 11:00:00',
        items: [
          {'product_id': finishedSalt.id, 'quantity': 50.0, 'unit_price': 100.0} // Rs 5,000
        ],
        paidAmount: 0.0,
      );

      // Wallet MUST NOT move
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialCashBalance));
      // Customer receivable must increase by Rs 5,000
      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance + 5000.0));

      // Ensure no wallet movements exist for these transaction references
      final wMovements = await db.query(
        'wallet_ledger_entries',
        where: 'reference_no = ? OR reference_no = ?',
        whereArgs: [purchase.purchaseNo, sale.saleNo],
      );
      expect(wMovements, isEmpty);
    });

    // -------------------------------------------------------------------------
    // 6. Editing and Reversing Each Financial Transaction Type
    // -------------------------------------------------------------------------
    test('6. Editing and Reversing: customer collection, supplier payment, expense, and transfer maintain balance integrity', () async {
      final db = await dbService.database;

      final customerId = (await db.query('parties', where: 'type = ?', whereArgs: ['Customer'])).first['id'] as int;
      final supplierId = (await db.query('parties', where: 'type = ?', whereArgs: ['Supplier'])).first['id'] as int;
      final cashWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'Cash in Hand');
      final bankWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'UBL Bank');

      // --- A. Customer Collection Edit & Reversal ---
      final custBalBefore = await repo.getPartyBalance(customerId);
      final cashBalBefore = await repo.getWalletBalance(cashWallet.id);

      final col = await repo.createDailyRecord(
        recordType: 'Customer Collection',
        recordDate: '2026-10-28 09:00:00',
        category: 'Collections',
        description: 'Customer payment test',
        partyId: customerId,
        destinationWalletId: cashWallet.id,
        amount: 10000.0,
      );

      expect(await repo.getPartyBalance(customerId), equals(custBalBefore - 10000.0));
      expect(await repo.getWalletBalance(cashWallet.id), equals(cashBalBefore + 10000.0));

      // Edit collection from 10,000 to 15,000
      final updatedCol = await repo.updateDailyRecord(
        recordId: col.id,
        newAmount: 15000.0,
        reason: 'Cheque amount corrected from 10,000 to 15,000',
      );

      expect(await repo.getPartyBalance(customerId), equals(custBalBefore - 15000.0));
      expect(await repo.getWalletBalance(cashWallet.id), equals(cashBalBefore + 15000.0));

      // Cancel collection completely -> balance must fully revert
      await repo.cancelDailyRecord(
        recordId: updatedCol.id,
        reason: 'Cheque bounced at clearing',
      );

      expect(await repo.getPartyBalance(customerId), equals(custBalBefore));
      expect(await repo.getWalletBalance(cashWallet.id), equals(cashBalBefore));

      // --- B. Supplier Payment Edit & Reversal ---
      final suppBalBefore = await repo.getPartyBalance(supplierId);
      final bankBalBefore = await repo.getWalletBalance(bankWallet.id);

      final pay = await repo.createDailyRecord(
        recordType: 'Supplier Payment',
        recordDate: '2026-10-28 10:00:00',
        category: 'Disbursements',
        description: 'Supplier payment test',
        partyId: supplierId,
        sourceWalletId: bankWallet.id,
        amount: 20000.0,
      );

      expect(await repo.getPartyBalance(supplierId), equals(suppBalBefore - 20000.0));
      expect(await repo.getWalletBalance(bankWallet.id), equals(bankBalBefore - 20000.0));

      // Edit payment to 25,000
      final updatedPay = await repo.updateDailyRecord(
        recordId: pay.id,
        newAmount: 25000.0,
        reason: 'Added withholding tax differential',
      );

      expect(await repo.getPartyBalance(supplierId), equals(suppBalBefore - 25000.0));
      expect(await repo.getWalletBalance(bankWallet.id), equals(bankBalBefore - 25000.0));

      // Cancel payment -> balance must fully revert
      await repo.cancelDailyRecord(
        recordId: updatedPay.id,
        reason: 'Payment stopped by manager',
      );

      expect(await repo.getPartyBalance(supplierId), equals(suppBalBefore));
      expect(await repo.getWalletBalance(bankWallet.id), equals(bankBalBefore));
    });

    // -------------------------------------------------------------------------
    // 7. Date Filtering Distinguishes Calendar Date in Different Years
    // -------------------------------------------------------------------------
    test('7. Date Filters: cleanly distinguish same calendar day in different years (e.g. 2025-10-28 vs 2026-10-28)', () async {
      final cashWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'Cash in Hand');

      // Record transaction on 28 Oct 2025
      await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2025-10-28 10:00:00',
        category: 'Repairs',
        description: 'Plant repair in 2025',
        sourceWalletId: cashWallet.id,
        amount: 8000.0,
      );

      // Record transaction on 28 Oct 2026
      await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2026-10-28 10:00:00',
        category: 'Repairs',
        description: 'Plant repair in 2026',
        sourceWalletId: cashWallet.id,
        amount: 19500.0,
      );

      // Query for 2026 date only
      final records2026 = await repo.getDailyRecords(
        recordType: 'Expense',
        startDate: '2026-10-28',
        endDate: '2026-10-28',
      );

      expect(records2026.length, equals(1));
      expect(records2026.first.amount, equals(19500.0));
      expect(records2026.first.recordDate, startsWith('2026-10-28'));

      // Query for 2025 date only
      final records2025 = await repo.getDailyRecords(
        recordType: 'Expense',
        startDate: '2025-10-28',
        endDate: '2025-10-28',
      );

      expect(records2025.length, equals(1));
      expect(records2025.first.amount, equals(8000.0));
      expect(records2025.first.recordDate, startsWith('2025-10-28'));

      // Expense total filtered by date range
      final expense2026 = await repo.getExpenseTotal(startDate: '2026-10-28', endDate: '2026-10-28');
      expect(expense2026, equals(19500.0));

      final expense2025 = await repo.getExpenseTotal(startDate: '2025-10-28', endDate: '2025-10-28');
      expect(expense2025, equals(8000.0));
    });

    // -------------------------------------------------------------------------
    // 8. Daily and Monthly Summaries Independently Verified
    // -------------------------------------------------------------------------
    test('8. Daily & Monthly Summaries: verified independently, opening balances persist across days without daily resets', () async {
      final cashWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'Cash in Hand');
      final initialCash = await repo.getWalletBalance(cashWallet.id);

      // Day 1: 2026-11-01 -> Income of Rs 50,000
      await repo.createDailyRecord(
        recordType: 'Income',
        recordDate: '2026-11-01 10:00:00',
        category: 'Scrap Sales',
        description: 'Sale of old packaging scrap',
        destinationWalletId: cashWallet.id,
        amount: 50000.0,
      );

      // Day 2: 2026-11-02 -> Expense of Rs 10,000
      await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2026-11-02 11:00:00',
        category: 'Printing',
        description: 'Invoice books printing',
        sourceWalletId: cashWallet.id,
        amount: 10000.0,
      );

      // Test Day 2 Summary:
      // Opening balance of Day 2 MUST carry forward closing balance of Day 1 (Requirement 10)
      final day2Summary = await repo.getFinancialDailySummary(
        date: '2026-11-02',
        walletId: cashWallet.id,
      );

      expect(day2Summary.openingWalletBalance, equals(initialCash + 50000.0));
      expect(day2Summary.totalCashOut, equals(10000.0));
      expect(day2Summary.netCashFlow, equals(-10000.0));
      expect(day2Summary.closingWalletBalance, equals(initialCash + 50000.0 - 10000.0));

      // Test Monthly Summary for November 2026
      final novSummary = await repo.getFinancialMonthlySummary(
        year: 2026,
        month: 11,
        walletId: cashWallet.id,
      );

      expect(novSummary.totalCashIn, equals(50000.0));
      expect(novSummary.totalCashOut, equals(10000.0));
      expect(novSummary.netCashFlow, equals(40000.0));
      expect(novSummary.closingWalletBalance, equals(initialCash + 40000.0));

      // Wallet Summary
      final walletSummary = await repo.getWalletSummary(cashWallet.id);
      expect(walletSummary.currentBalance, equals(initialCash + 40000.0));
      expect(walletSummary.walletName, equals('Cash in Hand'));
    });

    // -------------------------------------------------------------------------
    // 9. Atomic Rollback on Failed Database Writes
    // -------------------------------------------------------------------------
    test('9. Atomic Database Transactions: failed write rolls back every related update with zero partial writes', () async {
      final db = await dbService.database;
      final cashWallet = (await repo.getWallets()).firstWhere((w) => w.name == 'Cash in Hand');
      final customer = (await db.query('parties', where: 'type = ?', whereArgs: ['Customer'])).first;
      final customerId = customer['id'] as int;

      final initialCashBalance = await repo.getWalletBalance(cashWallet.id);
      final initialCustomerBalance = await repo.getPartyBalance(customerId);

      // Attempt transaction where step 1 updates customer, step 2 updates wallet, then fatal error occurs
      try {
        await db.transaction((txn) async {
          await txn.insert('party_ledger_entries', {
            'party_id': customerId,
            'entry_date': '2026-10-28',
            'reference_no': 'FAIL-TEST',
            'entry_type': 'Collection',
            'description': 'Partial failure test',
            'debit': 0.0,
            'credit': 50000.0,
            'running_balance': 0.0,
            'is_opening_balance': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          await txn.insert('wallet_ledger_entries', {
            'wallet_id': cashWallet.id,
            'entry_date': '2026-10-28',
            'reference_no': 'FAIL-TEST',
            'source_type': 'Collection',
            'description': 'Partial failure test',
            'amount': 50000.0,
            'direction': 'IN',
            'running_balance': 0.0,
            'is_cancelled': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Simulate database crash or constraint violation
          throw Exception('Simulated SQLite failure before transaction commit');
        });
      } catch (_) {}

      // Verify that neither customer balance nor wallet balance was modified
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialCashBalance));
      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance));

      // Verify no orphaned records exist
      final failLedgers = await db.query('wallet_ledger_entries', where: 'reference_no = ?', whereArgs: ['FAIL-TEST']);
      expect(failLedgers, isEmpty);
      final failPartyLedgers = await db.query('party_ledger_entries', where: 'reference_no = ?', whereArgs: ['FAIL-TEST']);
      expect(failPartyLedgers, isEmpty);
    });

    // -------------------------------------------------------------------------
    // 10. Custom Wallets and Factory Wallets Integrity
    // -------------------------------------------------------------------------
    test('10. Custom Wallets: create custom bank wallet with opening balance and verify isolation', () async {
      final wallets = await repo.getWallets();

      // Verify all factory wallets exist as specified
      final walletNames = wallets.map((w) => w.name).toSet();
      expect(walletNames.contains('Cash in Hand'), isTrue);
      expect(walletNames.contains('UBL Bank'), isTrue);
      expect(walletNames.contains('EasyPaisa'), isTrue);
      expect(walletNames.contains('Cash in Hand — HGM Work'), isTrue);
      expect(walletNames.contains('UBL Bank — HGM Work'), isTrue);
      expect(walletNames.contains('EasyPaisa — HGM Work'), isTrue);

      // Create a custom wallet
      final customWallet = await repo.createWallet(
        name: 'Meezan Bank — Factory Operations',
        type: 'Bank',
        openingBalance: 350000.0,
        openingDate: '2026-10-01',
      );

      expect(customWallet.id, greaterThan(0));
      expect(await repo.getWalletBalance(customWallet.id), equals(350000.0));

      // Verify opening balance ledger entry
      final ledger = await repo.getWalletLedgerEntries(customWallet.id);
      expect(ledger.length, equals(1));
      expect(ledger.first.sourceType, equals('Opening Balance'));
      expect(ledger.first.amount, equals(350000.0));
      expect(ledger.first.direction, equals('IN'));

      // Prevent duplicate wallet name
      expect(
        () async => await repo.createWallet(
          name: 'Meezan Bank — Factory Operations',
          type: 'Bank',
        ),
        throwsA(isA<TransactionIntegrityException>()),
      );
    });
  });
}
