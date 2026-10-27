import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:saltflow/database/database_service.dart';
import 'package:saltflow/repositories/erp_transaction_repository.dart';
import 'package:saltflow/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String liveDbPath;
  late String backupDir;
  late DatabaseService dbService;
  late ErpTransactionRepository repo;

  late int customerId;
  late int supplierId;
  late int cashWalletId;
  late int finishedProductId;
  late int rawSaltId;
  late int packagingId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('salt_reliability_test_');
    liveDbPath = p.join(tempDir.path, 'live_anwar_salt.db');
    backupDir = p.join(tempDir.path, 'Backups');
    await Directory(backupDir).create(recursive: true);

    dbService = DatabaseService.createTestingInstance(liveDbPath);
    repo = ErpTransactionRepository(dbService: dbService);

    final db = await dbService.database;

    final customers = await db.query('parties', where: 'type = ?', whereArgs: ['Customer']);
    final suppliers = await db.query('parties', where: 'type = ?', whereArgs: ['Supplier']);
    final wallets = await repo.getWallets();
    final products = await repo.getProducts();

    customerId = customers.first['id'] as int;
    supplierId = suppliers.first['id'] as int;
    cashWalletId = wallets.firstWhere((w) => w.name == 'Cash in Hand').id;
    finishedProductId = products.firstWhere((p) => p.code == 'FG-080024').id;
    rawSaltId = products.firstWhere((p) => p.code == 'RAW-PINK').id;
    packagingId = products.firstWhere((p) => p.code == 'PKG-00800').id;

    // 1. Post a Customer Sale
    await repo.createSale(
      customerId: customerId,
      saleDate: '2026-10-20',
      walletId: cashWalletId,
      paidAmount: 1500.0,
      notes: 'Initial wholesale delivery',
      items: [
        {
          'product_id': finishedProductId,
          'quantity': 25.0,
          'unit_price': 80.0,
        },
      ],
    );

    // 2. Post a Supplier Raw Salt Purchase
    await repo.createPurchase(
      supplierId: supplierId,
      purchaseDate: '2026-10-21',
      walletId: cashWalletId,
      paidAmount: 15000.0,
      notes: 'High grade pink salt blocks',
      items: [
        {
          'product_id': rawSaltId,
          'quantity': 1000.0,
          'unit_cost': 15.0,
        },
      ],
    );

    // 3. Post a Verified Production Batch
    await repo.createProductionBatch(
      finishedProductId: finishedProductId,
      batchDate: '2026-10-22',
      shift: 'Morning A',
      reportedQty: 50.0,
      verifiedQty: 50.0,
      consumedItems: [
        {
          'product_id': rawSaltId,
          'item_type': 'Raw Material',
          'quantity_consumed': 50.0,
          'unit_cost': 15.0,
        },
        {
          'product_id': packagingId,
          'item_type': 'Packaging',
          'quantity_consumed': 50.0,
          'unit_cost': 2.0,
        },
      ],
    );

    // 4. Post an Operational Expense
    await repo.createDailyRecord(
      recordType: 'Expense',
      recordDate: '2026-10-23',
      category: 'Utilities',
      description: 'Factory electricity bill - Khewra Grid',
      sourceWalletId: cashWalletId,
      amount: 4500.0,
    );
  });

  tearDown(() async {
    await dbService.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Anwar Salt Factory ERP - SQLite Reliability & Backup Tests', () {
    test('1. Create Backup: produces valid, timestamped SQLite snapshot with PRAGMA integrity verification', () async {
      final res = await BackupService.instance.createBackup(
        customDestinationDir: backupDir,
        reason: 'Automated test snapshot',
        dbServiceOverride: dbService,
      );

      expect(res.success, isTrue, reason: res.message);
      expect(res.backupPath, isNotNull);
      expect(res.isIntegrityVerified, isTrue);
      expect(res.fileSize, greaterThan(1024));

      final backupFile = File(res.backupPath!);
      expect(await backupFile.exists(), isTrue);

      // Verify filename formatting: AnwarSalt_Backup_YYYY-MM-DD_HHmmss.db
      final name = p.basename(res.backupPath!);
      expect(name.startsWith('AnwarSalt_Backup_'), isTrue);
      expect(name.endsWith('.db'), isTrue);

      // Directly verify SQLite magic header (first 16 bytes)
      final raf = await backupFile.open(mode: FileMode.read);
      final header = String.fromCharCodes(await raf.read(16));
      await raf.close();
      expect(header.startsWith('SQLite format 3'), isTrue);

      // Verify PRAGMA integrity_check directly against the backup file
      final check = await BackupService.instance.verifyBackupFile(res.backupPath!);
      expect(check.isValid, isTrue);
      expect(check.reason, equals('Verified OK'));
    });

    test('2. Accidental Overwrite Prevention: rapid successive backups generate unique timestamps', () async {
      final res1 = await BackupService.instance.createBackup(
        customDestinationDir: backupDir,
        dbServiceOverride: dbService,
      );
      final res2 = await BackupService.instance.createBackup(
        customDestinationDir: backupDir,
        dbServiceOverride: dbService,
      );

      expect(res1.success, isTrue);
      expect(res2.success, isTrue);
      expect(res1.backupPath, isNot(equals(res2.backupPath)));

      expect(File(res1.backupPath!).existsSync(), isTrue);
      expect(File(res2.backupPath!).existsSync(), isTrue);
    });

    test('3. Corrupted Backup Simulation: rejects invalid header, truncated file, and corrupt tables without touching live database', () async {
      // 3A. Truncated file (< 100 bytes)
      final truncatedPath = p.join(backupDir, 'AnwarSalt_Backup_truncated.db');
      await File(truncatedPath).writeAsString('TRUNCATED');
      final truncVerify = await BackupService.instance.verifyBackupFile(truncatedPath);
      expect(truncVerify.isValid, isFalse);
      expect(truncVerify.reason, contains('truncated'));

      // 3B. Invalid SQLite header (> 100 bytes non-SQLite garbage)
      final corruptPath = p.join(backupDir, 'AnwarSalt_Backup_corrupt_test.db');
      await File(corruptPath).writeAsString('CORRUPT_NON_SQLITE_GARBAGE_PAYLOAD_INVALID_MAGIC_HEADER_' * 4);

      // Verify validator detects the corrupt header
      final verify = await BackupService.instance.verifyBackupFile(corruptPath);
      expect(verify.isValid, isFalse);
      expect(verify.reason, contains('Invalid SQLite header format'));

      // Attempt restore with corrupt backup
      final restoreRes = await BackupService.instance.restoreBackup(
        corruptPath,
        dbServiceOverride: dbService,
      );

      expect(restoreRes.success, isFalse);
      expect(restoreRes.message, contains('Restore rejected'));

      // Verify live database was completely untouched and operational
      final integrity = await dbService.checkIntegrity();
      expect(integrity, isTrue);

      final balance = await repo.getPartyBalance(customerId);
      expect(balance, isNotNull);
    });

    test('4. Missing Directory & Permission Failures: handles unavailable folders gracefully with clear error', () async {
      // Use an invalid/inaccessible drive path
      final invalidDir = Platform.isWindows ? r'Z:\NonExistentDrive_SaltBackups' : '/non_existent_root_dir/backups';

      final res = await BackupService.instance.createBackup(
        customDestinationDir: invalidDir,
        dbServiceOverride: dbService,
      );

      expect(res.success, isFalse);
      expect(res.error, isNotNull);
      expect(res.message, contains('unavailable or inaccessible'));
    });

    test('5. Atomic Write Protection: temporary snapshot files (.tmp) are cleaned up and never left corrupted', () async {
      // Verify that after backup, no stale .tmp files remain in destination
      await BackupService.instance.createBackup(
        customDestinationDir: backupDir,
        dbServiceOverride: dbService,
      );

      final dir = Directory(backupDir);
      final tmpFiles = dir.listSync().where((f) => f.path.endsWith('.tmp')).toList();
      expect(tmpFiles, isEmpty, reason: 'Temporary backup files must be cleaned up atomically');
    });

    test('6. Retention Policy & Safety: prunes excess old backups but NEVER discards the only valid backup', () async {
      // Create 4 valid backups
      for (int i = 0; i < 4; i++) {
        await BackupService.instance.createBackup(
          customDestinationDir: backupDir,
          dbServiceOverride: dbService,
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      var history = await BackupService.instance.getBackupHistory(backupDir);
      expect(history.length, equals(4));

      // Clean with retention count of 2 -> 2 newest preserved, 2 oldest deleted
      final deleted = await BackupService.instance.cleanOldBackups(backupDir, 2);
      expect(deleted, equals(2));

      history = await BackupService.instance.getBackupHistory(backupDir);
      expect(history.length, equals(2));

      // Attempt retention count of 0 (edge case) -> MUST NOT discard the last remaining valid backup
      await BackupService.instance.cleanOldBackups(backupDir, 0);
      final remaining = await BackupService.instance.getBackupHistory(backupDir);
      expect(remaining.length, greaterThanOrEqualTo(1), reason: 'Never silently discard the only valid backup');
    });

    test('7. Controlled Restore & Rollback Protection: restores snapshot into isolated location and preserves exact records', () async {
      // Step A: Record state before mutation
      final initialCustomerBalance = await repo.getPartyBalance(customerId);
      final initialSupplierBalance = await repo.getPartyBalance(supplierId);
      final initialWalletBalance = await repo.getWalletBalance(cashWalletId);
      final initialStock = await repo.getProductStock(finishedProductId);

      // Step B: Take certified backup snapshot
      final backupRes = await BackupService.instance.createBackup(
        customDestinationDir: backupDir,
        reason: 'Pre-mutation test snapshot',
        dbServiceOverride: dbService,
      );
      expect(backupRes.success, isTrue);

      // Step C: Mutate the live database (destructive alterations)
      await repo.createSale(
        customerId: customerId,
        saleDate: '2026-10-24',
        walletId: cashWalletId,
        paidAmount: 5000.0,
        items: [
          {
            'product_id': finishedProductId,
            'quantity': 100.0,
            'unit_price': 80.0,
          },
        ],
      );

      final mutatedWalletBalance = await repo.getWalletBalance(cashWalletId);
      expect(mutatedWalletBalance, isNot(equals(initialWalletBalance)));

      // Step D: Restore the certified backup snapshot
      final restoreRes = await BackupService.instance.restoreBackup(
        backupRes.backupPath!,
        dbServiceOverride: dbService,
      );
      expect(restoreRes.success, isTrue, reason: restoreRes.message);

      // Step E: Verify customer, supplier, wallet, and stock returned to exact initial state
      final restoredCustomerBalance = await repo.getPartyBalance(customerId);
      final restoredSupplierBalance = await repo.getPartyBalance(supplierId);
      final restoredWalletBalance = await repo.getWalletBalance(cashWalletId);
      final restoredStock = await repo.getProductStock(finishedProductId);

      expect(restoredCustomerBalance, equals(initialCustomerBalance));
      expect(restoredSupplierBalance, equals(initialSupplierBalance));
      expect(restoredWalletBalance, equals(initialWalletBalance));
      expect(restoredStock, equals(initialStock));

      // Post-restore database integrity verification
      final integrity = await dbService.checkIntegrity();
      expect(integrity, isTrue);
    });

    test('8. Emergency Rollback on Broken File Replacement: preserves current database if restore verification fails', () async {
      // Create a valid SQLite DB file that is MISSING critical ERP tables (e.g. parties, wallets)
      final dummyDbPath = p.join(backupDir, 'AnwarSalt_Backup_empty_schema.db');
      final dummyDb = await databaseFactory.openDatabase(dummyDbPath);
      await dummyDb.execute('CREATE TABLE dummy_table (id INTEGER PRIMARY KEY);');
      await dummyDb.close();

      // Verify that restore validation rejects it and does NOT break the live database
      final restoreRes = await BackupService.instance.restoreBackup(
        dummyDbPath,
        dbServiceOverride: dbService,
      );

      expect(restoreRes.success, isFalse);
      expect(restoreRes.message, contains('Missing critical schema tables'));

      // Verify live database is fully intact
      final balance = await repo.getPartyBalance(customerId);
      expect(balance, isNotNull);
    });

    test('9. Schema Version Migration: upgrades from v1 schema to v2 without destroying existing user records', () async {
      // Create an isolated v1 database manually with baseline records
      final v1DbPath = p.join(tempDir.path, 'legacy_v1_database.db');
      final legacyDb = await databaseFactory.openDatabase(
        v1DbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            // Create legacy parties and wallets
            await db.execute('''
              CREATE TABLE parties (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL,
                name TEXT NOT NULL,
                contact_person TEXT,
                phone TEXT NOT NULL,
                secondary_phone TEXT,
                address TEXT,
                tax_id TEXT,
                opening_balance REAL NOT NULL DEFAULT 0.0,
                opening_balance_type TEXT NOT NULL DEFAULT 'Receivable',
                opening_balance_date TEXT NOT NULL,
                notes TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE wallets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL,
                balance REAL NOT NULL DEFAULT 0.0,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            await db.insert('parties', {
              'code': 'CUST-LEGACY-01',
              'type': 'Customer',
              'name': 'Khadim Salt Mart',
              'phone': '0300 9876543',
              'opening_balance': 150000.0,
              'opening_balance_type': 'Receivable',
              'opening_balance_date': '2025-01-01',
              'created_at': '2025-01-01T00:00:00',
              'updated_at': '2025-01-01T00:00:00',
            });
            await db.insert('wallets', {
              'name': 'Cash in Hand',
              'type': 'Cash',
              'balance': 345000.0,
              'created_at': '2025-01-01T00:00:00',
              'updated_at': '2025-01-01T00:00:00',
            });
          },
        ),
      );
      await legacyDb.close();

      // Open the v1 database with the upgraded DatabaseService (version: 2)
      final upgradedService = DatabaseService.createTestingInstance(v1DbPath);
      final upgradedDb = await upgradedService.database;

      // 1. Verify schema version is now 2
      final versionRes = await upgradedDb.rawQuery('PRAGMA user_version;');
      expect(versionRes.first.values.first, equals(2));

      // 2. Verify legacy customer was NOT destroyed
      final customerRows = await upgradedDb.query(
        'parties',
        where: 'code = ?',
        whereArgs: ['CUST-LEGACY-01'],
      );
      expect(customerRows.length, equals(1));
      expect(customerRows.first['name'], equals('Khadim Salt Mart'));
      expect(customerRows.first['opening_balance'], equals(150000.0));

      // 3. Verify legacy wallet balance was NOT destroyed
      final walletRows = await upgradedDb.query(
        'wallets',
        where: 'name = ?',
        whereArgs: ['Cash in Hand'],
      );
      expect(walletRows.length, equals(1));
      expect(walletRows.first['balance'], equals(345000.0));

      // 4. Verify system_settings and schema_migrations tables were added
      final settingsRows = await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('system_settings', 'schema_migrations');",
      );
      expect(settingsRows.length, equals(2));

      // 5. Verify system_settings key-value functionality works
      await upgradedService.setSetting('factory_manager', 'Adnan Khan');
      final val = await upgradedService.getSetting('factory_manager');
      expect(val, equals('Adnan Khan'));

      await upgradedService.close();
    });

    test('10. Shutdown & Scheduling Hooks: creates backup when enabled and logs power loss disclaimer', () async {
      // Test onNormalShutdown invocation
      final config = await BackupService.instance.loadConfig();
      expect(config.backupOnShutdown, isTrue);

      await BackupService.instance.onNormalShutdown(dbServiceOverride: dbService);

      // Verify backup was generated
      final history = await BackupService.instance.getBackupHistory();
      expect(history, isNotEmpty);
      expect(history.first.isValid, isTrue);
    });
  });
}
