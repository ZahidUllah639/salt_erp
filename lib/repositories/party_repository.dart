import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_service.dart';
import '../models/party.dart';
import '../models/ledger_entry.dart';

class PartyHasTransactionsException implements Exception {
  final String message;
  PartyHasTransactionsException(this.message);
  @override
  String toString() => message;
}

class DuplicatePartyCodeException implements Exception {
  final String message;
  DuplicatePartyCodeException(this.message);
  @override
  String toString() => message;
}

class PartyRepository {
  final DatabaseService _dbService;

  PartyRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  /// Fetches all parties for a type (Customer or Supplier) with dynamic balances and filters
  Future<List<Party>> getParties({
    required String type,
    String? searchQuery,
    String? statusFilter, // 'All', 'Active', 'Archived', 'Outstanding', 'Settled'
    String? sortOption, // 'Name (A-Z)', 'Balance (Highest)', 'Recent Activity'
  }) async {
    final db = await _db;

    // Subquery or aggregation to get latest ledger entry running balance & last transaction date
    final sql = '''
      SELECT 
        p.*,
        COALESCE(latest_ledger.running_balance, 0.0) AS current_balance,
        latest_ledger.entry_date AS last_transaction_date,
        COALESCE(txn_counts.cnt, 0) AS transaction_count
      FROM parties p
      LEFT JOIN (
        SELECT ple1.party_id, ple1.running_balance, ple1.entry_date
        FROM party_ledger_entries ple1
        INNER JOIN (
          SELECT party_id, MAX(id) AS max_id
          FROM party_ledger_entries
          GROUP BY party_id
        ) ple2 ON ple1.party_id = ple2.party_id AND ple1.id = ple2.max_id
      ) latest_ledger ON p.id = latest_ledger.party_id
      LEFT JOIN (
        SELECT party_id, COUNT(*) AS cnt
        FROM party_ledger_entries
        WHERE is_opening_balance = 0
        GROUP BY party_id
      ) txn_counts ON p.id = txn_counts.party_id
      WHERE p.type = ?
    ''';

    final rows = await db.rawQuery(sql, [type]);
    var parties = rows.map((r) => Party.fromMap(r)).toList();

    // In-memory search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      parties = parties.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.code.toLowerCase().contains(q) ||
            p.phone.toLowerCase().contains(q) ||
            (p.contactPerson?.toLowerCase().contains(q) ?? false) ||
            (p.address?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Status filtering
    if (statusFilter != null && statusFilter != 'All') {
      if (statusFilter == 'Active') {
        parties = parties.where((p) => !p.isArchived).toList();
      } else if (statusFilter == 'Archived') {
        parties = parties.where((p) => p.isArchived).toList();
      } else if (statusFilter == 'Outstanding') {
        parties = parties.where((p) => !p.isArchived && p.currentBalance.abs() > 0.01).toList();
      } else if (statusFilter == 'Settled') {
        parties = parties.where((p) => !p.isArchived && p.currentBalance.abs() <= 0.01).toList();
      }
    }

    // Sorting
    if (sortOption == 'Balance (Highest)') {
      parties.sort((a, b) => b.currentBalance.abs().compareTo(a.currentBalance.abs()));
    } else if (sortOption == 'Recent Activity') {
      parties.sort((a, b) {
        final aDate = a.lastTransactionDate ?? a.createdAt;
        final bDate = b.lastTransactionDate ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    } else {
      // Name (A-Z) default
      parties.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return parties;
  }

  /// Get party by ID with current balance
  Future<Party?> getPartyById(int id) async {
    final db = await _db;
    final sql = '''
      SELECT 
        p.*,
        COALESCE(latest_ledger.running_balance, 0.0) AS current_balance,
        latest_ledger.entry_date AS last_transaction_date,
        COALESCE(txn_counts.cnt, 0) AS transaction_count
      FROM parties p
      LEFT JOIN (
        SELECT ple1.party_id, ple1.running_balance, ple1.entry_date
        FROM party_ledger_entries ple1
        INNER JOIN (
          SELECT party_id, MAX(id) AS max_id
          FROM party_ledger_entries
          GROUP BY party_id
        ) ple2 ON ple1.party_id = ple2.party_id AND ple1.id = ple2.max_id
      ) latest_ledger ON p.id = latest_ledger.party_id
      LEFT JOIN (
        SELECT party_id, COUNT(*) AS cnt
        FROM party_ledger_entries
        WHERE is_opening_balance = 0
        GROUP BY party_id
      ) txn_counts ON p.id = txn_counts.party_id
      WHERE p.id = ?
    ''';
    final rows = await db.rawQuery(sql, [id]);
    if (rows.isEmpty) return null;
    return Party.fromMap(rows.first);
  }

  /// Suggest next unique sequential code (e.g., CUS-0179 or SUP-0032)
  Future<String> generateNextCode(String type) async {
    final db = await _db;
    final prefix = type == 'Customer' ? 'CUS' : 'SUP';
    final rows = await db.rawQuery(
      "SELECT code FROM parties WHERE type = ? AND code LIKE '$prefix-%' ORDER BY id DESC LIMIT 10",
      [type],
    );

    int maxNum = 0;
    final regex = RegExp(r'\d+');
    for (final r in rows) {
      final codeStr = r['code'] as String;
      final match = regex.firstMatch(codeStr);
      if (match != null) {
        final numVal = int.tryParse(match.group(0) ?? '') ?? 0;
        if (numVal > maxNum) maxNum = numVal;
      }
    }

    final nextNum = maxNum > 0 ? maxNum + 1 : (type == 'Customer' ? 1 : 1);
    return '$prefix-${nextNum.toString().padLeft(4, '0')}';
  }

  /// Create a new party profile and write initial opening balance ledger entry
  Future<int> createParty(Party party) async {
    final db = await _db;

    // Check code uniqueness
    final existing = await db.query(
      'parties',
      where: 'code = ?',
      whereArgs: [party.code.trim()],
    );
    if (existing.isNotEmpty) {
      throw DuplicatePartyCodeException('A profile with code "${party.code}" already exists.');
    }

    return await db.transaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final map = party.toMap();
      map['created_at'] = now;
      map['updated_at'] = now;

      final partyId = await txn.insert('parties', map);

      // Write opening balance ledger entry
      final isCustomer = party.type == 'Customer';
      final opBal = party.openingBalance;
      double opDebit = 0.0;
      double opCredit = 0.0;
      double runningBal = 0.0;

      if (isCustomer) {
        if (party.openingBalanceType == 'Receivable') {
          opDebit = opBal;
          runningBal = opBal;
        } else {
          opCredit = opBal;
          runningBal = -opBal;
        }
      } else {
        if (party.openingBalanceType == 'Payable') {
          opCredit = opBal;
          runningBal = opBal;
        } else {
          opDebit = opBal;
          runningBal = -opBal;
        }
      }

      await txn.insert('party_ledger_entries', {
        'party_id': partyId,
        'entry_date': party.openingBalanceDate,
        'reference_no': 'OPB-${party.code}',
        'entry_type': 'Opening Balance',
        'description': 'Opening balance as of ${party.openingBalanceDate}',
        'debit': opDebit,
        'credit': opCredit,
        'running_balance': runningBal,
        'is_opening_balance': 1,
        'created_at': now,
      });

      return partyId;
    });
  }

  /// Update an existing party profile and safely update opening balance ledger representation
  Future<void> updateParty(Party party) async {
    if (party.id == null) throw ArgumentError('Party id cannot be null for update.');
    final db = await _db;

    // Check code uniqueness against other parties
    final duplicate = await db.query(
      'parties',
      where: 'code = ? AND id != ?',
      whereArgs: [party.code.trim(), party.id],
    );
    if (duplicate.isNotEmpty) {
      throw DuplicatePartyCodeException('Code "${party.code}" is already in use by another profile.');
    }

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final map = party.toMap();
      map['updated_at'] = now;

      await txn.update(
        'parties',
        map,
        where: 'id = ?',
        whereArgs: [party.id],
      );

      // Check if opening balance changed
      final isCustomer = party.type == 'Customer';
      final opBal = party.openingBalance;
      double opDebit = 0.0;
      double opCredit = 0.0;

      if (isCustomer) {
        if (party.openingBalanceType == 'Receivable') {
          opDebit = opBal;
        } else {
          opCredit = opBal;
        }
      } else {
        if (party.openingBalanceType == 'Payable') {
          opCredit = opBal;
        } else {
          opDebit = opBal;
        }
      }

      // Update the opening balance ledger entry
      await txn.update(
        'party_ledger_entries',
        {
          'entry_date': party.openingBalanceDate,
          'reference_no': 'OPB-${party.code}',
          'description': 'Opening balance as of ${party.openingBalanceDate}',
          'debit': opDebit,
          'credit': opCredit,
        },
        where: 'party_id = ? AND is_opening_balance = 1',
        whereArgs: [party.id],
      );

      // Recalculate all running balances for this party
      final entries = await txn.query(
        'party_ledger_entries',
        where: 'party_id = ?',
        whereArgs: [party.id],
        orderBy: 'id ASC',
      );

      double running = 0.0;
      for (final e in entries) {
        final d = (e['debit'] as num).toDouble();
        final c = (e['credit'] as num).toDouble();
        if (isCustomer) {
          running += (d - c);
        } else {
          running += (c - d);
        }
        await txn.update(
          'party_ledger_entries',
          {'running_balance': running},
          where: 'id = ?',
          whereArgs: [e['id']],
        );
      }
    });
  }

