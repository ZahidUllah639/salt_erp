import 'dart:convert';

/// Domain models for Anwar Salt Factory ERP transactions, ledgers, wallets, stock, and audit logs.

class Wallet {
  final int id;
  final String name;
  final String type; // 'Cash', 'Bank', 'Digital wallet'
  final double balance;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class WalletLedgerEntry {
  final int id;
  final int walletId;
  final String entryDate;
  final String referenceNo;
  final String sourceType; // 'Purchase', 'Sale', 'Payment', 'Collection', 'Expense', 'Income', 'Transfer', 'Reversal'
  final int? sourceId;
  final String description;
  final double amount;
  final String direction; // 'IN' or 'OUT'
  final double runningBalance;
  final bool isCancelled;
  final String createdAt;

  const WalletLedgerEntry({
    required this.id,
    required this.walletId,
    required this.entryDate,
    required this.referenceNo,
    required this.sourceType,
    this.sourceId,
    required this.description,
    required this.amount,
    required this.direction,
    required this.runningBalance,
    this.isCancelled = false,
    required this.createdAt,
  });

  factory WalletLedgerEntry.fromMap(Map<String, dynamic> map) {
    return WalletLedgerEntry(
      id: map['id'] as int,
      walletId: map['wallet_id'] as int,
      entryDate: map['entry_date'] as String,
      referenceNo: map['reference_no'] as String,
      sourceType: map['source_type'] as String,
      sourceId: map['source_id'] as int?,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      direction: map['direction'] as String,
      runningBalance: (map['running_balance'] as num).toDouble(),
      isCancelled: (map['is_cancelled'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}

class Product {
  final int id;
  final String code;
  final String name;
  final String category; // 'Finished goods', 'Raw salt', 'Packaging'
  final String baseUnit;
  final String? conversionDescription;
  final double currentStock;
  final double averageCost;
  final String status;
  final String createdAt;
  final String updatedAt;

  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.baseUnit,
    this.conversionDescription,
    required this.currentStock,
    required this.averageCost,
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      code: map['code'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      baseUnit: map['base_unit'] as String,
      conversionDescription: map['conversion_description'] as String?,
      currentStock: (map['current_stock'] as num).toDouble(),
      averageCost: (map['average_cost'] as num).toDouble(),
      status: map['status'] as String? ?? 'Active',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

class StockMovement {
  final int id;
  final int productId;
  final String movementDate;
  final String referenceNo;
  final String movementType; // 'Purchase', 'Sale', 'Production Consumption', 'Production Output', 'Stock Adjustment', 'Reversal'
  final int? sourceId;
  final double quantity; // positive for IN, negative for OUT
  final double unitCost;
  final double totalCost;
  final double balanceAfter;
  final bool isCancelled;
  final String createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementDate,
    required this.referenceNo,
    required this.movementType,
    this.sourceId,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    required this.balanceAfter,
    this.isCancelled = false,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      movementDate: map['movement_date'] as String,
      referenceNo: map['reference_no'] as String,
      movementType: map['movement_type'] as String,
      sourceId: map['source_id'] as int?,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      isCancelled: (map['is_cancelled'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}

class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int productId;
  final double quantity;
  final double unitCost;
  final double totalCost;

  const PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as int?,
      purchaseId: map['purchase_id'] as int,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
    };
  }
}

class Purchase {
  final int id;
  final String purchaseNo;
  final int supplierId;
  final String purchaseDate;
  final String status; // 'Active', 'Cancelled'
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final int? walletId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<PurchaseItem> items;
  final String? partyName;

  const Purchase({
    required this.id,
    required this.purchaseNo,
    required this.supplierId,
    required this.purchaseDate,
    this.status = 'Active',
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    this.walletId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.partyName,
  });

  factory Purchase.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return Purchase(
      id: map['id'] as int,
      purchaseNo: map['purchase_no'] as String,
      supplierId: map['supplier_id'] as int,
      purchaseDate: map['purchase_date'] as String,
      status: map['status'] as String? ?? 'Active',
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      outstandingAmount: (map['outstanding_amount'] as num).toDouble(),
      walletId: map['wallet_id'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      items: items,
      partyName: (map['supplier_name'] ?? map['party_name']) as String?,
    );
  }
}

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class Sale {
  final int id;
  final String saleNo;
  final int customerId;
  final String saleDate;
  final String status; // 'Active', 'Cancelled'
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final int? walletId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<SaleItem> items;
  final String? partyName;

  const Sale({
    required this.id,
    required this.saleNo,
    required this.customerId,
    required this.saleDate,
    this.status = 'Active',
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    this.walletId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.partyName,
  });

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) {
    return Sale(
      id: map['id'] as int,
      saleNo: map['sale_no'] as String,
      customerId: map['customer_id'] as int,
      saleDate: map['sale_date'] as String,
      status: map['status'] as String? ?? 'Active',
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      outstandingAmount: (map['outstanding_amount'] as num).toDouble(),
      walletId: map['wallet_id'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      items: items,
      partyName: (map['customer_name'] ?? map['party_name']) as String?,
    );
  }
}

class DailyRecord {
  final int id;
  final String recordNo;
  final String recordDate;
  final String recordType; // 'Expense', 'Income', 'Customer Collection', 'Supplier Payment', 'Wallet Transfer', 'Stock Adjustment'
  final String category;
  final String description;
  final int? partyId;
  final int? sourceWalletId;
  final int? destinationWalletId;
  final double amount;
  final String status; // 'Active', 'Cancelled'
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const DailyRecord({
    required this.id,
    required this.recordNo,
    required this.recordDate,
    required this.recordType,
    required this.category,
    required this.description,
    this.partyId,
    this.sourceWalletId,
    this.destinationWalletId,
    required this.amount,
    this.status = 'Active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyRecord.fromMap(Map<String, dynamic> map) {
    return DailyRecord(
      id: map['id'] as int,
      recordNo: map['record_no'] as String,
      recordDate: map['record_date'] as String,
      recordType: map['record_type'] as String,
      category: map['category'] as String,
      description: map['description'] as String,
      partyId: map['party_id'] as int?,
      sourceWalletId: map['source_wallet_id'] as int?,
      destinationWalletId: map['destination_wallet_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'Active',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

class ProductionItem {
  final int? id;
  final int batchId;
  final int productId;
  final String itemType; // 'Raw Material', 'Packaging'
  final double quantityConsumed;
  final double unitCost;
  final double totalCost;

  const ProductionItem({
    this.id,
    required this.batchId,
    required this.productId,
    required this.itemType,
    required this.quantityConsumed,
    required this.unitCost,
    required this.totalCost,
  });

  factory ProductionItem.fromMap(Map<String, dynamic> map) {
    return ProductionItem(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      productId: map['product_id'] as int,
      itemType: map['item_type'] as String,
      quantityConsumed: (map['quantity_consumed'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'batch_id': batchId,
      'product_id': productId,
      'item_type': itemType,
      'quantity_consumed': quantityConsumed,
      'unit_cost': unitCost,
      'total_cost': totalCost,
    };
  }
}

class ProductionBatch {
  final int id;
  final String batchNo;
  final String batchDate;
  final String shift;
  final int finishedProductId;
  final double reportedQty;
  final double verifiedQty;
  final double rejectedQty;
  final double unitCost;
  final double totalCost;
  final String status; // 'Verified', 'Discrepancy', 'Cancelled'
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<ProductionItem> consumedItems;

  const ProductionBatch({
    required this.id,
    required this.batchNo,
    required this.batchDate,
    required this.shift,
    required this.finishedProductId,
    required this.reportedQty,
    required this.verifiedQty,
    this.rejectedQty = 0.0,
    required this.unitCost,
    required this.totalCost,
    this.status = 'Verified',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.consumedItems = const [],
  });

  factory ProductionBatch.fromMap(Map<String, dynamic> map, {List<ProductionItem> consumedItems = const []}) {
    return ProductionBatch(
      id: map['id'] as int,
      batchNo: map['batch_no'] as String,
      batchDate: map['batch_date'] as String,
      shift: map['shift'] as String,
      finishedProductId: map['finished_product_id'] as int,
      reportedQty: (map['reported_qty'] as num).toDouble(),
      verifiedQty: (map['verified_qty'] as num).toDouble(),
      rejectedQty: (map['rejected_qty'] as num? ?? 0.0).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      status: map['status'] as String? ?? 'Verified',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      consumedItems: consumedItems,
    );
  }
}

class AuditLogEntry {
  final int id;
  final String entityType;
  final int entityId;
  final String referenceNo;
  final String action; // 'CREATE', 'EDIT', 'CANCEL', 'REVERSE', 'DELETE'
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;
  final String reason;
  final String userName;
  final String createdAt;

  const AuditLogEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.referenceNo,
    required this.action,
    this.previousState,
    this.newState,
    required this.reason,
    required this.userName,
    required this.createdAt,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? prev;
    if (map['previous_state'] != null && (map['previous_state'] as String).isNotEmpty) {
      try {
        prev = jsonDecode(map['previous_state'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    Map<String, dynamic>? next;
    if (map['new_state'] != null && (map['new_state'] as String).isNotEmpty) {
      try {
        next = jsonDecode(map['new_state'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return AuditLogEntry(
      id: map['id'] as int,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int,
      referenceNo: map['reference_no'] as String,
      action: map['action'] as String,
      previousState: prev,
      newState: next,
      reason: map['reason'] as String,
      userName: map['user_name'] as String? ?? 'Adnan Khan',
      createdAt: map['created_at'] as String,
    );
  }
}

class UnitConversion {
  final int id;
  final int? productId; // null for standard global units
  final String fromUnit;
  final String toUnit;
  final double conversionFactor; // 1 fromUnit = conversionFactor toUnits
  final String? description;
  final bool isActive;

  const UnitConversion({
    required this.id,
    this.productId,
    required this.fromUnit,
    required this.toUnit,
    required this.conversionFactor,
    this.description,
    this.isActive = true,
  });

  factory UnitConversion.fromMap(Map<String, dynamic> map) {
    return UnitConversion(
      id: map['id'] as int,
      productId: map['product_id'] as int?,
      fromUnit: map['from_unit'] as String,
      toUnit: map['to_unit'] as String,
      conversionFactor: (map['conversion_factor'] as num).toDouble(),
      description: map['description'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'from_unit': fromUnit,
      'to_unit': toUnit,
      'conversion_factor': conversionFactor,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }
}

class ProductRecipeItem {
  final int? id;
  final int? recipeId;
  final int ingredientProductId;
  final String? ingredientName;
  final String? ingredientCategory;
  final double quantityPerBaseUnit;
  final double wastePercentage;

  const ProductRecipeItem({
    this.id,
    this.recipeId,
    required this.ingredientProductId,
    this.ingredientName,
    this.ingredientCategory,
    required this.quantityPerBaseUnit,
    this.wastePercentage = 0.0,
  });

  factory ProductRecipeItem.fromMap(Map<String, dynamic> map) {
    return ProductRecipeItem(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int?,
      ingredientProductId: map['ingredient_product_id'] as int,
      ingredientName: map['ingredient_name'] as String?,
      ingredientCategory: map['ingredient_category'] as String?,
      quantityPerBaseUnit: (map['quantity_per_base_unit'] as num).toDouble(),
      wastePercentage: (map['waste_percentage'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap(int recipeId) {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'ingredient_product_id': ingredientProductId,
      'quantity_per_base_unit': quantityPerBaseUnit,
      'waste_percentage': wastePercentage,
    };
  }
}

class ProductRecipe {
  final int id;
  final int finishedProductId;
  final String? finishedProductName;
  final String recipeName;
  final String version;
  final double baseOutputQuantity;
  final double laborCostPerUnit;
  final double powerCostPerUnit;
  final double overheadCostPerUnit;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final List<ProductRecipeItem> items;

  const ProductRecipe({
    required this.id,
    required this.finishedProductId,
    this.finishedProductName,
    required this.recipeName,
    this.version = 'v1',
    this.baseOutputQuantity = 1.0,
    this.laborCostPerUnit = 0.0,
    this.powerCostPerUnit = 0.0,
    this.overheadCostPerUnit = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory ProductRecipe.fromMap(Map<String, dynamic> map, {List<ProductRecipeItem> items = const []}) {
    return ProductRecipe(
      id: map['id'] as int,
      finishedProductId: map['finished_product_id'] as int,
      finishedProductName: map['finished_product_name'] as String?,
      recipeName: map['recipe_name'] as String,
      version: map['version'] as String? ?? 'v1',
      baseOutputQuantity: (map['base_output_quantity'] as num? ?? 1.0).toDouble(),
      laborCostPerUnit: (map['labor_cost_per_unit'] as num? ?? 0.0).toDouble(),
      powerCostPerUnit: (map['power_cost_per_unit'] as num? ?? 0.0).toDouble(),
      overheadCostPerUnit: (map['overhead_cost_per_unit'] as num? ?? 0.0).toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      items: items,
    );
  }
}

class StockAdjustment {
  final int id;
  final String adjustmentNo;
  final int productId;
  final String adjustmentDate;
  final String adjustmentType; // 'Physical Count Discrepancy', 'Damage', 'Spoilage', 'Revaluation'
  final double expectedQuantity;
  final double countedQuantity;
  final double differenceQuantity; // counted - expected (can be positive or negative)
  final double unitCost;
  final double totalCost;
  final String reason;
  final String operatorName;
  final String status; // 'Approved', 'Cancelled'
  final String? productName;
  final String? productCode;
  final String createdAt;
  final String updatedAt;

  const StockAdjustment({
    required this.id,
    required this.adjustmentNo,
    required this.productId,
    required this.adjustmentDate,
    required this.adjustmentType,
    required this.expectedQuantity,
    required this.countedQuantity,
    required this.differenceQuantity,
    required this.unitCost,
    required this.totalCost,
    required this.reason,
    required this.operatorName,
    this.status = 'Approved',
    this.productName,
    this.productCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as int,
      adjustmentNo: map['adjustment_no'] as String,
      productId: map['product_id'] as int,
      adjustmentDate: map['adjustment_date'] as String,
      adjustmentType: map['adjustment_type'] as String,
      expectedQuantity: (map['expected_quantity'] as num).toDouble(),
      countedQuantity: (map['counted_quantity'] as num).toDouble(),
      differenceQuantity: (map['difference_quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      reason: map['reason'] as String,
      operatorName: map['operator_name'] as String? ?? 'Warehouse Supervisor',
      status: map['status'] as String? ?? 'Approved',
      productName: map['product_name'] as String?,
      productCode: map['product_code'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

class SalesReturn {
  final int id;
  final String returnNo;
  final int? saleId;
  final int customerId;
  final int productId;
  final String returnDate;
  final double quantity;
  final double unitPrice;
  final double totalRefund;
  final int? walletId;
  final String refundType; // 'Credit Customer Ledger', 'Cash Refund'
  final String reason;
  final String status; // 'Approved', 'Cancelled'
  final String? customerName;
  final String? productName;
  final String createdAt;

  const SalesReturn({
    required this.id,
    required this.returnNo,
    this.saleId,
    required this.customerId,
    required this.productId,
    required this.returnDate,
    required this.quantity,
    required this.unitPrice,
    required this.totalRefund,
    this.walletId,
    required this.refundType,
    required this.reason,
    this.status = 'Approved',
    this.customerName,
    this.productName,
    required this.createdAt,
  });

  factory SalesReturn.fromMap(Map<String, dynamic> map) {
    return SalesReturn(
      id: map['id'] as int,
      returnNo: map['return_no'] as String,
      saleId: map['sale_id'] as int?,
      customerId: map['customer_id'] as int,
      productId: map['product_id'] as int,
      returnDate: map['return_date'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalRefund: (map['total_refund'] as num).toDouble(),
      walletId: map['wallet_id'] as int?,
      refundType: map['refund_type'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String? ?? 'Approved',
      customerName: map['customer_name'] as String?,
      productName: map['product_name'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class PurchaseReturn {
  final int id;
  final String returnNo;
  final int? purchaseId;
  final int supplierId;
  final int productId;
  final String returnDate;
  final double quantity;
  final double unitCost;
  final double totalRefund;
  final int? walletId;
  final String refundType; // 'Debit Supplier Ledger', 'Cash Received'
  final String reason;
  final String status; // 'Approved', 'Cancelled'
  final String? supplierName;
  final String? productName;
  final String createdAt;

  const PurchaseReturn({
    required this.id,
    required this.returnNo,
    this.purchaseId,
    required this.supplierId,
    required this.productId,
    required this.returnDate,
    required this.quantity,
    required this.unitCost,
    required this.totalRefund,
    this.walletId,
    required this.refundType,
    required this.reason,
    this.status = 'Approved',
    this.supplierName,
    this.productName,
    required this.createdAt,
  });

  factory PurchaseReturn.fromMap(Map<String, dynamic> map) {
    return PurchaseReturn(
      id: map['id'] as int,
      returnNo: map['return_no'] as String,
      purchaseId: map['purchase_id'] as int?,
      supplierId: map['supplier_id'] as int,
      productId: map['product_id'] as int,
      returnDate: map['return_date'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      totalRefund: (map['total_refund'] as num).toDouble(),
      walletId: map['wallet_id'] as int?,
      refundType: map['refund_type'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String? ?? 'Approved',
      supplierName: map['supplier_name'] as String?,
      productName: map['product_name'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class StockReconciliationBreakdown {
  final int productId;
  final String productCode;
  final String productName;
  final String baseUnit;
  final double openingStock;
  final double totalPurchases;
  final double totalProductionOutput;
  final double totalSalesReturns;
  final double totalSales;
  final double totalProductionConsumption;
  final double totalPurchaseReturns;
  final double totalAdjustments;
  final double calculatedStock;
  final double recordedStock;
  final bool isReconciled;

  const StockReconciliationBreakdown({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.baseUnit,
    required this.openingStock,
    required this.totalPurchases,
    required this.totalProductionOutput,
    required this.totalSalesReturns,
    required this.totalSales,
    required this.totalProductionConsumption,
    required this.totalPurchaseReturns,
    required this.totalAdjustments,
    required this.calculatedStock,
    required this.recordedStock,
    required this.isReconciled,
  });
}

class ProductionCostingSummary {
  final double estimatedProductionCost;
  final double actualProductionCost;
  final double costVariance;
  final double salesRevenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossMarginPercent;
  final int totalBatches;
  final double totalUnitsProduced;

  const ProductionCostingSummary({
    required this.estimatedProductionCost,
    required this.actualProductionCost,
    required this.costVariance,
    required this.salesRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.grossMarginPercent,
    required this.totalBatches,
    required this.totalUnitsProduced,
  });
}

class FinancialDailySummary {
  final String date;
  final double openingWalletBalance;
  final double totalCashIn;
  final double totalCashOut;
  final double netCashFlow;
  final double closingWalletBalance;
  final double salesRevenue;
  final double expensesTotal;
  final double customerCollections;
  final double supplierPayments;
  final double walletTransfersTotal;
  final int transactionCount;

  const FinancialDailySummary({
    required this.date,
    required this.openingWalletBalance,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.netCashFlow,
    required this.closingWalletBalance,
    required this.salesRevenue,
    required this.expensesTotal,
    required this.customerCollections,
    required this.supplierPayments,
    required this.walletTransfersTotal,
    required this.transactionCount,
  });
}

class FinancialMonthlySummary {
  final int year;
  final int month;
  final double openingWalletBalance;
  final double totalCashIn;
  final double totalCashOut;
  final double netCashFlow;
  final double closingWalletBalance;
  final double salesRevenue;
  final double expensesTotal;
  final double customerCollections;
  final double supplierPayments;
  final double walletTransfersTotal;
  final int totalTransactions;

  const FinancialMonthlySummary({
    required this.year,
    required this.month,
    required this.openingWalletBalance,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.netCashFlow,
    required this.closingWalletBalance,
    required this.salesRevenue,
    required this.expensesTotal,
    required this.customerCollections,
    required this.supplierPayments,
    required this.walletTransfersTotal,
    required this.totalTransactions,
  });
}

class WalletSummary {
  final int walletId;
  final String walletName;
  final String walletType;
  final double currentBalance;
  final double openingBalance;
  final double totalIn;
  final double totalOut;
  final int entryCount;

  const WalletSummary({
    required this.walletId,
    required this.walletName,
    required this.walletType,
    required this.currentBalance,
    required this.openingBalance,
    required this.totalIn,
    required this.totalOut,
    required this.entryCount,
  });
}

// =========================================================================
// THERMAL RECEIPT & PRINTING MODELS
// =========================================================================

class ReceiptLineItem {
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;

  const ReceiptLineItem({
    required this.description,
    required this.quantity,
    this.unit = '',
    required this.unitPrice,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'total_amount': totalAmount,
  };
}

class ReceiptData {
  final String title;
  final String referenceNo;
  final String dateTime;
  final String? partyLabel;
  final String? partyName;
  final String? partyPhone;
  final String? partyBalance;
  final String? paymentMethod;
  final List<ReceiptLineItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final double paidAmount;
  final double outstandingAmount;
  final String? notes;
  final String? sourceWalletName;
  final String? destinationWalletName;
  final bool isReprint;
  final String businessName;
  final String businessAddress;
  final String businessPhone;

  const ReceiptData({
    required this.title,
    required this.referenceNo,
    required this.dateTime,
    this.partyLabel,
    this.partyName,
    this.partyPhone,
    this.partyBalance,
    this.paymentMethod,
    this.items = const [],
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.grandTotal,
    this.paidAmount = 0.0,
    this.outstandingAmount = 0.0,
    this.notes,
    this.sourceWalletName,
    this.destinationWalletName,
    this.isReprint = false,
    this.businessName = 'ANWAR SALT FACTORY',
    this.businessAddress = 'Industrial Area, Khewra',
    this.businessPhone = '0300 1234567',
  });

  ReceiptData copyWith({
    String? title,
    String? referenceNo,
    String? dateTime,
    String? partyLabel,
    String? partyName,
    String? partyPhone,
    String? partyBalance,
    String? paymentMethod,
    List<ReceiptLineItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? grandTotal,
    double? paidAmount,
    double? outstandingAmount,
    String? notes,
    String? sourceWalletName,
    String? destinationWalletName,
    bool? isReprint,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) {
    return ReceiptData(
      title: title ?? this.title,
      referenceNo: referenceNo ?? this.referenceNo,
      dateTime: dateTime ?? this.dateTime,
      partyLabel: partyLabel ?? this.partyLabel,
      partyName: partyName ?? this.partyName,
      partyPhone: partyPhone ?? this.partyPhone,
      partyBalance: partyBalance ?? this.partyBalance,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      notes: notes ?? this.notes,
      sourceWalletName: sourceWalletName ?? this.sourceWalletName,
      destinationWalletName: destinationWalletName ?? this.destinationWalletName,
      isReprint: isReprint ?? this.isReprint,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
    );
  }

  static ReceiptData sampleSalesReceipt() {
    return const ReceiptData(
      title: 'SALES RECEIPT',
      referenceNo: 'SAL-10482',
      dateTime: '26 Oct 2026, 11:42 AM',
      partyLabel: 'Customer',
      partyName: 'Al-Madina Traders',
      partyPhone: '0301 2345678',
      partyBalance: 'Rs 182,500 Dr',
      paymentMethod: 'EasyPaisa',
      items: [
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
      notes: 'Thank you for your business. Prompt delivery guaranteed.',
    );
  }
}

// =========================================================================
// STRUCTURED ERP REPORT MODELS
// =========================================================================

class ReportData {
  final String title;
  final String subtitle;
  final String dateRange; // e.g. "01 Oct 2026 - 31 Oct 2026"
  final Map<String, String> summaryMetrics; // label -> value
  final List<String> columnHeaders;
  final List<List<String>> rows;
  final List<String>? totalsRow;
  final List<String> columnAlignments; // 'left', 'center', 'right'

  const ReportData({
    required this.title,
    this.subtitle = 'Official audit and operational report',
    required this.dateRange,
    this.summaryMetrics = const {},
    required this.columnHeaders,
    required this.rows,
    this.totalsRow,
    this.columnAlignments = const [],
  });
}




