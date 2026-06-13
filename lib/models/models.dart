// lib/models/models.dart

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String role; // Director, Co-Director, Manager
  final DateTime createdAt;
  final String? createdBy;
  final bool isDeleted;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.createdBy,
    this.isDeleted = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? 'User',
      role: json['role'] ?? 'Manager',
      createdAt: DateTime.parse(json['created_at']),
      createdBy: json['created_by'],
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role,
        'created_at': createdAt.toIso8601String(),
        'created_by': createdBy,
        'is_deleted': isDeleted,
      };
}

class RawMaterial {
  final String? id;
  final String materialName;
  final String vendorName;
  final double quantity;
  final String unit;
  final DateTime orderDate;
  final String? billNumber;
  final double? billAmount;
  final DateTime expectedDispatchDate;
  final DateTime expectedDeliveryDate;
  final String placedByUserId;
  final String placedbyUserName;
  final String enteredByUserId;
  final String enteredByUserName;
  final String
      status; // Pending, Partially Dispatched, Dispatched, Partially Received, Received
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  RawMaterial({
    this.id,
    required this.materialName,
    required this.vendorName,
    required this.quantity,
    required this.unit,
    required this.orderDate,
    this.billNumber,
    this.billAmount,
    required this.expectedDispatchDate,
    required this.expectedDeliveryDate,
    required this.placedByUserId,
    required this.placedbyUserName,
    required this.enteredByUserId,
    required this.enteredByUserName,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
  });

  factory RawMaterial.fromJson(Map<String, dynamic> json) {
    return RawMaterial(
      id: json['id'],
      materialName: json['material_name'],
      vendorName: json['vendor_name'],
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'],
      orderDate: DateTime.parse(json['order_date']),
      billNumber: json['bill_number'],
      billAmount: json['bill_amount'] != null
          ? (json['bill_amount'] as num).toDouble()
          : null,
      expectedDispatchDate: DateTime.parse(json['expected_dispatch_date']),
      expectedDeliveryDate: DateTime.parse(json['expected_delivery_date']),
      placedByUserId: json['placed_by_user_id'],
      placedbyUserName: json['placed_by_user_name'],
      enteredByUserId: json['entered_by_user_id'],
      enteredByUserName: json['entered_by_user_name'],
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'material_name': materialName,
        'vendor_name': vendorName,
        'quantity': quantity,
        'unit': unit,
        'order_date': orderDate.toIso8601String(),
        'bill_number': billNumber,
        'bill_amount': billAmount,
        'expected_dispatch_date': expectedDispatchDate.toIso8601String(),
        'expected_delivery_date': expectedDeliveryDate.toIso8601String(),
        'placed_by_user_id': placedByUserId,
        'placed_by_user_name': placedbyUserName,
        'entered_by_user_id': enteredByUserId,
        'entered_by_user_name': enteredByUserName,
        'status': status,
      };
}

class SupplyOrder {
  final String? id;
  final DateTime orderReceivedDate;
  final DateTime orderDate;
  final String customerName;
  final String materialProduct;
  final double quantity;
  final String unit;
  final String poNumber;
  final String? trayBatchNumber;
  final String? billNumber;
  final double? billAmount;
  final DateTime deliveryDate;
  final String placedByUserId;
  final String placedByUserName;
  final String enteredByUserId;
  final String enteredByUserName;
  final String
      status; // Received, In Progress, Partially Dispatched, Dispatched, Partially Delivered, Delivered
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  SupplyOrder({
    this.id,
    required this.orderReceivedDate,
    required this.orderDate,
    required this.customerName,
    required this.materialProduct,
    required this.quantity,
    required this.unit,
    required this.poNumber,
    this.trayBatchNumber,
    this.billNumber,
    this.billAmount,
    required this.deliveryDate,
    required this.placedByUserId,
    required this.placedByUserName,
    required this.enteredByUserId,
    required this.enteredByUserName,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
  });