  /// Archive or Restore party
  Future<void> setArchived(int id, bool isArchived) async {
    final db = await _db;
    await db.update(
      'parties',
      {
        'is_archived': isArchived ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Safely delete profile only if it has zero commercial transactions
  Future<void> deleteParty(int id) async {
    final db = await _db;

    // Check for commercial transactions (sales, purchases, payments, collections)
    final txnCheck = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM party_ledger_entries WHERE party_id = ? AND is_opening_balance = 0',
      [id],
    );
    final count = (txnCheck.first['cnt'] as int?) ?? 0;

    final partyTxns = await db.query(
      'party_transactions',
      where: 'party_id = ?',
      whereArgs: [id],
    );

    if (count > 0 || partyTxns.isNotEmpty) {
      throw PartyHasTransactionsException(
        'Cannot permanently delete this profile because it has $count linked accounting ledger transactions. '
        'ERP accounting rules require protecting historical audit trails. You can Archive this profile instead.',
      );
    }

    // Safe to delete: remove opening balance ledger entry and party profile
    await db.transaction((txn) async {
      await txn.delete('party_ledger_entries', where: 'party_id = ?', whereArgs: [id]);
      await txn.delete('parties', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Fetch chronological ledger entries for a party
  Future<List<LedgerEntry>> getPartyLedger(int partyId) async {
    final db = await _db;
    final rows = await db.query(
      'party_ledger_entries',
      where: 'party_id = ?',
      whereArgs: [partyId],
      orderBy: 'id ASC',
    );
    return rows.map((r) => LedgerEntry.fromMap(r)).toList();
  }

  /// Fetch linked transactions for a party
  Future<List<Map<String, dynamic>>> getPartyTransactions(int partyId) async {
    final db = await _db;
    return await db.query(
      'party_transactions',
      where: 'party_id = ?',
      whereArgs: [partyId],
      orderBy: 'id DESC',
    );
  }

  /// Compute high-level directory metrics from real database rows
  Future<Map<String, dynamic>> getSummaryStats(String type) async {
    final db = await _db;
    final isCustomer = type == 'Customer';

    // 1. Total and active count
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) as total, SUM(CASE WHEN is_archived = 0 THEN 1 ELSE 0 END) as active FROM parties WHERE type = ?',
      [type],
    );
    final totalCount = (countRows.first['total'] as int?) ?? 0;
    final activeCount = (countRows.first['active'] as int?) ?? 0;

    // 2. Sum of current balances
    final balanceSql = '''
      SELECT 
        SUM(latest.running_balance) as net_balance,
        SUM(CASE WHEN latest.running_balance > 0 THEN latest.running_balance ELSE 0 END) as positive_balance
      FROM parties p
      INNER JOIN (
        SELECT ple1.party_id, ple1.running_balance
        FROM party_ledger_entries ple1
        INNER JOIN (
          SELECT party_id, MAX(id) AS max_id
          FROM party_ledger_entries
          GROUP BY party_id
        ) ple2 ON ple1.party_id = ple2.party_id AND ple1.id = ple2.max_id
      ) latest ON p.id = latest.party_id
      WHERE p.type = ? AND p.is_archived = 0
    ''';
    final balRows = await db.rawQuery(balanceSql, [type]);
    final netBalance = (balRows.first['net_balance'] as num?)?.toDouble() ?? 0.0;
    final positiveBalance = (balRows.first['positive_balance'] as num?)?.toDouble() ?? 0.0;

    // 3. Opening balances sum
    final opRows = await db.rawQuery(
      'SELECT SUM(opening_balance) as op_sum FROM parties WHERE type = ? AND is_archived = 0',
      [type],
    );
    final opSum = (opRows.first['op_sum'] as num?)?.toDouble() ?? 0.0;

    // 4. Overdue count and amount
    final overdueRows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT party_id) as overdue_cnt, SUM(outstanding_amount) as overdue_amt 
      FROM party_transactions 
      WHERE party_id IN (SELECT id FROM parties WHERE type = ?) AND status IN ('Overdue', 'Unpaid')
      ''',
      [type],
    );
    final overdueCount = (overdueRows.first['overdue_cnt'] as int?) ?? 0;
    final overdueAmount = (overdueRows.first['overdue_amt'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalCount': totalCount,
      'activeCount': activeCount,
      'totalBalance': positiveBalance > 0 ? positiveBalance : netBalance,
      'openingBalanceSum': opSum,
      'overdueCount': overdueCount,
      'overdueAmount': overdueAmount,
      'balanceLabel': isCustomer ? 'Total receivables' : 'Total payables',
    };
  }
}
