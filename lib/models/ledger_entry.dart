class LedgerEntry {
  final int? id;
  final int partyId;
  final String entryDate;
  final String referenceNo;
  final String entryType; // 'Opening Balance', 'Sale Invoice', 'Purchase Invoice', 'Payment', 'Collection', 'Return', 'Adjustment'
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;
  final bool isOpeningBalance;
  final String createdAt;

  const LedgerEntry({
    this.id,
    required this.partyId,
    required this.entryDate,
    required this.referenceNo,
    required this.entryType,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    this.runningBalance = 0.0,
    this.isOpeningBalance = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'party_id': partyId,
      'entry_date': entryDate,
      'reference_no': referenceNo.trim(),
      'entry_type': entryType,
      'description': description.trim(),
      'debit': debit,
      'credit': credit,
      'running_balance': runningBalance,
      'is_opening_balance': isOpeningBalance ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      id: map['id'] as int?,
      partyId: map['party_id'] as int,
      entryDate: map['entry_date'] as String,
      referenceNo: map['reference_no'] as String,
      entryType: map['entry_type'] as String,
      description: map['description'] as String,
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (map['running_balance'] as num?)?.toDouble() ?? 0.0,
      isOpeningBalance: (map['is_opening_balance'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  LedgerEntry copyWith({
    int? id,
    int? partyId,
    String? entryDate,
    String? referenceNo,
    String? entryType,
    String? description,
    double? debit,
    double? credit,
    double? runningBalance,
    bool? isOpeningBalance,
    String? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      entryDate: entryDate ?? this.entryDate,
      referenceNo: referenceNo ?? this.referenceNo,
      entryType: entryType ?? this.entryType,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      runningBalance: runningBalance ?? this.runningBalance,
      isOpeningBalance: isOpeningBalance ?? this.isOpeningBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
