import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/models/party.dart';
import 'package:saltflow/repositories/party_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late PartyRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_party_test_');
    dbPath = p.join(tempDir.path, 'test_salt_factory.db');
    dbService = DatabaseService.createTestingInstance(dbPath);
    repository = PartyRepository(dbService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('1. Baseline Seeding: Existing customer and supplier records remain accessible', () async {
    final customers = await repository.getParties(type: 'Customer');
    final suppliers = await repository.getParties(type: 'Supplier');

    // Baseline had 4 customers and 4 suppliers
    expect(customers.length, 4);
    expect(suppliers.length, 4);

    final khewra = suppliers.firstWhere((s) => s.code == 'SUP-0012');
    expect(khewra.name, 'Khewra Salt Co.');
    expect(khewra.phone, '+92 300 812 4780');
    expect(khewra.currentBalance, 426000.0);
    expect(khewra.balanceDirection, 'Payable');

    final madina = customers.firstWhere((c) => c.code == 'CUS-0142');
    expect(madina.name, 'Al-Madina Traders');
    expect(madina.currentBalance, 182500.0);
    expect(madina.balanceDirection, 'Receivable');
  });

  test('2. Create Customer and Supplier profiles with correct initial data', () async {
    final newCust = Party(
      code: 'CUS-0999',
      type: 'Customer',
      name: 'Khyber Salt Distributors',
      contactPerson: 'Arbab Jehangir',
      phone: '+92 313 900 1234',
      secondaryPhone: '+92 91 500 4321',
      address: 'Plot 10, Industrial Estate, Hayatabad, Peshawar',
      taxId: 'NTN-7712345-0',
      openingBalance: 75000.0,
      openingBalanceType: 'Receivable',
      openingBalanceDate: '2026-10-15',
      notes: 'Wholesale contract 500 MT per month',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );

    final custId = await repository.createParty(newCust);
    expect(custId, isPositive);

    final newSupp = Party(
      code: 'SUP-0888',
      type: 'Supplier',
      name: 'Indus Bag Manufacturers',
      contactPerson: 'Farhan Zaidi',
      phone: '+92 345 678 9012',
      address: 'Circular Road, Multan',
      taxId: 'STRN-9988776-5',
      openingBalance: 45000.0,
      openingBalanceType: 'Payable',
      openingBalanceDate: '2026-10-10',
      notes: 'Laminated packaging liners supplier',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );

    final suppId = await repository.createParty(newSupp);
    expect(suppId, isPositive);

    // Verify fetched customer
    final fetchedCust = await repository.getPartyById(custId);
    expect(fetchedCust, isNotNull);
    expect(fetchedCust!.code, 'CUS-0999');
    expect(fetchedCust.name, 'Khyber Salt Distributors');
    expect(fetchedCust.contactPerson, 'Arbab Jehangir');
    expect(fetchedCust.phone, '+92 313 900 1234');
    expect(fetchedCust.currentBalance, 75000.0);
    expect(fetchedCust.balanceDirection, 'Receivable');

    // Verify fetched supplier
    final fetchedSupp = await repository.getPartyById(suppId);
    expect(fetchedSupp, isNotNull);
    expect(fetchedSupp!.code, 'SUP-0888');
    expect(fetchedSupp.name, 'Indus Bag Manufacturers');
    expect(fetchedSupp.currentBalance, 45000.0);
    expect(fetchedSupp.balanceDirection, 'Payable');
  });

  test('3 & 4. Edit names, contact details, notes and verify updated info everywhere', () async {
    final cust = Party(
      code: 'CUS-0555',
      type: 'Customer',
      name: 'Original Store Name',
      phone: '+92 300 111 2233',
      openingBalance: 10000.0,
      openingBalanceType: 'Receivable',
      openingBalanceDate: '2026-10-01',
      notes: 'Initial test note',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    final id = await repository.createParty(cust);

    final saved = await repository.getPartyById(id);
    final updated = saved!.copyWith(
      name: 'Grand Frontier Salt Mart',
      contactPerson: 'Zia-ur-Rehman',
      phone: '+92 300 999 8877',
      address: 'University Road, Peshawar',
      notes: 'Updated credit limit approved by Director',
      openingBalance: 25000.0,
    );

    await repository.updateParty(updated);

    final reloaded = await repository.getPartyById(id);
    expect(reloaded!.name, 'Grand Frontier Salt Mart');
    expect(reloaded.contactPerson, 'Zia-ur-Rehman');
    expect(reloaded.phone, '+92 300 999 8877');
    expect(reloaded.address, 'University Road, Peshawar');
    expect(reloaded.notes, 'Updated credit limit approved by Director');
    expect(reloaded.openingBalance, 25000.0);
    expect(reloaded.currentBalance, 25000.0);

    // Verify it appears updated in list view
    final allCustomers = await repository.getParties(type: 'Customer', searchQuery: 'Frontier');
    expect(allCustomers.length, 1);
    expect(allCustomers.first.name, 'Grand Frontier Salt Mart');
  });

  test('5 & 6. Opening balances do not create false revenue or expenses', () async {
    final cust = Party(
      code: 'CUS-0777',
      type: 'Customer',
      name: 'Audit Trail Test Customer',
      phone: '+92 300 555 4433',
      openingBalance: 500000.0,
      openingBalanceType: 'Receivable',
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    final id = await repository.createParty(cust);

    final ledger = await repository.getPartyLedger(id);
    expect(ledger.length, 1);
    expect(ledger.first.isOpeningBalance, isTrue);
    expect(ledger.first.entryType, 'Opening Balance');
    expect(ledger.first.debit, 500000.0);
    expect(ledger.first.credit, 0.0);
    expect(ledger.first.runningBalance, 500000.0);

    // Revenue queries must check non-opening entries
    final db = await dbService.database;
    final commercialSales = await db.rawQuery('''
      SELECT SUM(debit) as total_sales 
      FROM party_ledger_entries 
      WHERE party_id = ? AND is_opening_balance = 0
    ''', [id]);
    expect(commercialSales.first['total_sales'], isNull); // ZERO commercial sales created!

    // Verify that reports do not classify opening balance as a sale invoice
    final commercialTxns = await repository.getPartyTransactions(id);
    expect(commercialTxns.isEmpty, isTrue);
  });

  test('7. Search, Filtering, Archive, and Restore workflows', () async {
    final p1 = Party(
      code: 'CUS-0101',
      type: 'Customer',
      name: 'Alpha Supermarket',
      phone: '+92 333 111 2222',
      openingBalance: 50000.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    final id = await repository.createParty(p1);

    // Search by name
    var searchResult = await repository.getParties(type: 'Customer', searchQuery: 'Alpha');
    expect(searchResult.any((p) => p.code == 'CUS-0101'), isTrue);

    // Search by phone
    searchResult = await repository.getParties(type: 'Customer', searchQuery: '333 111');
    expect(searchResult.any((p) => p.code == 'CUS-0101'), isTrue);

    // Archive party
    await repository.setArchived(id, true);
    var archivedParty = await repository.getPartyById(id);
    expect(archivedParty!.isArchived, isTrue);

    // Active filter hides archived
    var activeList = await repository.getParties(type: 'Customer', statusFilter: 'Active');
    expect(activeList.any((p) => p.code == 'CUS-0101'), isFalse);

    // Archived filter shows it
    var archivedList = await repository.getParties(type: 'Customer', statusFilter: 'Archived');
    expect(archivedList.any((p) => p.code == 'CUS-0101'), isTrue);

    // Restore party
    await repository.setArchived(id, false);
    activeList = await repository.getParties(type: 'Customer', statusFilter: 'Active');
    expect(activeList.any((p) => p.code == 'CUS-0101'), isTrue);
  });

  test('8. Safe Deletion: Unused profile can be deleted cleanly', () async {
    final unused = Party(
      code: 'SUP-0999',
      type: 'Supplier',
      name: 'Unused Temporary Vendor',
      phone: '+92 300 000 1122',
      openingBalance: 0.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    final id = await repository.createParty(unused);

    // Verify it exists
    expect(await repository.getPartyById(id), isNotNull);

    // Delete unused profile
    await repository.deleteParty(id);

    // Confirm it is gone
    expect(await repository.getPartyById(id), isNull);
  });

  test('9. Protected Deletion: Profile with commercial transaction history cannot be deleted', () async {
    // Al-Madina Traders has commercial invoices SAL-10482 and COL-01673
    final customers = await repository.getParties(type: 'Customer', searchQuery: 'Al-Madina');
    final madina = customers.first;

    expect(
      () => repository.deleteParty(madina.id!),
      throwsA(isA<PartyHasTransactionsException>()),
    );

    // Confirm Al-Madina still exists safely in database
    final stillThere = await repository.getPartyById(madina.id!);
    expect(stillThere, isNotNull);
    expect(stillThere!.name, 'Al-Madina Traders');
  });

  test('10. Duplicate ID/Code prevention is enforced', () async {
    final p1 = Party(
      code: 'CUS-0999',
      type: 'Customer',
      name: 'First User',
      phone: '+92 300 123 4567',
      openingBalance: 0.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    await repository.createParty(p1);

    final duplicate = Party(
      code: 'CUS-0999', // Duplicate code!
      type: 'Customer',
      name: 'Duplicate Pretender',
      phone: '+92 300 987 6543',
      openingBalance: 0.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );

    expect(
      () => repository.createParty(duplicate),
      throwsA(isA<DuplicatePartyCodeException>()),
    );
  });

  test('11. Database Persistence across restart', () async {
    final party = Party(
      code: 'CUS-0888',
      type: 'Customer',
      name: 'Persistent Salt Mart',
      contactPerson: 'Imran Khan',
      phone: '+92 312 999 8888',
      openingBalance: 125000.0,
      openingBalanceDate: '2026-10-01',
      createdAt: '2026-10-18T10:00:00',
      updatedAt: '2026-10-18T10:00:00',
    );
    final id = await repository.createParty(party);

    // Close database connection simulating application termination
    await dbService.close();

    // Reopen database from the exact same file path
    final restartedService = DatabaseService.createTestingInstance(dbPath);
    final restartedRepo = PartyRepository(dbService: restartedService);

    final restored = await restartedRepo.getPartyById(id);
    expect(restored, isNotNull);
    expect(restored!.code, 'CUS-0888');
    expect(restored.name, 'Persistent Salt Mart');
    expect(restored.contactPerson, 'Imran Khan');
    expect(restored.currentBalance, 125000.0);

    final ledger = await restartedRepo.getPartyLedger(id);
    expect(ledger.length, 1);
    expect(ledger.first.debit, 125000.0);

    await restartedService.close();
  });
}
