class Party {
  final int? id;
  final String code; // e.g. "CUS-0142" or "SUP-0012"
  final String type; // 'Customer' or 'Supplier'
  final String name;
  final String? contactPerson;
  final String phone;
  final String? secondaryPhone;
  final String? address;
  final String? taxId; // NTN / STRN
  final double openingBalance;
  final String openingBalanceType; // 'Receivable' or 'Payable'
  final String openingBalanceDate; // 'YYYY-MM-DD'
  final String? notes;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  // Dynamically calculated/joined fields
  final double currentBalance;
  final String balanceDirection; // 'Receivable', 'Payable', 'Settled'
  final String? lastTransactionDate;
  final String status; // 'Active', 'Archived', 'Overdue', 'Settled'
  final int transactionCount;

  const Party({
    this.id,
    required this.code,
    required this.type,
    required this.name,
    this.contactPerson,
    required this.phone,
    this.secondaryPhone,
    this.address,
    this.taxId,
    this.openingBalance = 0.0,
    this.openingBalanceType = 'Receivable',
    required this.openingBalanceDate,
    this.notes,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.currentBalance = 0.0,
    this.balanceDirection = 'Settled',
    this.lastTransactionDate,
    this.status = 'Active',
    this.transactionCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code.trim(),
      'type': type,
      'name': name.trim(),
      'contact_person': contactPerson?.trim(),
      'phone': phone.trim(),
      'secondary_phone': secondaryPhone?.trim(),
      'address': address?.trim(),
      'tax_id': taxId?.trim(),
      'opening_balance': openingBalance,
      'opening_balance_type': openingBalanceType,
      'opening_balance_date': openingBalanceDate,
      'notes': notes?.trim(),
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Party.fromMap(Map<String, dynamic> map, {
    double currentBalance = 0.0,
    String? lastTransactionDate,
    String? computedStatus,
    int transactionCount = 0,
  }) {
    final isArchived = (map['is_archived'] as int? ?? 0) == 1;
    final bal = (map['current_balance'] != null)
        ? (map['current_balance'] as num).toDouble()
        : currentBalance;

    final type = map['type'] as String;
    String dir = 'Settled';
    if (bal.abs() > 0.001) {
      if (type == 'Customer') {
        dir = bal > 0 ? 'Receivable' : 'Payable';
      } else {
        dir = bal > 0 ? 'Payable' : 'Receivable';
      }
    }

    String finalStatus = isArchived ? 'Archived' : 'Active';
    if (!isArchived) {
      if (computedStatus != null) {
        finalStatus = computedStatus;
      } else if (bal.abs() <= 0.001) {
        finalStatus = 'Settled';
      } else if (map['status'] != null) {
        finalStatus = map['status'] as String;
      }
    }

    return Party(
      id: map['id'] as int?,
      code: map['code'] as String,
      type: type,
      name: map['name'] as String,
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String,
      secondaryPhone: map['secondary_phone'] as String?,
      address: map['address'] as String?,
      taxId: map['tax_id'] as String?,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceType: map['opening_balance_type'] as String? ?? (type == 'Customer' ? 'Receivable' : 'Payable'),
      openingBalanceDate: map['opening_balance_date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      notes: map['notes'] as String?,
      isArchived: isArchived,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      currentBalance: bal,
      balanceDirection: dir,
      lastTransactionDate: (map['last_transaction_date'] as String?) ?? lastTransactionDate,
      status: finalStatus,
      transactionCount: (map['transaction_count'] as int?) ?? transactionCount,
    );
  }

  Party copyWith({
    int? id,
    String? code,
    String? type,
    String? name,
    String? contactPerson,
    String? phone,
    String? secondaryPhone,
    String? address,
    String? taxId,
    double? openingBalance,
    String? openingBalanceType,
    String? openingBalanceDate,
    String? notes,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
    double? currentBalance,
    String? balanceDirection,
    String? lastTransactionDate,
    String? status,
    int? transactionCount,
  }) {
    return Party(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceType: openingBalanceType ?? this.openingBalanceType,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentBalance: currentBalance ?? this.currentBalance,
      balanceDirection: balanceDirection ?? this.balanceDirection,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
      status: status ?? this.status,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
