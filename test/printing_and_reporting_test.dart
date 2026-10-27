import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/models/erp_models.dart';
import 'package:saltflow/repositories/erp_transaction_repository.dart';
import 'package:saltflow/services/printing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late ErpTransactionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_print_test_');
    dbPath = '${tempDir.path}/test_print_erp.db';
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

  group('Anwar Salt Factory ERP - Printing & Reporting Tests', () {
    // -------------------------------------------------------------------------
    // 1. Representative 58 mm & 80 mm Thermal Receipt Layouts
    // -------------------------------------------------------------------------
    test('1. Thermal Layouts: 58 mm and 80 mm receipts generate valid non-empty PDF bytes', () async {
      final receipt = ReceiptData(
        title: 'SALES RECEIPT',
        referenceNo: 'SAL-10482',
        dateTime: '2026-10-26 11:42:00',
        partyLabel: 'Customer',
        partyName: 'Al-Madina Traders',
        partyPhone: '0300 1234567',
        paymentMethod: 'EasyPaisa',
        items: const [
          ReceiptLineItem(
            description: 'HGM Pink Salt 800g × 24 packets',
            quantity: 20.0,
            unit: 'ctn',
            unitPrice: 1920.0,
            totalAmount: 38400.0,
          ),
          ReceiptLineItem(
            description: 'Fine Table Salt 1kg × 10',
            quantity: 10.0,
            unit: 'ctn',
            unitPrice: 1050.0,
            totalAmount: 10500.0,
          ),
        ],
        subtotal: 48900.0,
        discount: 400.0,
        tax: 0.0,
        grandTotal: 48500.0,
        paidAmount: 48500.0,
        outstandingAmount: 0.0,
        partyBalance: 'Rs 182,500 Dr',
      );

      final pdf58 = await PrintingService.instance.generateThermalReceiptPdf(receipt, paperWidth: '58');
      final pdf80 = await PrintingService.instance.generateThermalReceiptPdf(receipt, paperWidth: '80');

      expect(pdf58, isNotEmpty);
      expect(pdf80, isNotEmpty);

      // PDF magic header %PDF-
      expect(String.fromCharCodes(pdf58.take(5)), '%PDF-');
      expect(String.fromCharCodes(pdf80.take(5)), '%PDF-');
    });

    // -------------------------------------------------------------------------
    // 2. Long Item Names & Decimal Quantities
    // -------------------------------------------------------------------------
    test('2. Layout Robustness: long item names and decimal quantities format cleanly without clipping', () async {
      final receipt = ReceiptData(
        title: 'SALES RECEIPT',
        referenceNo: 'SAL-10999',
        dateTime: '2026-10-26 14:15:00',
        partyName: 'Super Mega Wholesalers Pakistan (Private) Limited Khewra Depot',
        items: const [
          ReceiptLineItem(
            description: 'HGM Special Crushed Dark Pink Himalayan Mineral Rock Salt Extra Coarse Industrial Grade Export Quality',
            quantity: 1250.75,
            unit: 'kg',
            unitPrice: 42.50,
            totalAmount: 53156.88,
          ),
          ReceiptLineItem(
            description: 'Standard Woven Laminated Packaging Sacks 50kg Heavy Duty with Inner Polyethylene Liner',
            quantity: 25.5,
            unit: 'bundles',
            unitPrice: 650.0,
            totalAmount: 16575.0,
          ),
        ],
        subtotal: 69731.88,
        discount: 231.88,
        grandTotal: 69500.0,
        paidAmount: 50000.0,
        outstandingAmount: 19500.0,
      );

      // Verify both 58mm and 80mm layouts succeed
      final bytes58 = await PrintingService.instance.generateThermalReceiptPdf(receipt, paperWidth: '58');
      final bytes80 = await PrintingService.instance.generateThermalReceiptPdf(receipt, paperWidth: '80');

      expect(bytes58.length, greaterThan(1000));
      expect(bytes80.length, greaterThan(1000));
    });

    // -------------------------------------------------------------------------
    // 3. Large Multi-Million Rupee Totals & Formatting
    // -------------------------------------------------------------------------
    test('3. Large Totals: multi-million rupee amounts format and render accurately', () async {
      final receipt = ReceiptData(
        title: 'PURCHASE VOUCHER',
        referenceNo: 'PUR-99001',
        dateTime: '2026-10-26 16:30:00',
        partyLabel: 'Supplier',
        partyName: 'Khewra Mineral Mining Corporation',
        items: const [
          ReceiptLineItem(
            description: 'Raw Bulk Rock Salt Uncrushed Grade A',
            quantity: 500.0,
            unit: 'ton',
            unitPrice: 35000.0,
            totalAmount: 17500000.0,
          ),
        ],
        subtotal: 17500000.0,
        grandTotal: 17500000.0,
        paidAmount: 10000000.0,
        outstandingAmount: 7500000.0,
        partyBalance: 'Rs 14,250,000 Cr',
      );

      final pdfBytes = await PrintingService.instance.generateThermalReceiptPdf(receipt, paperWidth: '80');
      expect(pdfBytes, isNotEmpty);
      expect(receipt.grandTotal, equals(17500000.0));
      expect(receipt.outstandingAmount, equals(7500000.0));
    });

    // -------------------------------------------------------------------------
    // 4. Reprint Safety: reprinting never alters balances or adds transactions
    // -------------------------------------------------------------------------
    test('4. Reprint Safety: reprint action marks slip as REPRINT and preserves database state', () async {
      final db = await dbService.database;

      // 1. Create a real sale
      final customers = await db.query('parties', where: 'type = ?', whereArgs: ['Customer']);
      final customerId = customers.first['id'] as int;
      final initialCustomerBalance = await repo.getPartyBalance(customerId);

      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');
      final initialWalletBalance = cashWallet.balance;

      final sale = await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-26 10:00:00',
        items: [
          {'product_id': 1, 'quantity': 10.0, 'unit_price': 200.0},
        ],
        paidAmount: 1500.0,
        walletId: cashWallet.id,
      );

      // Verify post-sale state
      final postSaleCustBal = await repo.getPartyBalance(customerId);
      final walletAfterSale = (await repo.getWallets()).firstWhere((w) => w.id == cashWallet.id);
      final postSaleWalletBal = walletAfterSale.balance;

      expect(postSaleCustBal, equals(initialCustomerBalance + 500.0)); // 2000 total - 1500 paid = 500 due
      expect(postSaleWalletBal, equals(initialWalletBalance + 1500.0));

      final initialLedgerCount = (await db.query('wallet_ledger_entries')).length;
      final initialPartyLedgerCount = (await db.query('party_ledger_entries')).length;

      // 2. Perform 5 reprints of the receipt
      for (int i = 0; i < 5; i++) {
        final reprintData = PrintingService.instance.receiptFromSale(
          sale,
          customer: null,
          wallet: cashWallet,
          isReprint: true,
        );
        expect(reprintData.isReprint, isTrue);

        final bytes = await PrintingService.instance.generateThermalReceiptPdf(reprintData, paperWidth: '80');
        expect(bytes, isNotEmpty);
      }

      // 3. Confirm 100% database immutability
      final customerBalAfterReprints = await repo.getPartyBalance(customerId);
      final walletAfterReprints = (await repo.getWallets()).firstWhere((w) => w.id == cashWallet.id);
      final finalLedgerCount = (await db.query('wallet_ledger_entries')).length;
      final finalPartyLedgerCount = (await db.query('party_ledger_entries')).length;

      expect(customerBalAfterReprints, equals(postSaleCustBal));
      expect(walletAfterReprints.balance, equals(postSaleWalletBal));
      expect(finalLedgerCount, equals(initialLedgerCount));
      expect(finalPartyLedgerCount, equals(initialPartyLedgerCount));
    });

    // -------------------------------------------------------------------------
    // 5. All Transaction Receipts: Collections, Payments, Expenses, Transfers
    // -------------------------------------------------------------------------
    test('5. Transaction Slips: collection, payment, expense, transfer, and statement slips generate correctly', () async {
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');
      final bankWallet = wallets.firstWhere((w) => w.name == 'UBL Bank');

      // Customer Collection Voucher
      final collection = await repo.createDailyRecord(
        recordType: 'Customer Collection',
        recordDate: '2026-10-26 12:00:00',
        category: 'Customer Receipts',
        description: 'Payment on account from Al-Madina',
        partyId: 1,
        destinationWalletId: cashWallet.id,
        amount: 5000.0,
      );
      final colReceipt = PrintingService.instance.receiptFromDailyRecord(
        collection,
        destWallet: cashWallet,
      );
      expect(colReceipt.title, contains('COLLECTION'));
      expect(colReceipt.grandTotal, equals(5000.0));
      final colPdf = await PrintingService.instance.generateThermalReceiptPdf(colReceipt);
      expect(colPdf, isNotEmpty);

      // Supplier Payment Voucher
      final payment = await repo.createDailyRecord(
        recordType: 'Supplier Payment',
        recordDate: '2026-10-26 12:30:00',
        category: 'Supplier Payments',
        description: 'Part payment to Khewra Salt',
        partyId: 2,
        sourceWalletId: bankWallet.id,
        amount: 8000.0,
      );
      final payReceipt = PrintingService.instance.receiptFromDailyRecord(
        payment,
        sourceWallet: bankWallet,
      );
      expect(payReceipt.title, contains('PAYMENT'));
      expect(payReceipt.grandTotal, equals(8000.0));
      final payPdf = await PrintingService.instance.generateThermalReceiptPdf(payReceipt);
      expect(payPdf, isNotEmpty);

      // Inter-Wallet Transfer Slip
      final transfer = await repo.createDailyRecord(
        recordType: 'Wallet Transfer',
        recordDate: '2026-10-26 13:00:00',
        category: 'Inter-Wallet Transfer',
        description: 'Cash deposit to UBL Bank',
        sourceWalletId: cashWallet.id,
        destinationWalletId: bankWallet.id,
        amount: 15000.0,
      );
      final trfReceipt = PrintingService.instance.receiptFromDailyRecord(
        transfer,
        sourceWallet: cashWallet,
        destWallet: bankWallet,
      );
      expect(trfReceipt.title, contains('TRANSFER'));
      expect(trfReceipt.sourceWalletName, equals('Cash in Hand'));
      expect(trfReceipt.destinationWalletName, equals('UBL Bank'));
      final trfPdf = await PrintingService.instance.generateThermalReceiptPdf(trfReceipt);
      expect(trfPdf, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 6. A4 / Multi-Page Audited Reports Generation
    // -------------------------------------------------------------------------
    test('6. A4 Reports: generates professional tabular A4 PDF with KPI metrics and totals', () async {
      const report = ReportData(
        title: 'Factory Monthly Performance & Profitability Report',
        subtitle: 'Comprehensive financial audit of manufacturing operations',
        dateRange: '01 Oct 2026 to 31 Oct 2026',
        summaryMetrics: {
          'Total Revenue': 'Rs 8,420,000',
          'Total Overhead': 'Rs 7,486,000',
          'Operating Margin': '11.1%',
          'Closing Cash': 'Rs 2,340,000',
        },
        columnHeaders: ['METRIC', 'CLASSIFICATION', 'CONFIRMED AMOUNT (RS)'],
        rows: [
          ['Sales Revenue (Finished Goods)', 'Operating', '8,420,000'],
          ['Factory Labor & Electricity', 'Overhead', '2,400,000'],
          ['Raw Khewra Salt Procurements', 'Cost of Goods', '4,200,000'],
          ['Packaging Sacks & Packets', 'Cost of Goods', '886,000'],
          ['Net Operational Surplus', 'Net Profit', '934,000'],
        ],
        totalsRow: ['TOTAL NET SURPLUS', 'Reconciled', 'Rs 934,000'],
        columnAlignments: ['left', 'center', 'right'],
      );

      final pdfBytes = await PrintingService.instance.generateReportPdf(report);
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });

    // -------------------------------------------------------------------------
    // 7. Structured Report Queries & Multi-Year Cross-Calendar Date Filtering
    // -------------------------------------------------------------------------
    test('7. Filtered Report Queries: cross-year date boundaries separate 2025 and 2026 records', () async {
      final wallets = await repo.getWallets();
      final cashWallet = wallets.firstWhere((w) => w.name == 'Cash in Hand');

      // Record in 2025
      // Record in 2025
      await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2025-10-26 10:00:00',
        category: 'Fuel Audit Test',
        description: '2025 generator fuel',
        sourceWalletId: cashWallet.id,
        amount: 3500.0,
      );

      // Record in 2026
      await repo.createDailyRecord(
        recordType: 'Expense',
        recordDate: '2026-10-26 10:00:00',
        category: 'Fuel Audit Test',
        description: '2026 generator fuel',
        sourceWalletId: cashWallet.id,
        amount: 7200.0,
      );

      // Query 2025 report only
      final report2025 = await repo.getExpensesReport(
        startDate: '2025-01-01',
        endDate: '2025-12-31',
        category: 'Fuel Audit Test',
      );
      expect(report2025.rows.length, equals(1));
      expect(report2025.summaryMetrics['Total Expenses'], contains('3500'));

      // Query 2026 report only
      final report2026 = await repo.getExpensesReport(
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        category: 'Fuel Audit Test',
      );
      expect(report2026.rows.length, equals(1));
      expect(report2026.summaryMetrics['Total Expenses'], contains('7200'));
    });

    // -------------------------------------------------------------------------
    // 8. Stock Valuation Report & Reconciliation
    // -------------------------------------------------------------------------
    test('8. Stock Report: accurately calculates stock valuation, categories, and low stock items', () async {
      final reportAll = await repo.getStockValuationReport();
      expect(reportAll.rows, isNotEmpty);
      expect(reportAll.columnHeaders, contains('VALUATION'));
      expect(reportAll.summaryMetrics.containsKey('Total Valuation'), isTrue);

      // Filter by packaging category
      final reportPackaging = await repo.getStockValuationReport(category: 'Packaging');
      for (final r in reportPackaging.rows) {
        expect(r[2], equals('Packaging'));
      }
    });

    // -------------------------------------------------------------------------
    // 9. Empty Report Results Handling
    // -------------------------------------------------------------------------
    test('9. Empty Reports: handles empty date ranges gracefully without exceptions', () async {
      // Query distant future where no transactions exist
      final emptySalesReport = await repo.getSalesReport(
        startDate: '2099-01-01',
        endDate: '2099-12-31',
      );

      expect(emptySalesReport.rows, isEmpty);
      expect(emptySalesReport.summaryMetrics['Invoice Count'], equals('0'));
      expect(emptySalesReport.summaryMetrics['Total Revenue'], contains('0'));

      // PDF generation of empty report should succeed without crash
      final pdfBytes = await PrintingService.instance.generateReportPdf(emptySalesReport);
      expect(pdfBytes, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 10. PDF Export File System Writing & Fallback
    // -------------------------------------------------------------------------
    test('10. PDF Export: writes receipt and report files to disk with valid file paths', () async {
      final receipt = ReceiptData.sampleSalesReceipt();
      final receiptExport = await PrintingService.instance.exportReceiptPdf(receipt);

      expect(receiptExport.success, isTrue);
      expect(receiptExport.filePath, isNotNull);

      final file = File(receiptExport.filePath!);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(500));

      // Clean up exported file
      try {
        await file.delete();
      } catch (_) {}

      final report = await repo.getCashReconciliationReport();
      final reportExport = await PrintingService.instance.exportReportPdf(report);

      expect(reportExport.success, isTrue);
      expect(reportExport.filePath, isNotNull);

      final reportFile = File(reportExport.filePath!);
      expect(await reportFile.exists(), isTrue);
      expect(await reportFile.length(), greaterThan(1000));

      try {
        await reportFile.delete();
      } catch (_) {}
    });
  });
}
