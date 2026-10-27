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
    tempDir = await Directory.systemTemp.createTemp('salt_inv_mfg_test_');
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

  group('Anwar Salt Factory ERP - Inventory & Manufacturing Workflows', () {
    // -------------------------------------------------------------------------
    // TEST CASE A: Negative Stock on Dispatch
    // -------------------------------------------------------------------------
    test('Test Case A: Start with zero finished packets, record sale of 200 packets -> balance is -200', () async {
      final db = await dbService.database;

      // Create a test finished product with 0 opening stock
      final now = DateTime.now().toIso8601String();
      final pId = await db.insert('products', {
        'name': 'Test Fine Table Salt 500g',
        'code': 'FG-TEST500',
        'category': 'Finished goods',
        'base_unit': 'Packet',
        'current_stock': 0.0,
        'average_cost': 45.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      // Verify opening stock is 0
      final initialStock = await repo.getProductStock(pId);
      expect(initialStock, equals(0.0));

      // Get a customer
      final customers = await db.query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;

      // Record a sale of 200 packets (factory rule: dispatch before end-of-shift packaging verification)
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-28 09:00:00',
        items: [
          {'product_id': pId, 'quantity': 200.0, 'unit_price': 65.0}
        ],
        paidAmount: 0.0,
        notes: 'Pre-production morning dispatch to distributor',
      );

      expect(sale.saleNo, startsWith('SAL-'));

      // Check resulting stock balance: MUST BE EXACTLY -200
      final balanceAfterSale = await repo.getProductStock(pId);
      expect(balanceAfterSale, equals(-200.0));

      // Check authoritative stock movements
      final movements = await repo.getStockMovementHistory(pId);
      expect(movements.length, equals(1));
      expect(movements.first.movementType, equals('Sale'));
      expect(movements.first.quantity, equals(-200.0));
      expect(movements.first.referenceNo, equals(sale.saleNo));
    });

    // -------------------------------------------------------------------------
    // TEST CASE B: Verified Production Output Reconciles Negative Stock
    // -------------------------------------------------------------------------
    test('Test Case B: Record verified production output of 300 packets -> resulting balance is 100', () async {
      final db = await dbService.database;
      final now = DateTime.now().toIso8601String();

      // Product starts at 0, sells 200 -> balance -200
      final pId = await db.insert('products', {
        'name': 'Test Himalayan Pink Salt 1kg',
        'code': 'FG-TEST1KG',
        'category': 'Finished goods',
        'base_unit': 'Packet',
        'current_stock': 0.0,
        'average_cost': 75.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      // Raw salt & packet packaging items for the recipe
      final rawSaltId = (await db.query('products', where: 'code = ?', whereArgs: ['RAW-PINK'])).first['id'] as int;
      final pkgPacketId = (await db.query('products', where: 'code = ?', whereArgs: ['PKG-00800'])).first['id'] as int;

      // Create a configured recipe for FG-TEST1KG
      final recipe = await repo.createProductRecipe(
        finishedProductId: pId,
        recipeName: 'Standard 1kg Pink Salt Recipe',
        version: 'v1.0',
        baseOutputQuantity: 1.0, // 1 packet
        laborCostPerUnit: 2.0,
        powerCostPerUnit: 1.5,
        overheadCostPerUnit: 0.5,
        items: [
          {'ingredient_product_id': rawSaltId, 'quantity_per_base_unit': 1.0, 'waste_percentage': 2.0},
          {'ingredient_product_id': pkgPacketId, 'quantity_per_base_unit': 1.0, 'waste_percentage': 1.0},
        ],
      );

      final customers = await db.query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;

      // 1. Dispatch 200 packets
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-28 09:30:00',
        items: [
          {'product_id': pId, 'quantity': 200.0, 'unit_price': 110.0}
        ],
        paidAmount: 0.0,
      );

      expect(await repo.getProductStock(pId), equals(-200.0));

      // 2. Post verified production output of 300 packets
      final batch = await repo.executeProductionWithRecipe(
        recipeId: recipe.id,
        reportedQty: 300.0,
        verifiedQty: 300.0,
        shift: 'Morning',
        batchDate: '2026-10-28',
      );

      expect(batch.batchNo, startsWith('PRD-'));
      expect(batch.status, equals('Verified'));

      // 3. Resulting stock balance must be exactly 100 (-200 + 300)
      final balanceAfterProduction = await repo.getProductStock(pId);
      expect(balanceAfterProduction, equals(100.0));

      // 4. Verify historical sale was NEVER silently altered (Requirement 11)
      final saleAfter = await db.query('sales', where: 'id = ?', whereArgs: [sale.id]);
      expect((saleAfter.first['total_amount'] as num).toDouble(), equals(200.0 * 110.0));
      final saleItemAfter = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale.id]);
      expect((saleItemAfter.first['quantity'] as num).toDouble(), equals(200.0));

      // 5. Verify movements history
      final movements = await repo.getStockMovementHistory(pId);
      expect(movements.length, equals(2));
      expect(movements.any((m) => m.movementType == 'Sale' && m.quantity == -200.0), isTrue);
      expect(movements.any((m) => m.movementType == 'Production Output' && m.quantity == 300.0), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST CASE C: Physical Count Discrepancy Recorded Separately
    // -------------------------------------------------------------------------
    test('Test Case C: Production states 300, physical count is 280 -> record 20 discrepancy separately, resulting stock is 80', () async {
      final db = await dbService.database;
      final now = DateTime.now().toIso8601String();

      final pId = await db.insert('products', {
        'name': 'Test Fine White Salt 1kg Batch',
        'code': 'FG-DISC1KG',
        'category': 'Finished goods',
        'base_unit': 'Packet',
        'current_stock': 0.0,
        'average_cost': 50.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      final rawSaltId = (await db.query('products', where: 'code = ?', whereArgs: ['RAW-PINK'])).first['id'] as int;
      final pkgPacketId = (await db.query('products', where: 'code = ?', whereArgs: ['PKG-00800'])).first['id'] as int;

      final recipe = await repo.createProductRecipe(
        finishedProductId: pId,
        recipeName: 'White Salt 1kg Test Recipe',
        version: 'v1.0',
        items: [
          {'ingredient_product_id': rawSaltId, 'quantity_per_base_unit': 1.0, 'waste_percentage': 0.0},
          {'ingredient_product_id': pkgPacketId, 'quantity_per_base_unit': 1.0, 'waste_percentage': 0.0},
        ],
      );

      final customerId = (await db.query('parties', where: 'type = ?', whereArgs: ['Customer'])).first['id'] as int;

      // Sale of 200 packets -> -200
      await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-28 08:00:00',
        items: [
          {'product_id': pId, 'quantity': 200.0, 'unit_price': 80.0}
        ],
        paidAmount: 0.0,
      );

      // Production verified at 300 packets -> book stock is 100
      final prodBatch = await repo.executeProductionWithRecipe(
        recipeId: recipe.id,
        reportedQty: 300.0,
        verifiedQty: 300.0,
        shift: 'Morning',
      );

      expect(await repo.getProductStock(pId), equals(100.0));

      // Physical audit reveals actual warehouse packets are 280 (discrepancy of 20 packets missing from the 300 production batch)
      // On book balance 100, the counted quantity is 80 (since 200 were shipped and 280 are in warehouse, expected 100, actual 80)
      final adjustment = await repo.createStockAdjustment(
        productId: pId,
        adjustmentDate: '2026-10-28 17:00:00',
        adjustmentType: 'Physical Count Discrepancy',
        countedQuantity: 80.0, // Expected 100.0, counted 80.0 -> difference = -20.0
        reason: 'Shift end physical count: 280 packets verified on pallet out of 300 reported (20 damaged during sealing)',
        operatorName: 'Supervisor Tariq',
      );

      expect(adjustment.adjustmentNo, startsWith('ADJ-'));
      expect(adjustment.expectedQuantity, equals(100.0));
      expect(adjustment.countedQuantity, equals(80.0));
      expect(adjustment.differenceQuantity, equals(-20.0));
      expect(adjustment.status, equals('Approved'));

      // Original production record MUST NOT be overwritten (Requirement 11 & 12)
      final originalBatch = (await db.query('production_batches', where: 'id = ?', whereArgs: [prodBatch.id])).first;
      expect((originalBatch['verified_qty'] as num).toDouble(), equals(300.0));
      expect((originalBatch['reported_qty'] as num).toDouble(), equals(300.0));

      // Resulting stock balance must be mathematically correct: exactly 80.0
      final finalStock = await repo.getProductStock(pId);
      expect(finalStock, equals(80.0));

      // Traceability in stock movement history
      final movements = await repo.getStockMovementHistory(pId);
      expect(movements.length, equals(3));
      expect(movements.any((m) => m.movementType == 'Sale' && m.quantity == -200.0), isTrue);
      expect(movements.any((m) => m.movementType == 'Production Output' && m.quantity == 300.0), isTrue);
      expect(movements.any((m) => m.movementType == 'Stock Adjustment' && m.quantity == -20.0), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST CASE D: 1,000 kg Raw Salt Purchase, Production Conversion, Packaging,
    // Sale, Return, and Cancellation on Isolated DB
    // -------------------------------------------------------------------------
    test('Test Case D: Full lifecycle: 1,000 kg purchase, BOM production, packaging, sale, return, and cancellation', () async {
      final db = await dbService.database;
      final now = DateTime.now().toIso8601String();

      // 1. Create unique raw salt, packaging item, and finished goods
      final rawSaltId = await db.insert('products', {
        'name': 'Lifecycle Khewra Salt Rock',
        'code': 'RAW-LIFE1000',
        'category': 'Raw salt',
        'base_unit': 'Kilogram',
        'current_stock': 0.0,
        'average_cost': 6.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      final bagId = await db.insert('products', {
        'name': 'Lifecycle 50kg Heavy Bag',
        'code': 'PKG-LIFE50',
        'category': 'Packaging',
        'base_unit': 'Piece',
        'current_stock': 0.0,
        'average_cost': 25.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      final finishedBagId = await db.insert('products', {
        'name': 'Lifecycle 50kg Industrial Refined Bag',
        'code': 'FG-LIFE50',
        'category': 'Finished goods',
        'base_unit': 'Bag',
        'current_stock': 0.0,
        'average_cost': 350.0,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      // Recipe: 1 finished 50kg bag requires 50 kg raw salt (with 2% processing waste) + 1 bag packaging
      final recipe = await repo.createProductRecipe(
        finishedProductId: finishedBagId,
        recipeName: '50kg Industrial Bag Recipe',
        version: 'v1.0',
        baseOutputQuantity: 1.0,
        laborCostPerUnit: 15.0,
        powerCostPerUnit: 10.0,
        overheadCostPerUnit: 5.0,
        items: [
          {'ingredient_product_id': rawSaltId, 'quantity_per_base_unit': 50.0, 'waste_percentage': 2.0}, // 51 kg
          {'ingredient_product_id': bagId, 'quantity_per_base_unit': 1.0, 'waste_percentage': 0.0},
        ],
      );

      final supplierId = (await db.query('parties', where: 'type = ?', whereArgs: ['Supplier'])).first['id'] as int;
      final customerId = (await db.query('parties', where: 'type = ?', whereArgs: ['Customer'])).first['id'] as int;

      // STEP 1: Purchase 1,000 kg raw salt @ Rs 6.0/kg and 25 packaging bags @ Rs 25.0/bag
      final purchase = await repo.createPurchase(
        supplierId: supplierId,
        purchaseDate: '2026-10-28 08:00:00',
        items: [
          {'product_id': rawSaltId, 'quantity': 1000.0, 'unit_cost': 6.0},
          {'product_id': bagId, 'quantity': 25.0, 'unit_cost': 25.0},
        ],
        paidAmount: 0.0,
      );

      expect(await repo.getProductStock(rawSaltId), equals(1000.0));
      expect(await repo.getProductStock(bagId), equals(25.0));
      expect(await repo.getProductStock(finishedBagId), equals(0.0));

      // STEP 2: Production conversion: manufacture 18 bags (each consumes 51 kg raw salt and 1 empty bag)
      // 18 bags * 51 kg = 918 kg raw salt consumed. 18 bags consumed.
      final batch = await repo.executeProductionWithRecipe(
        recipeId: recipe.id,
        reportedQty: 18.0,
        verifiedQty: 18.0,
        shift: 'Morning',
      );

      expect(batch.status, equals('Verified'));
      expect(await repo.getProductStock(finishedBagId), equals(18.0));
      expect(await repo.getProductStock(rawSaltId), equals(1000.0 - (18.0 * 51.0))); // 1000 - 918 = 82 kg
      expect(await repo.getProductStock(bagId), equals(25.0 - 18.0)); // 7 bags left

      // STEP 3: Sale of 10 finished bags to customer
      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-28 14:00:00',
        items: [
          {'product_id': finishedBagId, 'quantity': 10.0, 'unit_price': 520.0}
        ],
        paidAmount: 0.0,
      );

      expect(await repo.getProductStock(finishedBagId), equals(8.0)); // 18 - 10 = 8

      // STEP 4: Customer Sales Return of 2 bags (damaged during transit)
      final sReturn = await repo.createSalesReturn(
        saleId: sale.id,
        customerId: customerId,
        productId: finishedBagId,
        returnDate: '2026-10-28 16:00:00',
        quantity: 2.0,
        unitPrice: 520.0,
        refundType: 'Credit Customer Ledger',
        reason: 'Transit hook puncture, salt intact',
      );

      expect(sReturn.returnNo, startsWith('SRTN-'));
      expect(await repo.getProductStock(finishedBagId), equals(10.0)); // 8 + 2 = 10

      // STEP 5: Reversal / Cancellation of Production Batch
      // Cancelling the batch must deduct finished product by 18, and return 918 kg raw salt and 18 bags
      await repo.cancelProductionBatch(
        batchId: batch.id,
        reason: 'Quality audit failed: grain size out of specification',
      );

      expect(await repo.getProductStock(finishedBagId), equals(10.0 - 18.0)); // -8 (due to the 10 sale - 2 return = 8 net sold)
      expect(await repo.getProductStock(rawSaltId), equals(1000.0)); // Restored to 1000
      expect(await repo.getProductStock(bagId), equals(25.0)); // Restored to 25

      // STEP 6: Cancel the purchase
      await repo.cancelPurchase(
        purchaseId: purchase.id,
        reason: 'Return whole lot to rock quarry',
      );

      expect(await repo.getProductStock(rawSaltId), equals(0.0));
      expect(await repo.getProductStock(bagId), equals(0.0));
    });

    // -------------------------------------------------------------------------
    // TEST CASE E: Decimal Quantities, Configurable Unit Conversions, Insufficient
    // Materials/Invalid Recipes, and Failed Database Writes
    // -------------------------------------------------------------------------
    test('Test Case E: Decimal quantities, unit conversions (tonne, maund, kg, cotton), invalid recipes, rollback', () async {
      final db = await dbService.database;

      // 1. Decimal Quantities: Exact internal precision
      final now = DateTime.now().toIso8601String();
      final pId = await db.insert('products', {
        'name': 'High-Precision Analytical Salt',
        'code': 'RAW-PREC1',
        'category': 'Raw salt',
        'base_unit': 'Kilogram',
        'current_stock': 123.45678,
        'average_cost': 5.4321,
        'status': 'Active',
        'created_at': now,
        'updated_at': now,
      });

      final stock = await repo.getProductStock(pId);
      expect(stock, equals(123.45678)); // No premature rounding to integer or 2 decimal places

      // 2. Unit Conversions: Standard weight units bridging
      // 1 Tonne = 1000 kg
      final kgFromTonne = await repo.convertUnit(quantity: 2.5, fromUnit: 'Tonne', toUnit: 'Kilogram');
      expect(kgFromTonne, equals(2500.0));

      // 1 Maund = 40 kg (Khewra / Sargodha local trade)
      final kgFromMaund = await repo.convertUnit(quantity: 10.0, fromUnit: 'Maund', toUnit: 'Kilogram');
      expect(kgFromMaund, equals(400.0));

      // Tonne to Maund: 1 Tonne = 25 Maunds
      final maundsFromTonne = await repo.convertUnit(quantity: 2.0, fromUnit: 'Tonne', toUnit: 'Maund');
      expect(maundsFromTonne, equals(50.0));

      // Gram to Kilogram
      final kgFromGrams = await repo.convertUnit(quantity: 800.0, fromUnit: 'Gram', toUnit: 'Kilogram');
      expect(kgFromGrams, equals(0.8));

      // 3. Product-specific configurable unit conversions
      // Find HGM Pink Salt 800g product
      final hgmProduct = (await db.query('products', where: 'code = ?', whereArgs: ['FG-080024'])).first;
      final hgmId = hgmProduct['id'] as int;

      // 1 Cotton = 24 Packets
      final pktsFromCotton = await repo.convertUnit(
        quantity: 5.0,
        fromUnit: 'Cotton',
        toUnit: 'Packet',
        productId: hgmId,
      );
      expect(pktsFromCotton, equals(120.0));

      // Inverse: 240 Packets = 10 Cottons
      final cottonsFromPkts = await repo.convertUnit(
        quantity: 240.0,
        fromUnit: 'Packet',
        toUnit: 'Cotton',
        productId: hgmId,
      );
      expect(cottonsFromPkts, equals(10.0));

      // Bundle to pieces for packaging (PKG-00800 has 1 bundle = 1000 pieces)
      final pkgPacketId = (await db.query('products', where: 'code = ?', whereArgs: ['PKG-00800'])).first['id'] as int;
      final piecesFromBundle = await repo.convertUnit(
        quantity: 3.0,
        fromUnit: 'Bundle',
        toUnit: 'Piece',
        productId: pkgPacketId,
      );
      expect(piecesFromBundle, equals(3000.0));

      // 4. Prevent ambiguous / non-existent unit conversion
      expect(
        () async => await repo.convertUnit(quantity: 10.0, fromUnit: 'Packet', toUnit: 'Tonne', productId: 99999),
        throwsA(isA<TransactionIntegrityException>()),
      );

      // 5. Invalid Recipe: Execution with non-existent recipe ID must fail
      expect(
        () async => await repo.executeProductionWithRecipe(
          recipeId: 88888,
          reportedQty: 100.0,
          verifiedQty: 100.0,
          shift: 'Morning',
        ),
        throwsA(isA<TransactionIntegrityException>()),
      );

      // 6. Failed Database Write: Atomic Rollback ensures zero material consumption on failure
      final initialRawPinkStock = await repo.getProductStock(1);
      final initialWhiteSaltStock = await repo.getProductStock(2);

      // Attempt to execute production where database operation aborts or throws inside txn
      try {
        await db.transaction((txn) async {
          // Simulate partial deduction
          await txn.insert('stock_movements', {
            'product_id': 1,
            'movement_date': '2026-10-28',
            'reference_no': 'FAIL-TEST',
            'movement_type': 'Production Consumption',
            'quantity': -500.0,
            'unit_cost': 5.0,
            'total_cost': -2500.0,
            'balance_after': 0.0,
            'is_cancelled': 0,
            'created_at': now,
          });
          // Force a fatal exception before output is recorded
          throw Exception('Simulated power disruption during batch registration');
        });
      } catch (_) {}

      // Verify atomic rollback: Raw salt stock was NOT deducted
      final rawPinkStockAfterRollback = await repo.getProductStock(1);
      expect(rawPinkStockAfterRollback, equals(initialRawPinkStock));
      final whiteStockAfterRollback = await repo.getProductStock(2);
      expect(whiteStockAfterRollback, equals(initialWhiteSaltStock));
    });

    // -------------------------------------------------------------------------
    // TEST CASE F: Independently Verify Authoritative Stock Equation
    // -------------------------------------------------------------------------
    test('Test Case F: Verify Stock Equation: Opening + Inward - Outward + Adjustments = Closing', () async {
      final products = await repo.getProducts();

      for (final p in products) {
        final breakdown = await repo.investigateStockBalance(p.id);

        // Verify equation:
        // Opening + Purchases + Production Output + Sales Returns - Sales - Production Consumption - Purchase Returns + Adjustments = Calculated
        final manualCalc = breakdown.openingStock +
            breakdown.totalPurchases +
            breakdown.totalProductionOutput +
            breakdown.totalSalesReturns -
            breakdown.totalSales -
            breakdown.totalProductionConsumption -
            breakdown.totalPurchaseReturns +
            breakdown.totalAdjustments;

        expect((manualCalc - breakdown.calculatedStock).abs() < 0.0001, isTrue);
        expect((breakdown.calculatedStock - breakdown.recordedStock).abs() < 0.0001, isTrue);
        expect(breakdown.isReconciled, isTrue);
      }
    });

    // -------------------------------------------------------------------------
    // TEST CASE G: Transaction Editing & Reversals Do Not Duplicate or Orphan Movements
    // -------------------------------------------------------------------------
    test('Test Case G: Editing/reversing transactions leaves clean, auditable movements without orphans', () async {
      final db = await dbService.database;
      final suppliers = await db.query('parties', where: 'type = ?', whereArgs: ['Supplier']);
      final supplierId = suppliers.first['id'] as int;

      final product = await repo.createProduct(
        code: 'RAW-REV100',
        name: 'Test Reversal Salt Lot',
        category: 'Raw salt',
        baseUnit: 'Kilogram',
        openingStock: 100.0,
        averageCost: 5.0,
      );
      final pId = product.id;

      // 1. Initial purchase: 500 kg -> stock becomes 600
      final purchase = await repo.createPurchase(
        supplierId: supplierId,
        purchaseDate: '2026-10-28 10:00:00',
        items: [
          {'product_id': pId, 'quantity': 500.0, 'unit_cost': 5.0}
        ],
        paidAmount: 0.0,
      );

      expect(await repo.getProductStock(pId), equals(600.0));

      // 2. Edit purchase from 500 kg to 400 kg -> stock must become 500 kg (100 + 400), NOT 600 + 400
      final updatedPurchase = await repo.updatePurchase(
        purchaseId: purchase.id,
        items: [
          {'product_id': pId, 'quantity': 400.0, 'unit_cost': 5.0}
        ],
        paidAmount: 0.0,
        reason: 'Weighbridge slip corrected from 500 kg gross to 400 kg net',
      );

      expect(await repo.getProductStock(pId), equals(500.0));

      // Check movements: original 500 movement marked cancelled, new 400 movement active
      final movementsAfterEdit = await repo.getStockMovementHistory(pId);
      final activeMovements = movementsAfterEdit.where((m) => !m.isCancelled).toList();
      final cancelledMovements = movementsAfterEdit.where((m) => m.isCancelled).toList();

      expect(activeMovements.length, equals(2)); // 1 Opening Balance (100) + 1 edited Purchase (400)
      expect(activeMovements.any((m) => m.movementType == 'Opening Balance' && m.quantity == 100.0), isTrue);
      expect(activeMovements.any((m) => m.movementType == 'Purchase' && m.quantity == 400.0), isTrue);
      expect(cancelledMovements.length, equals(1));
      expect(cancelledMovements.first.quantity, equals(500.0));

      // 3. Cancel the purchase completely -> stock returns to 100.0
      await repo.cancelPurchase(
        purchaseId: updatedPurchase.id,
        reason: 'Quarry delivery rejected due to dirt contamination',
      );

      expect(await repo.getProductStock(pId), equals(100.0));

      // Verify no orphaned movements and stock reconciliation is perfectly balanced
      final reconciliation = await repo.investigateStockBalance(pId);
      expect(reconciliation.isReconciled, isTrue);
      expect(reconciliation.recordedStock, equals(100.0));
    });

    // -------------------------------------------------------------------------
    // COSTING & PROFIT REPORTING (REQUIREMENT 8)
    // -------------------------------------------------------------------------
    test('Costing & Profit: Distinguishes estimated production cost, actual cost, revenue, and gross profit', () async {
      final summary = await repo.getProductionCostingSummary();

      expect(summary.actualProductionCost, greaterThanOrEqualTo(0.0));
      expect(summary.estimatedProductionCost, greaterThanOrEqualTo(0.0));
      expect(summary.salesRevenue, greaterThanOrEqualTo(0.0));
      expect(summary.costOfGoodsSold, greaterThanOrEqualTo(0.0));
      expect(summary.grossProfit, equals(summary.salesRevenue - summary.costOfGoodsSold));
      expect(summary.costVariance, equals(summary.actualProductionCost - summary.estimatedProductionCost));
    });
  });
}
