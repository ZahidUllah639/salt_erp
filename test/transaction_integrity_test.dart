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
    tempDir = await Directory.systemTemp.createTemp('salt_txn_test_');
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

  group('ERP Transaction Integrity, Edits, Cancellations, Reversals & Audit Trail', () {
    test('1. Edit Purchase Quantity: verifies stock, supplier balance, and wallet effects', () async {
      final db = await dbService.database;

      // Baseline setup
      final suppliers = await db.query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;
      final products = await repo.getProducts();
      final bagProduct = products.firstWhere((p) => p.code == 'PKG-BAG50');
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      final initialStock = await repo.getProductStock(bagProduct.id);
      final initialSupplierBalance = await repo.getPartyBalance(supplierId);
      final initialWalletBalance = await repo.getWalletBalance(cashWallet.id);

      // Create a purchase: 100 bags @ Rs 20 = Rs 2000, Rs 500 paid
      final purchase = await repo.createPurchase(
        supplierId: supplierId,
        purchaseDate: '2026-10-27 10:00:00',
        items: [
          {'product_id': bagProduct.id, 'quantity': 100.0, 'unit_cost': 20.0}
        ],
        paidAmount: 500.0,
        walletId: cashWallet.id,
        notes: 'Initial purchase of 100 bags',
      );

      expect(await repo.getProductStock(bagProduct.id), equals(initialStock + 100.0));
      // Supplier payable should have increased by net outstanding: 2000 - 500 = 1500
      expect(await repo.getPartyBalance(supplierId), equals(initialSupplierBalance + 1500.0));
      // Wallet should have decreased by 500
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWalletBalance - 500.0));

      // EDIT: Change quantity from 100 to 250 @ Rs 20 = Rs 5000, paidAmount from 500 to 1500
      final updated = await repo.updatePurchase(
        purchaseId: purchase.id,
        items: [
          {'product_id': bagProduct.id, 'quantity': 250.0, 'unit_cost': 20.0}
        ],
        paidAmount: 1500.0,
        walletId: cashWallet.id,
        notes: 'Corrected quantity after delivery tally',
        reason: 'Driver delivered 250 bags instead of 100',
      );

      expect(updated.totalAmount, equals(5000.0));
      expect(updated.paidAmount, equals(1500.0));
      expect(updated.outstandingAmount, equals(3500.0));

      // Stock must reflect the new 250 units (old 100 reversed, 250 added)
      expect(await repo.getProductStock(bagProduct.id), equals(initialStock + 250.0));

      // Supplier balance must reflect net outstanding: initial + 3500
      expect(await repo.getPartyBalance(supplierId), equals(initialSupplierBalance + 3500.0));

      // Wallet balance must reflect Rs 1500 total paid: initial - 1500
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWalletBalance - 1500.0));

      // Audit trail must be recorded
      final logs = await repo.getAuditLogs(entityType: 'Purchase', entityId: purchase.id);
      expect(logs.length, greaterThanOrEqualTo(2));
      expect(logs.first.action, equals('EDIT'));
      expect(logs.first.reason, equals('Driver delivered 250 bags instead of 100'));
    });

    test('2. Edit Sale Quantity: verifies stock, customer balance, and financial effects', () async {
      final customers = await (await dbService.database).query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;
      final products = await repo.getProducts();
      final saltProduct = products.firstWhere((p) => p.code == 'FG-080024');
      final wallets = await repo.getWallets();
      final easyPaisa = wallets.firstWhere((w) => w.name == 'EasyPaisa');

      final initialStock = await repo.getProductStock(saltProduct.id);
      final initialCustomerBalance = await repo.getPartyBalance(customerId);
      final initialWalletBalance = await repo.getWalletBalance(easyPaisa.id);

      // Create a sale: 50 packets @ Rs 80 = Rs 4000, Rs 1000 collected
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-27 11:00:00',
        items: [
          {'product_id': saltProduct.id, 'quantity': 50.0, 'unit_price': 80.0}
        ],
        paidAmount: 1000.0,
        walletId: easyPaisa.id,
        notes: 'Wholesale order',
      );

      // Stock decreased by 50
      expect(await repo.getProductStock(saltProduct.id), equals(initialStock - 50.0));
      // Customer receivable increased by net outstanding: 4000 - 1000 = 3000
      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance + 3000.0));
      // Wallet increased by 1000
      expect(await repo.getWalletBalance(easyPaisa.id), equals(initialWalletBalance + 1000.0));

      // EDIT: Change quantity from 50 to 80 @ Rs 80 = Rs 6400, paidAmount from 1000 to 2400
      final updatedSale = await repo.updateSale(
        saleId: sale.id,
        items: [
          {'product_id': saltProduct.id, 'quantity': 80.0, 'unit_price': 80.0}
        ],
        paidAmount: 2400.0,
        walletId: easyPaisa.id,
        notes: 'Customer added 30 more packets',
        reason: 'Customer expanded shop order before dispatch',
      );

      expect(updatedSale.totalAmount, equals(6400.0));
      expect(updatedSale.paidAmount, equals(2400.0));
      expect(updatedSale.outstandingAmount, equals(4000.0));

      // Stock must be reduced by 80 from initial
      expect(await repo.getProductStock(saltProduct.id), equals(initialStock - 80.0));
      // Customer balance should be initial + 4000
      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance + 4000.0));
      // Wallet balance should be initial + 2400
      expect(await repo.getWalletBalance(easyPaisa.id), equals(initialWalletBalance + 2400.0));

      final logs = await repo.getAuditLogs(entityType: 'Sale', entityId: sale.id);
      expect(logs.first.action, equals('EDIT'));
      expect(logs.first.reason, contains('Customer expanded shop order'));
    });

    test('3. Edit Supplier Payment: verifies supplier ledger and payment wallet', () async {
      final suppliers = await (await dbService.database).query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;
      final wallets = await repo.getWallets();
      final ublBank = wallets.firstWhere((w) => w.name == 'UBL Bank');

      final initialSupplierBalance = await repo.getPartyBalance(supplierId);
      final initialWalletBalance = await repo.getWalletBalance(ublBank.id);

      // Create payment of Rs 10,000
      final payRecord = await repo.createDailyRecord(
        recordType: 'Supplier Payment',
        recordDate: '2026-10-27 12:00:00',
        category: 'Supplier payment',
        description: 'Payment towards monthly supply',
        partyId: supplierId,
        sourceWalletId: ublBank.id,
        amount: 10000.0,
      );

      // Supplier payable decreased by 10,000
      expect(await repo.getPartyBalance(supplierId), equals(initialSupplierBalance - 10000.0));
      // Wallet decreased by 10,000
      expect(await repo.getWalletBalance(ublBank.id), equals(initialWalletBalance - 10000.0));

      // EDIT: Change amount to Rs 18,000
      await repo.updateDailyRecord(
        recordId: payRecord.id,
        newAmount: 18000.0,
        reason: 'Cheque cleared for Rs 18,000 instead of Rs 10,000',
      );

      // Supplier payable decreased by 18,000 total from initial
      expect(await repo.getPartyBalance(supplierId), equals(initialSupplierBalance - 18000.0));
      // Wallet decreased by 18,000 total from initial
      expect(await repo.getWalletBalance(ublBank.id), equals(initialWalletBalance - 18000.0));
    });

    test('4. Edit Customer Collection: verifies customer ledger and receiving wallet', () async {
      final customers = await (await dbService.database).query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      final initialCustomerBalance = await repo.getPartyBalance(customerId);
      final initialWalletBalance = await repo.getWalletBalance(cashWallet.id);

      // Create collection of Rs 15,000
      final colRecord = await repo.createDailyRecord(
        recordType: 'Customer Collection',
        recordDate: '2026-10-27 13:00:00',
        category: 'Customer collection',
        description: 'Recovery from market visit',
        partyId: customerId,
        destinationWalletId: cashWallet.id,
        amount: 15000.0,
      );

      // Receivable decreased by 15,000
      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance - 15000.0));
      // Wallet increased by 15,000
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWalletBalance + 15000.0));

      // EDIT: Change amount to Rs 22,000
      await repo.updateDailyRecord(
        recordId: colRecord.id,
        newAmount: 22000.0,
        reason: 'Additional recovery received in evening',
      );

      expect(await repo.getPartyBalance(customerId), equals(initialCustomerBalance - 22000.0));
      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWalletBalance + 22000.0));
    });

    test('5. Edit Expense Amount: verifies wallet and expense report consistency', () async {
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      final initialWallet = await repo.getWalletBalance(cashWallet.id);
      final initialExpenses = await repo.getExpenseTotal();

      final expRecord = await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2026-10-27 14:00:00',
        category: 'Generator Fuel',
        description: 'Diesel for plant generator',
        sourceWalletId: cashWallet.id,
        amount: 6000.0,
      );

      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWallet - 6000.0));
      expect(await repo.getExpenseTotal(), equals(initialExpenses + 6000.0));

      // EDIT: Correct fuel receipt amount to Rs 8,500
      await repo.updateDailyRecord(
        recordId: expRecord.id,
        newAmount: 8500.0,
        reason: 'Final petrol pump receipt reconciled',
      );

      expect(await repo.getWalletBalance(cashWallet.id), equals(initialWallet - 8500.0));
      expect(await repo.getExpenseTotal(), equals(initialExpenses + 8500.0));
    });

    test('6. Edit Production Record: verifies consumption, finished goods, and costing', () async {
      final products = await repo.getProducts();
      final finishedProduct = products.firstWhere((p) => p.code == 'FG-080024');
      final rawSalt = products.firstWhere((p) => p.code == 'RAW-PINK');
      final packaging = products.firstWhere((p) => p.code == 'PKG-00800');

      final initialFGStock = await repo.getProductStock(finishedProduct.id);
      final initialRawStock = await repo.getProductStock(rawSalt.id);
      final initialPkgStock = await repo.getProductStock(packaging.id);

      // Create Batch: 500 packets output, consuming 4000kg salt and 500 packets packaging
      final batch = await repo.createProductionBatch(
        finishedProductId: finishedProduct.id,
        batchDate: '2026-10-27',
        shift: 'Morning',
        reportedQty: 500.0,
        verifiedQty: 500.0,
        consumedItems: [
          {'product_id': rawSalt.id, 'item_type': 'Raw Material', 'quantity_consumed': 4000.0, 'unit_cost': 5.10},
          {'product_id': packaging.id, 'item_type': 'Packaging', 'quantity_consumed': 500.0, 'unit_cost': 2.00},
        ],
        allocationLaborCost: 2000.0,
        allocationPowerCost: 1500.0,
      );

      // Raw cost = 4000 * 5.1 = 20400, Pkg = 1000, Labor = 2000, Power = 1500 => Total = 24900, Unit = 49.8
      expect(batch.totalCost, equals(24900.0));
      expect(batch.unitCost, equals(49.80));

      expect(await repo.getProductStock(finishedProduct.id), equals(initialFGStock + 500.0));
      expect(await repo.getProductStock(rawSalt.id), equals(initialRawStock - 4000.0));
      expect(await repo.getProductStock(packaging.id), equals(initialPkgStock - 500.0));

      // EDIT: Correct verified output to 600, raw salt consumed to 4800, packaging to 600
      final updatedBatch = await repo.updateProductionBatch(
        batchId: batch.id,
        newReportedQty: 600.0,
        newVerifiedQty: 600.0,
        newConsumedItems: [
          {'product_id': rawSalt.id, 'item_type': 'Raw Material', 'quantity_consumed': 4800.0, 'unit_cost': 5.10},
          {'product_id': packaging.id, 'item_type': 'Packaging', 'quantity_consumed': 600.0, 'unit_cost': 2.00},
        ],
        allocationLaborCost: 2400.0,
        allocationPowerCost: 1800.0,
        reason: 'End-of-shift recount and supervisor audit',
      );

      // Raw cost = 4800 * 5.1 = 24480, Pkg = 1200, Labor = 2400, Power = 1800 => Total = 29880, Unit = 49.8
      expect(updatedBatch.totalCost, equals(29880.0));
      expect(updatedBatch.unitCost, equals(49.80));

      expect(await repo.getProductStock(finishedProduct.id), equals(initialFGStock + 600.0));
      expect(await repo.getProductStock(rawSalt.id), equals(initialRawStock - 4800.0));
      expect(await repo.getProductStock(packaging.id), equals(initialPkgStock - 600.0));
    });

    test('7. Cancellation & Reversal: preserves audit trail and restores all dependent effects', () async {
      final customers = await (await dbService.database).query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;
      final products = await repo.getProducts();
      final saltProduct = products.firstWhere((p) => p.code == 'FG-080024');
      final wallets = await repo.getWallets();
      final ublBank = wallets.firstWhere((w) => w.name == 'UBL Bank');

      final initialStock = await repo.getProductStock(saltProduct.id);
      final initialBalance = await repo.getPartyBalance(customerId);
      final initialWallet = await repo.getWalletBalance(ublBank.id);

      // Create a sale of 100 units @ Rs 80 = Rs 8000, paid Rs 3000
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-27 15:00:00',
        items: [
          {'product_id': saltProduct.id, 'quantity': 100.0, 'unit_price': 80.0}
        ],
        paidAmount: 3000.0,
        walletId: ublBank.id,
      );

      expect(await repo.getProductStock(saltProduct.id), equals(initialStock - 100.0));
      expect(await repo.getPartyBalance(customerId), equals(initialBalance + 5000.0));
      expect(await repo.getWalletBalance(ublBank.id), equals(initialWallet + 3000.0));

      // CANCEL the sale
      await repo.cancelSale(
        saleId: sale.id,
        reason: 'Customer cancelled order due to truck breakdown',
      );

      // All effects must be restored to exact baseline!
      expect(await repo.getProductStock(saltProduct.id), equals(initialStock));
      expect(await repo.getPartyBalance(customerId), equals(initialBalance));
      expect(await repo.getWalletBalance(ublBank.id), equals(initialWallet));

      // The sale record must still exist with status 'Cancelled'
      final cancelledSaleList = await repo.getSales(status: 'Cancelled');
      expect(cancelledSaleList.any((s) => s.id == sale.id), isTrue);

      // Audit trail must be intact
      final logs = await repo.getAuditLogs(entityType: 'Sale', entityId: sale.id);
      expect(logs.any((l) => l.action == 'CANCEL'), isTrue);
    });

    test('8. Multi-Step Database Error: rolls back entire transaction atomically', () async {
      final db = await dbService.database;
      final suppliers = await db.query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;
      final products = await repo.getProducts();
      final product = products.first;

      final initialStock = await repo.getProductStock(product.id);
      final initialBalance = await repo.getPartyBalance(supplierId);

      // Attempt multi-step update inside transaction that fails on step 2
      try {
        await db.transaction((txn) async {
          // Step 1: Add stock movement
          await txn.insert('stock_movements', {
            'product_id': product.id,
            'movement_date': '2026-10-27',
            'reference_no': 'FAIL-TEST',
            'movement_type': 'Purchase',
            'quantity': 999.0,
            'unit_cost': 10.0,
            'total_cost': 9990.0,
            'balance_after': 999.0,
            'is_cancelled': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Step 2: Trigger foreign key violation / intentional database error
          await txn.insert('party_ledger_entries', {
            'party_id': 999999, // Non-existent foreign key!
            'entry_date': '2026-10-27',
            'reference_no': 'FAIL-TEST',
            'entry_type': 'Purchase Invoice',
            'description': 'This must fail',
            'debit': 0.0,
            'credit': 9990.0,
            'running_balance': 0.0,
            'is_opening_balance': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        });
        fail('Should have thrown database exception');
      } catch (e) {
        expect(e, isNotNull);
      }

      // Verify that Step 1 was rolled back completely
      expect(await repo.getProductStock(product.id), equals(initialStock));
      expect(await repo.getPartyBalance(supplierId), equals(initialBalance));
      final failMovements = await db.query('stock_movements', where: 'reference_no = ?', whereArgs: ['FAIL-TEST']);
      expect(failMovements, isEmpty);
    });

    test('9. Duplicate Submission Prevention: rejects duplicate reference posting', () async {
      final suppliers = await (await dbService.database).query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;
      final products = await repo.getProducts();

      // First purchase succeeds
      final p1 = await repo.createPurchase(
        supplierId: supplierId,
        purchaseDate: '2026-10-27',
        items: [
          {'product_id': products.first.id, 'quantity': 10.0, 'unit_cost': 5.0}
        ],
      );

      // Attempting to manually insert with the identical unique purchase_no must throw SQLite constraint error
      final db = await dbService.database;
      expect(
        () async => await db.insert('purchases', {
          'purchase_no': p1.purchaseNo,
          'supplier_id': supplierId,
          'purchase_date': '2026-10-27',
          'total_amount': 50.0,
          'paid_amount': 0.0,
          'outstanding_amount': 50.0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('10. Safe Deletion vs Blocked Destruction: protects historical financial records', () async {
      final sales = await repo.getSales();
      final postedSale = sales.first;

      // Attempting hard delete on a posted sale must throw TransactionIntegrityException
      expect(
        () async => await repo.deleteSale(postedSale.id),
        throwsA(isA<TransactionIntegrityException>()),
      );

      // Verify record still exists
      final checkSale = await repo.getSales();
      expect(checkSale.any((s) => s.id == postedSale.id), isTrue);
    });

    test('11. Independent Mathematical Totals Verification before and after', () async {
      final db = await dbService.database;

      // Authoritative Wallet Reconciliation: Sum(IN) - Sum(OUT) == wallet.balance for all wallets
      final wallets = await repo.getWallets();
      for (final w in wallets) {
        final entries = await db.query(
          'wallet_ledger_entries',
          where: 'wallet_id = ? AND is_cancelled = 0',
          whereArgs: [w.id],
        );

        double expectedBalance = 0.0;
        for (final e in entries) {
          final amt = (e['amount'] as num).toDouble();
          if (e['direction'] == 'IN') {
            expectedBalance += amt;
          } else {
            expectedBalance -= amt;
          }
        }
        final actualBalance = await repo.getWalletBalance(w.id);
        expect(actualBalance, closeTo(expectedBalance, 0.01),
            reason: 'Wallet "${w.name}" balance must match the mathematical sum of its active ledger entries');
      }

      // Authoritative Stock Reconciliation: Sum(stock_movements.quantity) == product.current_stock
      final products = await repo.getProducts();
      for (final p in products) {
        final movements = await db.query(
          'stock_movements',
          where: 'product_id = ? AND is_cancelled = 0',
          whereArgs: [p.id],
        );

        double expectedStock = 0.0;
        for (final m in movements) {
          expectedStock += (m['quantity'] as num).toDouble();
        }
        final actualStock = await repo.getProductStock(p.id);
        expect(actualStock, closeTo(expectedStock, 0.01),
            reason: 'Product "${p.name}" stock must match the mathematical sum of its active inventory movements');
      }
    });
  });
}
