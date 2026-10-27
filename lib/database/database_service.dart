import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static const int currentSchemaVersion = 2;
  static DatabaseService? _instance;
  static Database? _sharedDatabase;
  Database? _localDatabase;
  final String? dbPathOverride;
  String? _resolvedPath;

  DatabaseService._({this.dbPathOverride});

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Create a scoped instance for testing with an isolated database
  static DatabaseService createTestingInstance(String path) {
    return DatabaseService._(dbPathOverride: path);
  }

  /// Override or reset the default instance (useful in testing)
  static void setTestingInstance(DatabaseService? service) {
    _instance = service;
    _sharedDatabase = null;
  }

  Future<Database> get database async {
    if (dbPathOverride != null) {
      if (_localDatabase != null && _localDatabase!.isOpen) return _localDatabase!;
      _localDatabase = await _initDatabase();
      return _localDatabase!;
    }
    if (_sharedDatabase != null && _sharedDatabase!.isOpen) return _sharedDatabase!;
    _sharedDatabase = await _initDatabase();
    return _sharedDatabase!;
  }

  /// Resolves the actual physical SQLite file path
  Future<String> getDatabasePath() async {
    if (_resolvedPath != null) return _resolvedPath!;
    await database;
    return _resolvedPath!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows desktop & tests
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.environment.containsKey('FLUTTER_TEST')) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (dbPathOverride != null) {
      path = dbPathOverride!;
    } else {
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        final dbFolder = Directory(p.join(appSupportDir.path, 'AnwarSaltFactory'));
        if (!await dbFolder.exists()) {
          await dbFolder.create(recursive: true);
        }
        path = p.join(dbFolder.path, 'anwar_salt_factory.db');
      } catch (_) {
        path = inMemoryDatabasePath;
      }
    }
    _resolvedPath = path;

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: currentSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedBaselineData(db);
          await _seedOperationalBaselineData(db);
          await db.insert('schema_migrations', {
            'version': currentSchemaVersion,
            'applied_at': DateTime.now().toIso8601String(),
            'description': 'Initial baseline schema creation (v$currentSchemaVersion)',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _runMigrations(db, oldVersion, newVersion);
        },
        onOpen: (db) async {
          await _createTables(db);
          final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM parties');
          final cnt = (rows.first['cnt'] as int?) ?? 0;
          if (cnt == 0) {
            await _seedBaselineData(db);
          }
          final wRows = await db.rawQuery('SELECT COUNT(*) as cnt FROM wallets');
          final wCnt = (wRows.first['cnt'] as int?) ?? 0;
          if (wCnt == 0) {
            await _seedOperationalBaselineData(db);
          }
        },
      ),
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Parties (Customers & Suppliers)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parties (
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parties_type ON parties(type);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parties_code ON parties(code);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parties_archived ON parties(is_archived);');

    // 2. Party Ledger Entries (Accounting Double-Entry Trail)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS party_ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        reference_no TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        description TEXT NOT NULL,
        debit REAL NOT NULL DEFAULT 0.0,
        credit REAL NOT NULL DEFAULT 0.0,
        running_balance REAL NOT NULL DEFAULT 0.0,
        is_opening_balance INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (party_id) REFERENCES parties(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_party_id ON party_ledger_entries(party_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_entry_date ON party_ledger_entries(entry_date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_is_opening ON party_ledger_entries(is_opening_balance);');

    // 3. Transactions linked to parties (Sales, Purchases, Payments, Collections)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS party_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_id INTEGER NOT NULL,
        transaction_no TEXT UNIQUE NOT NULL,
        transaction_type TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        outstanding_amount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (party_id) REFERENCES parties(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_party_id ON party_transactions(party_id);');

    // 4. Wallets & Accounts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 5. Wallet Ledger Entries
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallet_ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        reference_no TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_id INTEGER,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        direction TEXT NOT NULL,
        running_balance REAL NOT NULL DEFAULT 0.0,
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wallet_ledger_wallet_id ON wallet_ledger_entries(wallet_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wallet_ledger_ref ON wallet_ledger_entries(reference_no);');

    // 6. Products & Raw Materials & Packaging
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        base_unit TEXT NOT NULL,
        conversion_description TEXT,
        current_stock REAL NOT NULL DEFAULT 0.0,
        average_cost REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'Active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_code ON products(code);');

    // 7. Inventory Stock Movements (Double-entry stock ledger)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_date TEXT NOT NULL,
        reference_no TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        source_id INTEGER,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        total_cost REAL NOT NULL DEFAULT 0.0,
        balance_after REAL NOT NULL DEFAULT 0.0,
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_ref ON stock_movements(reference_no);');

    // 8. Purchases
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_no TEXT UNIQUE NOT NULL,
        supplier_id INTEGER NOT NULL,
        purchase_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        outstanding_amount REAL NOT NULL DEFAULT 0.0,
        wallet_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES parties(id) ON DELETE RESTRICT,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchases_no ON purchases(purchase_no);');

    // 9. Purchase Items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_cost REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');

    // 10. Sales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_no TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        sale_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        outstanding_amount REAL NOT NULL DEFAULT 0.0,
        wallet_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES parties(id) ON DELETE RESTRICT,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_no ON sales(sale_no);');

    // 11. Sale Items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');

    // 12. Daily Records (Expenses, Incomes, Collections, Payments, Transfers)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_no TEXT UNIQUE NOT NULL,
        record_date TEXT NOT NULL,
        record_type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        party_id INTEGER,
        source_wallet_id INTEGER,
        destination_wallet_id INTEGER,
        amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'Active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (party_id) REFERENCES parties(id) ON DELETE RESTRICT,
        FOREIGN KEY (source_wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT,
        FOREIGN KEY (destination_wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_records_no ON daily_records(record_no);');

    // 13. Production Batches
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_no TEXT UNIQUE NOT NULL,
        batch_date TEXT NOT NULL,
        shift TEXT NOT NULL,
        finished_product_id INTEGER NOT NULL,
        reported_qty REAL NOT NULL,
        verified_qty REAL NOT NULL,
        rejected_qty REAL NOT NULL DEFAULT 0.0,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        total_cost REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'Verified',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (finished_product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_production_batches_no ON production_batches(batch_no);');

    // 14. Production Items (Consumed Materials)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        item_type TEXT NOT NULL,
        quantity_consumed REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        total_cost REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (batch_id) REFERENCES production_batches(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');

    // 15. Audit Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        reference_no TEXT NOT NULL,
        action TEXT NOT NULL,
        previous_state TEXT,
        new_state TEXT,
        reason TEXT NOT NULL,
        user_name TEXT NOT NULL DEFAULT 'Adnan Khan',
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_ref ON audit_logs(reference_no);');

    // 16. Unit Conversions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        from_unit TEXT NOT NULL,
        to_unit TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_unit_conv_prod ON unit_conversions(product_id);');

    // 17. Product Recipes (BOM)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        finished_product_id INTEGER NOT NULL,
        recipe_name TEXT NOT NULL,
        version TEXT NOT NULL DEFAULT 'v1',
        base_output_quantity REAL NOT NULL DEFAULT 1.0,
        labor_cost_per_unit REAL NOT NULL DEFAULT 0.0,
        power_cost_per_unit REAL NOT NULL DEFAULT 0.0,
        overhead_cost_per_unit REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (finished_product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recipes_product ON product_recipes(finished_product_id);');

    // 18. Product Recipe Items (Ingredients)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        ingredient_product_id INTEGER NOT NULL,
        quantity_per_base_unit REAL NOT NULL,
        waste_percentage REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (recipe_id) REFERENCES product_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON product_recipe_items(recipe_id);');

    // 19. Stock Adjustments (Physical count discrepancies, damage, etc.)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adjustment_no TEXT UNIQUE NOT NULL,
        product_id INTEGER NOT NULL,
        adjustment_date TEXT NOT NULL,
        adjustment_type TEXT NOT NULL,
        expected_quantity REAL NOT NULL,
        counted_quantity REAL NOT NULL,
        difference_quantity REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        total_cost REAL NOT NULL DEFAULT 0.0,
        reason TEXT NOT NULL,
        operator_name TEXT NOT NULL DEFAULT 'Warehouse Supervisor',
        status TEXT NOT NULL DEFAULT 'Approved',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_adj_product ON stock_adjustments(product_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_adj_no ON stock_adjustments(adjustment_no);');

    // 20. Sales Returns
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_no TEXT UNIQUE NOT NULL,
        sale_id INTEGER,
        customer_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        return_date TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_refund REAL NOT NULL,
        wallet_id INTEGER,
        refund_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Approved',
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE RESTRICT,
        FOREIGN KEY (customer_id) REFERENCES parties(id) ON DELETE RESTRICT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');

    // 21. Purchase Returns
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_no TEXT UNIQUE NOT NULL,
        purchase_id INTEGER,
        supplier_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        return_date TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_refund REAL NOT NULL,
        wallet_id INTEGER,
        refund_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Approved',
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE RESTRICT,
        FOREIGN KEY (supplier_id) REFERENCES parties(id) ON DELETE RESTRICT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT
      );
    ''');

    // 22. System Settings Key-Value Store
    await db.execute('''
      CREATE TABLE IF NOT EXISTS system_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 23. Schema Migrations History Log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL,
        description TEXT NOT NULL
      );
    ''');
  }

  Future<void> _seedBaselineData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Baseline Suppliers
    final suppliers = [
      {
        'code': 'SUP-0012',
        'type': 'Supplier',
        'name': 'Khewra Salt Co.',
        'contact_person': 'Haji Munir Khewra',
        'phone': '+92 300 812 4780',
        'secondary_phone': '+92 51 228 9011',
        'address': 'Mine Site Road, Khewra, District Jhelum',
        'tax_id': 'NTN-3829104-7',
        'opening_balance': 300000.0,
        'opening_balance_type': 'Payable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Primary raw pink rock salt supplier. Grade A boulders.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'PUR-08314',
            'type': 'Purchase Invoice',
            'desc': 'Raw Pink Rock Salt 40MT',
            'debit': 0.0,
            'credit': 126000.0,
            'date': '2026-10-26 10:18:00',
            'status': 'Unpaid',
            'amount': 126000.0,
            'paid': 0.0,
            'outstanding': 126000.0,
          }
        ]
      },
      {
        'code': 'SUP-0018',
        'type': 'Supplier',
        'name': 'Pak Packaging Industries',
        'contact_person': 'Tariq Mehmood',
        'phone': '+92 321 445 9032',
        'secondary_phone': '+92 42 351 1890',
        'address': 'Plot 44, Industrial Estate, Gujranwala',
        'tax_id': 'STRN-0801999-2',
        'opening_balance': 84000.0,
        'opening_balance_type': 'Payable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Master corrugated outer cartons & 800g printed retail rolls.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'PUR-08313',
            'type': 'Purchase Invoice',
            'desc': '10,000 Master Cartons with Anwar Brand Print',
            'debit': 0.0,
            'credit': 84500.0,
            'date': '2026-10-25 15:22:00',
            'status': 'Partial',
            'amount': 84500.0,
            'paid': 50000.0,
            'outstanding': 34500.0,
          },
          {
            'ref': 'PAY-00812',
            'type': 'Payment',
            'desc': 'Cheque payment via UBL Bank A/C',
            'debit': 50000.0,
            'credit': 0.0,
            'date': '2026-10-25 16:30:00',
            'status': 'Paid',
            'amount': 50000.0,
            'paid': 50000.0,
            'outstanding': 0.0,
          }
        ]
      },
      {
        'code': 'SUP-0024',
        'type': 'Supplier',
        'name': 'Rashid Woven Bags',
        'contact_person': 'Rashid Javed',
        'phone': '+92 333 672 1105',
        'secondary_phone': null,
        'address': 'Sargodha Road, Faisalabad',
        'tax_id': 'NTN-1902834-1',
        'opening_balance': 0.0,
        'opening_balance_type': 'Payable',
        'opening_balance_date': '2026-10-01',
        'notes': '50kg woven PP bags for bulk industrial salt.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'PUR-08312',
            'type': 'Purchase Invoice',
            'desc': '2,000 PP Woven Bags (50kg)',
            'debit': 0.0,
            'credit': 47000.0,
            'date': '2026-10-24 11:15:00',
            'status': 'Paid',
            'amount': 47000.0,
            'paid': 47000.0,
            'outstanding': 0.0,
          },
          {
            'ref': 'PAY-00798',
            'type': 'Payment',
            'desc': 'Cash in hand settlement upon delivery',
            'debit': 47000.0,
            'credit': 0.0,
            'date': '2026-10-24 11:45:00',
            'status': 'Paid',
            'amount': 47000.0,
            'paid': 47000.0,
            'outstanding': 0.0,
          }
        ]
      },
      {
        'code': 'SUP-0031',
        'type': 'Supplier',
        'name': 'Iqbal Transport Service',
        'contact_person': 'Chaudhry Iqbal',
        'phone': '+92 304 112 7964',
        'secondary_phone': null,
        'address': 'Truck Stand, GT Road, Peshawar',
        'tax_id': null,
        'opening_balance': 26800.0,
        'opening_balance_type': 'Payable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Freight and haulage from Khewra mines to factory.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': []
      },
    ];

    // Baseline Customers
    final customers = [
      {
        'code': 'CUS-0142',
        'type': 'Customer',
        'name': 'Al-Madina Traders',
        'contact_person': 'Sheikh Abdul Rehman',
        'phone': '+92 300 778 5421',
        'secondary_phone': '+92 91 582 3344',
        'address': 'Shop 12, New Grain Market, Peshawar',
        'tax_id': 'NTN-8821943-3',
        'opening_balance': 182500.0,
        'opening_balance_type': 'Receivable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Key wholesale distributor for Peshawar & Charsadda.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'SAL-10482',
            'type': 'Sale Invoice',
            'desc': '50 Cartons HGM Pink Salt 800g',
            'debit': 48500.0,
            'credit': 0.0,
            'date': '2026-10-26 11:42:00',
            'status': 'Paid',
            'amount': 48500.0,
            'paid': 48500.0,
            'outstanding': 0.0,
          },
          {
            'ref': 'COL-01673',
            'type': 'Collection',
            'desc': 'Full payment collected via Cash in Hand',
            'debit': 0.0,
            'credit': 48500.0,
            'date': '2026-10-26 11:45:00',
            'status': 'Paid',
            'amount': 48500.0,
            'paid': 48500.0,
            'outstanding': 0.0,
          }
        ]
      },
      {
        'code': 'CUS-0098',
        'type': 'Customer',
        'name': 'Usman General Store',
        'contact_person': 'Muhammad Usman',
        'phone': '+92 321 550 4418',
        'secondary_phone': null,
        'address': 'Main Bazar, Kohat Road, Peshawar',
        'tax_id': null,
        'opening_balance': 32000.0,
        'opening_balance_type': 'Receivable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Semi-wholesale retail grocer. 15-day credit cycle.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'COL-01672',
            'type': 'Collection',
            'desc': 'Cheque clearing towards opening ledger balance',
            'debit': 0.0,
            'credit': 32000.0,
            'date': '2026-10-26 09:12:00',
            'status': 'Paid',
            'amount': 32000.0,
            'paid': 32000.0,
            'outstanding': 0.0,
          },
          {
            'ref': 'SAL-10479',
            'type': 'Sale Invoice',
            'desc': 'Fine White Salt 1kg × 70 Cartons',
            'debit': 68000.0,
            'credit': 0.0,
            'date': '2026-10-26 13:25:00',
            'status': 'Unpaid',
            'amount': 68000.0,
            'paid': 0.0,
            'outstanding': 68000.0,
          }
        ]
      },
      {
        'code': 'CUS-0044',
        'type': 'Customer',
        'name': 'Punjab Cash & Carry',
        'contact_person': 'Malik Zubair',
        'phone': '+92 333 708 2290',
        'secondary_phone': '+92 51 448 9022',
        'address': 'I-8 Markaz, Islamabad',
        'tax_id': 'STRN-0701888-9',
        'opening_balance': 0.0,
        'opening_balance_type': 'Receivable',
        'opening_balance_date': '2026-10-01',
        'notes': 'Direct retail store replenishment. Strictly cash-on-delivery.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': []
      },
      {
        'code': 'CUS-0178',
        'type': 'Customer',
        'name': 'Noor Wholesale Mart',
        'contact_person': 'Haji Noor Muhammad',
        'phone': '+92 304 651 9072',
        'secondary_phone': null,
        'address': 'Ganj Bazar, Old City, Peshawar',
        'tax_id': 'NTN-5541098-4',
        'opening_balance': 159300.0,
        'opening_balance_type': 'Receivable',
        'opening_balance_date': '2026-09-15',
        'notes': 'High volume buyer. Aging balance exceeds 30 days.',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
        'history': [
          {
            'ref': 'SAL-10480',
            'type': 'Sale Invoice',
            'desc': 'Industrial Grade Salt 50kg bags × 150',
            'debit': 126000.0,
            'credit': 0.0,
            'date': '2026-10-23 16:12:00',
            'status': 'Partial',
            'amount': 126000.0,
            'paid': 40000.0,
            'outstanding': 86000.0,
          },
          {
            'ref': 'COL-01660',
            'type': 'Collection',
            'desc': 'Partial payment received in cash',
            'debit': 0.0,
            'credit': 40000.0,
            'date': '2026-10-23 16:30:00',
            'status': 'Paid',
            'amount': 40000.0,
            'paid': 40000.0,
            'outstanding': 0.0,
          }
        ]
      },
    ];

    // Seed into Database inside an explicit transaction
    await db.transaction((txn) async {
      for (final p in [...suppliers, ...customers]) {
        final history = (p['history'] as List<dynamic>?) ?? [];
        final Map<String, dynamic> partyMap = Map<String, dynamic>.from(p);
        partyMap.remove('history');

        final partyId = await txn.insert('parties', partyMap);

        double runningBal = 0.0;
        final isCustomer = p['type'] == 'Customer';
        final opBal = (p['opening_balance'] as num).toDouble();
        final opType = p['opening_balance_type'] as String;

        // 1. Write opening balance ledger entry if opBal > 0 or explicit 0 entry
        double opDebit = 0.0;
        double opCredit = 0.0;
        if (isCustomer) {
          if (opType == 'Receivable') {
            opDebit = opBal;
            runningBal = opBal;
          } else {
            opCredit = opBal;
            runningBal = -opBal;
          }
        } else {
          // Supplier
          if (opType == 'Payable') {
            opCredit = opBal;
            runningBal = opBal;
          } else {
            opDebit = opBal;
            runningBal = -opBal;
          }
        }

        await txn.insert('party_ledger_entries', {
          'party_id': partyId,
          'entry_date': p['opening_balance_date'],
          'reference_no': 'OPB-${p['code']}',
          'entry_type': 'Opening Balance',
          'description': 'Verified opening balance as of ${p['opening_balance_date']}',
          'debit': opDebit,
          'credit': opCredit,
          'running_balance': runningBal,
          'is_opening_balance': 1,
          'created_at': now,
        });

        // 2. Insert subsequent transaction history
        for (final item in history) {
          final debit = (item['debit'] as num).toDouble();
          final credit = (item['credit'] as num).toDouble();

          if (isCustomer) {
            runningBal += (debit - credit);
          } else {
            runningBal += (credit - debit);
          }

          await txn.insert('party_ledger_entries', {
            'party_id': partyId,
            'entry_date': item['date'],
            'reference_no': item['ref'],
            'entry_type': item['type'],
            'description': item['desc'],
            'debit': debit,
            'credit': credit,
            'running_balance': runningBal,
            'is_opening_balance': 0,
            'created_at': now,
          });

          // Insert into party_transactions
          await txn.insert('party_transactions', {
            'party_id': partyId,
            'transaction_no': item['ref'],
            'transaction_type': item['type'],
            'transaction_date': item['date'],
            'amount': (item['amount'] as num).toDouble(),
            'paid_amount': (item['paid'] as num).toDouble(),
            'outstanding_amount': (item['outstanding'] as num).toDouble(),
            'status': item['status'],
            'notes': item['desc'],
            'created_at': now,
          });
        }
      }
    });
  }

  Future<void> _seedOperationalBaselineData(Database db) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Wallets
      final walletIds = <String, int>{};
      final initialWallets = [
        {'name': 'Cash in Hand', 'type': 'Cash', 'balance': 268450.0},
        {'name': 'UBL Bank', 'type': 'Bank', 'balance': 786200.0},
        {'name': 'EasyPaisa', 'type': 'Digital wallet', 'balance': 230000.0},
        {'name': 'Cash in Hand — HGM Work', 'type': 'Cash', 'balance': 84600.0},
        {'name': 'UBL Bank — HGM Work', 'type': 'Bank', 'balance': 150000.0},
        {'name': 'EasyPaisa — HGM Work', 'type': 'Digital wallet', 'balance': 45000.0},
      ];

      for (final w in initialWallets) {
        final id = await txn.insert('wallets', {
          'name': w['name'],
          'type': w['type'],
          'balance': w['balance'],
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        walletIds[w['name'] as String] = id;

        // Opening wallet ledger entry
        await txn.insert('wallet_ledger_entries', {
          'wallet_id': id,
          'entry_date': '2026-10-01',
          'reference_no': 'OPB-${(w['name'] as String).replaceAll(' ', '').toUpperCase()}',
          'source_type': 'Opening Balance',
          'source_id': null,
          'description': 'Verified opening wallet balance as of 2026-10-01',
          'amount': w['balance'],
          'direction': 'IN',
          'running_balance': w['balance'],
          'is_cancelled': 0,
          'created_at': now,
        });
      }

      // 2. Products
      final productIds = <String, int>{};
      final initialProducts = [
        {
          'code': 'FG-080024',
          'name': 'HGM Pink Salt 800g × 24',
          'category': 'Finished goods',
          'base_unit': 'Packet',
          'conversion_description': '1 cotton = 24 packets = 19.2 kg',
          'current_stock': 12480.0,
          'average_cost': 76.40,
        },
        {
          'code': 'FG-010001',
          'name': 'Fine White Salt 1kg',
          'category': 'Finished goods',
          'base_unit': 'Packet',
          'conversion_description': '1 cotton = 10 packets = 10 kg',
          'current_stock': -200.0,
          'average_cost': 92.20,
        },
        {
          'code': 'RAW-PINK',
          'name': 'Raw Pink Salt',
          'category': 'Raw salt',
          'base_unit': 'Kilogram',
          'conversion_description': '1 tonne = 1,000 kg',
          'current_stock': 84250.0,
          'average_cost': 5.10,
        },
        {
          'code': 'PKG-00800',
          'name': 'Empty 800g Printed Packet',
          'category': 'Packaging',
          'base_unit': 'Piece',
          'conversion_description': '1 bundle = 1,000 pieces',
          'current_stock': 18600.0,
          'average_cost': 2.00,
        },
        {
          'code': 'PKG-BAG50',
          'name': '50 kg Woven Bag',
          'category': 'Packaging',
          'base_unit': 'Piece',
          'conversion_description': '1 bundle = 100 pieces',
          'current_stock': 4850.0,
          'average_cost': 23.50,
        },
        {
          'code': 'PKG-COT24',
          'name': 'Outer Cotton 24 pack',
          'category': 'Packaging',
          'base_unit': 'Piece',
          'conversion_description': '1 bundle = 50 pieces',
          'current_stock': 2480.0,
          'average_cost': 7.00,
        },
      ];

      for (final p in initialProducts) {
        final id = await txn.insert('products', {
          'code': p['code'],
          'name': p['name'],
          'category': p['category'],
          'base_unit': p['base_unit'],
          'conversion_description': p['conversion_description'],
          'current_stock': p['current_stock'],
          'average_cost': p['average_cost'],
          'status': 'Active',
          'created_at': now,
          'updated_at': now,
        });
        productIds[p['code'] as String] = id;

        // Opening stock movement entry
        await txn.insert('stock_movements', {
          'product_id': id,
          'movement_date': '2026-10-01',
          'reference_no': 'OP-STOCK-${p['code']}',
          'movement_type': 'Opening Balance',
          'source_id': null,
          'quantity': p['current_stock'],
          'unit_cost': p['average_cost'],
          'total_cost': (p['current_stock'] as num).toDouble() * (p['average_cost'] as num).toDouble(),
          'balance_after': p['current_stock'],
          'is_cancelled': 0,
          'created_at': now,
        });
      }

      // Fetch party IDs
      final partiesRows = await txn.query('parties', columns: ['id', 'code', 'type']);
      final partyMap = {for (var r in partiesRows) r['code'] as String: r['id'] as int};

      // 3. Baseline Purchases
      if (partyMap.containsKey('SUP-0012') && productIds.containsKey('RAW-PINK')) {
        final pId = await txn.insert('purchases', {
          'purchase_no': 'PUR-08314',
          'supplier_id': partyMap['SUP-0012'],
          'purchase_date': '2026-10-26 10:18:00',
          'status': 'Active',
          'total_amount': 126000.0,
          'paid_amount': 0.0,
          'outstanding_amount': 126000.0,
          'wallet_id': null,
          'notes': 'Raw Pink Rock Salt 40MT',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('purchase_items', {
          'purchase_id': pId,
          'product_id': productIds['RAW-PINK'],
          'quantity': 24705.88,
          'unit_cost': 5.10,
          'total_cost': 126000.0,
        });
      }

      if (partyMap.containsKey('SUP-0018') && productIds.containsKey('PKG-COT24') && walletIds.containsKey('UBL Bank')) {
        final pId = await txn.insert('purchases', {
          'purchase_no': 'PUR-08313',
          'supplier_id': partyMap['SUP-0018'],
          'purchase_date': '2026-10-25 15:22:00',
          'status': 'Active',
          'total_amount': 84500.0,
          'paid_amount': 50000.0,
          'outstanding_amount': 34500.0,
          'wallet_id': walletIds['UBL Bank'],
          'notes': '10,000 Master Cartons with Anwar Brand Print',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('purchase_items', {
          'purchase_id': pId,
          'product_id': productIds['PKG-COT24'],
          'quantity': 12071.0,
          'unit_cost': 7.00,
          'total_cost': 84500.0,
        });
      }

      if (partyMap.containsKey('SUP-0024') && productIds.containsKey('PKG-BAG50') && walletIds.containsKey('Cash in Hand')) {
        final pId = await txn.insert('purchases', {
          'purchase_no': 'PUR-08312',
          'supplier_id': partyMap['SUP-0024'],
          'purchase_date': '2026-10-24 11:15:00',
          'status': 'Active',
          'total_amount': 47000.0,
          'paid_amount': 47000.0,
          'outstanding_amount': 0.0,
          'wallet_id': walletIds['Cash in Hand'],
          'notes': '2,000 PP Woven Bags (50kg)',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('purchase_items', {
          'purchase_id': pId,
          'product_id': productIds['PKG-BAG50'],
          'quantity': 2000.0,
          'unit_cost': 23.50,
          'total_cost': 47000.0,
        });
      }

      // 4. Baseline Sales
      if (partyMap.containsKey('CUS-0142') && productIds.containsKey('FG-080024') && walletIds.containsKey('EasyPaisa')) {
        final sId = await txn.insert('sales', {
          'sale_no': 'SAL-10482',
          'customer_id': partyMap['CUS-0142'],
          'sale_date': '2026-10-26 11:42:00',
          'status': 'Active',
          'total_amount': 48500.0,
          'paid_amount': 48500.0,
          'outstanding_amount': 0.0,
          'wallet_id': walletIds['EasyPaisa'],
          'notes': '50 Cartons HGM Pink Salt 800g',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('sale_items', {
          'sale_id': sId,
          'product_id': productIds['FG-080024'],
          'quantity': 635.0,
          'unit_price': 76.40,
          'total_price': 48500.0,
        });
      }

      if (partyMap.containsKey('CUS-0178') && productIds.containsKey('PKG-BAG50') && walletIds.containsKey('Cash in Hand')) {
        final sId = await txn.insert('sales', {
          'sale_no': 'SAL-10480',
          'customer_id': partyMap['CUS-0178'],
          'sale_date': '2026-10-23 16:12:00',
          'status': 'Active',
          'total_amount': 126000.0,
          'paid_amount': 40000.0,
          'outstanding_amount': 86000.0,
          'wallet_id': walletIds['Cash in Hand'],
          'notes': 'Industrial Grade Salt 50kg bags × 150',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('sale_items', {
          'sale_id': sId,
          'product_id': productIds['PKG-BAG50'],
          'quantity': 150.0,
          'unit_price': 840.0,
          'total_price': 126000.0,
        });
      }

      if (partyMap.containsKey('CUS-0098') && productIds.containsKey('FG-010001')) {
        final sId = await txn.insert('sales', {
          'sale_no': 'SAL-10479',
          'customer_id': partyMap['CUS-0098'],
          'sale_date': '2026-10-26 13:25:00',
          'status': 'Active',
          'total_amount': 68000.0,
          'paid_amount': 0.0,
          'outstanding_amount': 68000.0,
          'wallet_id': null,
          'notes': 'Fine White Salt 1kg × 70 Cartons',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('sale_items', {
          'sale_id': sId,
          'product_id': productIds['FG-010001'],
          'quantity': 737.5,
          'unit_price': 92.20,
          'total_price': 68000.0,
        });
      }

      // 5. Baseline Daily Records (Collections, Payments, Expenses, Transfers)
      if (partyMap.containsKey('CUS-0098') && walletIds.containsKey('UBL Bank')) {
        await txn.insert('daily_records', {
          'record_no': 'COL-01672',
          'record_date': '2026-10-26 09:12:00',
          'record_type': 'Customer Collection',
          'category': 'Customer collection',
          'description': 'Cheque clearing towards opening ledger balance',
          'party_id': partyMap['CUS-0098'],
          'source_wallet_id': null,
          'destination_wallet_id': walletIds['UBL Bank'],
          'amount': 32000.0,
          'status': 'Active',
          'notes': 'Verified UBL clearing',
          'created_at': now,
          'updated_at': now,
        });
      }

      if (walletIds.containsKey('Cash in Hand')) {
        await txn.insert('daily_records', {
          'record_no': 'EXP-02918',
          'record_date': '2026-10-26 09:35:00',
          'record_type': 'Expense',
          'category': 'Labour',
          'description': 'Labour • Team A daily wages',
          'party_id': null,
          'source_wallet_id': walletIds['Cash in Hand'],
          'destination_wallet_id': null,
          'amount': 7000.0,
          'status': 'Active',
          'notes': 'Labour Team A paid in cash',
          'created_at': now,
          'updated_at': now,
        });

        await txn.insert('daily_records', {
          'record_no': 'EXP-02919',
          'record_date': '2026-10-26 10:05:00',
          'record_type': 'Expense',
          'category': 'Hotel / Meals',
          'description': 'Hotel / Meals • Morning meal',
          'party_id': null,
          'source_wallet_id': walletIds['Cash in Hand'],
          'destination_wallet_id': null,
          'amount': 1000.0,
          'status': 'Active',
          'notes': 'Al-Rehman Hotel',
          'created_at': now,
          'updated_at': now,
        });
      }

      if (walletIds.containsKey('Cash in Hand') && walletIds.containsKey('EasyPaisa')) {
        await txn.insert('daily_records', {
          'record_no': 'TRF-00428',
          'record_date': '2026-10-26 12:20:00',
          'record_type': 'Wallet Transfer',
          'category': 'Wallet transfer',
          'description': 'Cash in Hand → EasyPaisa',
          'party_id': null,
          'source_wallet_id': walletIds['Cash in Hand'],
          'destination_wallet_id': walletIds['EasyPaisa'],
          'amount': 20000.0,
          'status': 'Active',
          'notes': 'Shared transfer reference',
          'created_at': now,
          'updated_at': now,
        });
      }

      // 6. Baseline Production Batches
      if (productIds.containsKey('FG-010001') && productIds.containsKey('RAW-PINK') && productIds.containsKey('PKG-00800')) {
        final bId = await txn.insert('production_batches', {
          'batch_no': 'PRD-02648',
          'batch_date': '2026-10-26',
          'shift': 'Morning',
          'finished_product_id': productIds['FG-010001'],
          'reported_qty': 300.0,
          'verified_qty': 280.0,
          'rejected_qty': 4.0,
          'unit_cost': 97.0,
          'total_cost': 27160.0,
          'status': 'Discrepancy',
          'notes': 'Fine White Salt 1kg batch discrepancy under investigation',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('production_items', {
          'batch_id': bId,
          'product_id': productIds['RAW-PINK'],
          'item_type': 'Raw Material',
          'quantity_consumed': 2800.0,
          'unit_cost': 5.10,
          'total_cost': 14280.0,
        });
        await txn.insert('production_items', {
          'batch_id': bId,
          'product_id': productIds['PKG-00800'],
          'item_type': 'Packaging',
          'quantity_consumed': 2800.0,
          'unit_cost': 2.00,
          'total_cost': 5600.0,
        });
      }

      if (productIds.containsKey('FG-080024') && productIds.containsKey('RAW-PINK') && productIds.containsKey('PKG-COT24')) {
        final bId = await txn.insert('production_batches', {
          'batch_no': 'PRD-02647',
          'batch_date': '2026-10-25',
          'shift': 'Evening',
          'finished_product_id': productIds['FG-080024'],
          'reported_qty': 1200.0,
          'verified_qty': 1200.0,
          'rejected_qty': 8.0,
          'unit_cost': 76.40,
          'total_cost': 91680.0,
          'status': 'Verified',
          'notes': 'HGM Pink Salt 800g Verified output',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('production_items', {
          'batch_id': bId,
          'product_id': productIds['RAW-PINK'],
          'item_type': 'Raw Material',
          'quantity_consumed': 9600.0,
          'unit_cost': 5.10,
          'total_cost': 48960.0,
        });
      }

      if (productIds.containsKey('PKG-BAG50') && productIds.containsKey('RAW-PINK')) {
        final bId = await txn.insert('production_batches', {
          'batch_no': 'PRD-02646',
          'batch_date': '2026-10-25',
          'shift': 'Morning',
          'finished_product_id': productIds['PKG-BAG50'],
          'reported_qty': 180.0,
          'verified_qty': 180.0,
          'rejected_qty': 0.0,
          'unit_cost': 262.0,
          'total_cost': 47160.0,
          'status': 'Verified',
          'notes': '50 kg Industrial Bag Verified output',
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('production_items', {
          'batch_id': bId,
          'product_id': productIds['RAW-PINK'],
          'item_type': 'Raw Material',
          'quantity_consumed': 9000.0,
          'unit_cost': 5.10,
          'total_cost': 45900.0,
        });
      }

      // 7. Baseline Unit Conversions
      final conversions = [
        {'product_id': null, 'from_unit': 'Tonne', 'to_unit': 'Kilogram', 'conversion_factor': 1000.0, 'description': '1 Metric Tonne = 1,000 Kilograms'},
        {'product_id': null, 'from_unit': 'Maund', 'to_unit': 'Kilogram', 'conversion_factor': 40.0, 'description': '1 Pakistani Maund (mann) = 40 Kilograms'},
        {'product_id': null, 'from_unit': 'Kilogram', 'to_unit': 'Gram', 'conversion_factor': 1000.0, 'description': '1 Kilogram = 1,000 Grams'},
        if (productIds.containsKey('FG-080024'))
          {'product_id': productIds['FG-080024'], 'from_unit': 'Cotton', 'to_unit': 'Packet', 'conversion_factor': 24.0, 'description': '1 Cotton = 24 Packets = 19.2 kg net salt'},
        if (productIds.containsKey('FG-010001'))
          {'product_id': productIds['FG-010001'], 'from_unit': 'Cotton', 'to_unit': 'Packet', 'conversion_factor': 10.0, 'description': '1 Cotton = 10 Packets = 10.0 kg net salt'},
        if (productIds.containsKey('PKG-00800'))
          {'product_id': productIds['PKG-00800'], 'from_unit': 'Bundle', 'to_unit': 'Piece', 'conversion_factor': 1000.0, 'description': '1 Bundle = 1,000 pieces'},
        if (productIds.containsKey('PKG-BAG50'))
          {'product_id': productIds['PKG-BAG50'], 'from_unit': 'Bundle', 'to_unit': 'Piece', 'conversion_factor': 100.0, 'description': '1 Bundle = 100 bags'},
        if (productIds.containsKey('PKG-COT24'))
          {'product_id': productIds['PKG-COT24'], 'from_unit': 'Bundle', 'to_unit': 'Piece', 'conversion_factor': 50.0, 'description': '1 Bundle = 50 outer cartons'},
      ];
      for (final c in conversions) {
        await txn.insert('unit_conversions', {
          'product_id': c['product_id'],
          'from_unit': c['from_unit'],
          'to_unit': c['to_unit'],
          'conversion_factor': c['conversion_factor'],
          'description': c['description'],
          'is_active': 1,
        });
      }

      // 8. Baseline Product Recipes (BOM)
      if (productIds.containsKey('FG-080024') && productIds.containsKey('RAW-PINK') && productIds.containsKey('PKG-00800') && productIds.containsKey('PKG-COT24')) {
        final rId = await txn.insert('product_recipes', {
          'finished_product_id': productIds['FG-080024'],
          'recipe_name': 'HGM Pink Salt 800g Packet',
          'version': 'v3',
          'base_output_quantity': 1.0,
          'labor_cost_per_unit': 0.90,
          'power_cost_per_unit': 1.00,
          'overhead_cost_per_unit': 0.0,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('product_recipe_items', {
          'recipe_id': rId,
          'ingredient_product_id': productIds['RAW-PINK'],
          'quantity_per_base_unit': 0.816,
          'waste_percentage': 2.0,
        });
        await txn.insert('product_recipe_items', {
          'recipe_id': rId,
          'ingredient_product_id': productIds['PKG-00800'],
          'quantity_per_base_unit': 1.0,
          'waste_percentage': 0.0,
        });
        await txn.insert('product_recipe_items', {
          'recipe_id': rId,
          'ingredient_product_id': productIds['PKG-COT24'],
          'quantity_per_base_unit': 0.04167,
          'waste_percentage': 0.0,
        });
      }

      if (productIds.containsKey('FG-010001') && productIds.containsKey('RAW-PINK') && productIds.containsKey('PKG-00800')) {
        final rId = await txn.insert('product_recipes', {
          'finished_product_id': productIds['FG-010001'],
          'recipe_name': 'Fine White Salt 1kg Packet',
          'version': 'v4',
          'base_output_quantity': 1.0,
          'labor_cost_per_unit': 0.90,
          'power_cost_per_unit': 1.00,
          'overhead_cost_per_unit': 0.0,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        await txn.insert('product_recipe_items', {
          'recipe_id': rId,
          'ingredient_product_id': productIds['RAW-PINK'],
          'quantity_per_base_unit': 1.02,
          'waste_percentage': 2.0,
        });
        await txn.insert('product_recipe_items', {
          'recipe_id': rId,
          'ingredient_product_id': productIds['PKG-00800'],
          'quantity_per_base_unit': 1.0,
          'waste_percentage': 0.0,
        });
      }
    });
  }

  /// Runs incremental, versioned, and non-destructive migrations
  Future<void> _runMigrations(Database db, int oldVersion, int newVersion) async {
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await db.transaction((txn) async {
        switch (v) {
          case 2:
            // Migration to Version 2:
            // 1. Ensure system_settings table exists
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS system_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
              );
            ''');
            // 2. Ensure schema_migrations table tracks history
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL,
                description TEXT NOT NULL
              );
            ''');
            await txn.insert('schema_migrations', {
              'version': 2,
              'applied_at': DateTime.now().toIso8601String(),
              'description': 'Added system_settings and schema_migrations tracking tables',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            // 3. Add performance indexes for dates if tables exist
            final tables = (await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table';"))
                .map((r) => r['name'] as String)
                .toSet();
            if (tables.contains('party_transactions')) {
              await txn.execute('CREATE INDEX IF NOT EXISTS idx_party_txns_date ON party_transactions(transaction_date);');
            }
            if (tables.contains('sales')) {
              await txn.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);');
            }
            if (tables.contains('purchases')) {
              await txn.execute('CREATE INDEX IF NOT EXISTS idx_purchases_date ON purchases(purchase_date);');
            }
            break;
        }
      });
    }
  }

  /// Verifies SQLite database integrity via PRAGMA integrity_check
  Future<bool> checkIntegrity() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('PRAGMA integrity_check;');
      if (rows.isEmpty) return false;
      return rows.first.values.first.toString().toLowerCase() == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Fetches a persistent key-value configuration from system_settings
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      final rows = await db.query(
        'system_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first['value'] as String?;
    } catch (_) {}
    return null;
  }

  /// Fetches all persistent configurations from system_settings
  Future<Map<String, String>> getAllSettings() async {
    try {
      final db = await database;
      final rows = await db.query('system_settings');
      final map = <String, String>{};
      for (final r in rows) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (k != null && v != null) {
          map[k] = v;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Sets a persistent key-value configuration in system_settings
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'system_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sets multiple persistent configurations in system_settings in a single transaction batch
  Future<void> setSettings(Map<String, String> entries) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final e in entries.entries) {
      batch.insert(
        'system_settings',
        {
          'key': e.key,
          'value': e.value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Closes database connection (used during restore coordination and test teardown)
  Future<void> close() async {
    if (dbPathOverride != null) {
      if (_localDatabase != null) {
        await _localDatabase!.close();
        _localDatabase = null;
      }
    } else {
      if (_sharedDatabase != null) {
        await _sharedDatabase!.close();
        _sharedDatabase = null;
      }
    }
  }
}