  factory SupplyOrder.fromJson(Map<String, dynamic> json) {
    return SupplyOrder(
      id: json['id'],
      orderReceivedDate: DateTime.parse(json['order_received_date']),
      orderDate: DateTime.parse(json['order_date']),
      customerName: json['customer_name'],
      materialProduct: json['material_product'],
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'],
      poNumber: json['po_number'],
      trayBatchNumber: json['tray_batch_number'],
      billNumber: json['bill_number'],
      billAmount: json['bill_amount'] != null
          ? (json['bill_amount'] as num).toDouble()
          : null,
      deliveryDate: DateTime.parse(json['delivery_date']),
      placedByUserId: json['placed_by_user_id'],
      placedByUserName: json['placed_by_user_name'],
      enteredByUserId: json['entered_by_user_id'],
      enteredByUserName: json['entered_by_user_name'],
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_received_date': orderReceivedDate.toIso8601String(),
        'order_date': orderDate.toIso8601String(),
        'customer_name': customerName,
        'material_product': materialProduct,
        'quantity': quantity,
        'unit': unit,
        'po_number': poNumber,
        'tray_batch_number': trayBatchNumber,
        'bill_number': billNumber,
        'bill_amount': billAmount,
        'delivery_date': deliveryDate.toIso8601String(),
        'placed_by_user_id': placedByUserId,
        'placed_by_user_name': placedByUserName,
        'entered_by_user_id': enteredByUserId,
        'entered_by_user_name': enteredByUserName,
        'status': status,
      };
}

class ProductionJob {
  final String? id;
  final String productName;
  final String machineId;
  final DateTime orderReceivedDate;
  final DateTime? manufacturingStartDate;
  final String customerName;
  final double quantity;
  final String? materialUsed;
  final DateTime deliveryDate;
  final String enteredByUserId;
  final String enteredByUserName;
  final String status; // Not Started, In Progress, QC, Done
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  ProductionJob({
    this.id,
    required this.productName,
    required this.machineId,
    required this.orderReceivedDate,
    this.manufacturingStartDate,
    required this.customerName,
    required this.quantity,
    this.materialUsed,
    required this.deliveryDate,
    required this.enteredByUserId,
    required this.enteredByUserName,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
  });

  factory ProductionJob.fromJson(Map<String, dynamic> json) {
    return ProductionJob(
      id: json['id'],
      productName: json['product_name'],
      machineId: json['machine_id'],
      orderReceivedDate: DateTime.parse(json['order_received_date']),
      manufacturingStartDate: json['manufacturing_start_date'] != null
          ? DateTime.parse(json['manufacturing_start_date'])
          : null,
      customerName: json['customer_name'],
      quantity: (json['quantity'] as num).toDouble(),
      materialUsed: json['material_used'],
      deliveryDate: DateTime.parse(json['delivery_date']),
      enteredByUserId: json['entered_by_user_id'],
      enteredByUserName: json['entered_by_user_name'],
      status: json['status'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'machine_id': machineId,
        'order_received_date': orderReceivedDate.toIso8601String(),
        'manufacturing_start_date': manufacturingStartDate?.toIso8601String(),
        'customer_name': customerName,
        'quantity': quantity,
        'material_used': materialUsed,
        'delivery_date': deliveryDate.toIso8601String(),
        'entered_by_user_id': enteredByUserId,
        'entered_by_user_name': enteredByUserName,
        'status': status,
      };

  bool get isOverdue =>
      DateTime.now().isAfter(deliveryDate) && status != 'Done';
}

class Machine {
  final String? id;
  final String name;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Machine({
    this.id,
    required this.name,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'],
      name: json['name'],
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_active': isActive,
        'is_deleted': isDeleted,
      };
}

class AuditLog {
  final String id;
  final String tableName;
  final String recordId;
  final String action; // CREATE, UPDATE, DELETE
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String performedBy;
  final String performedByName;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.oldData,
    this.newData,
    required this.performedBy,
    required this.performedByName,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'].toString(),
      tableName: json['table_name'],
      recordId: json['record_id'].toString(),
      action: json['action'],
      oldData: json['old_data'] is Map
          ? Map<String, dynamic>.from(json['old_data'] as Map)
          : null,
      newData: json['new_data'] is Map
          ? Map<String, dynamic>.from(json['new_data'] as Map)
          : null,
      performedBy: json['performed_by']?.toString() ?? '',
      performedByName: json['performed_by_name'] ?? 'Unknown',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
