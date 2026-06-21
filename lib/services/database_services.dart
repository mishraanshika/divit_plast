// lib/services/database_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../models/models.dart';
import 'company_service.dart';

class DatabaseService {
  SupabaseClient get _supabase => CompanyService.instance.client;

  // ============ RAW MATERIALS ============

  Future<List<RawMaterial>> getRawMaterials({
    String? vendorFilter,
    String? materialFilter,
    String? statusFilter,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) async {
    try {
      final data = await _supabase
          .from('raw_materials')
          .select()
          .eq('is_deleted', false)
          .order('expected_delivery_date');

      return _filterRawMaterials(
        (data as List)
            .map((e) => RawMaterial.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        vendorFilter: vendorFilter,
        materialFilter: materialFilter,
        statusFilter: statusFilter,
        dateRangeStart: dateRangeStart,
        dateRangeEnd: dateRangeEnd,
      );
    } catch (e) {
      debugPrint('Error fetching raw materials: $e');
      return [];
    }
  }

  Stream<List<RawMaterial>> watchRawMaterials({
    String? vendorFilter,
    String? materialFilter,
    String? statusFilter,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) {
    return _supabase
        .from('raw_materials')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('expected_delivery_date')
        .map(
          (rows) => _filterRawMaterials(
            rows.map(RawMaterial.fromJson).toList(),
            vendorFilter: vendorFilter,
            materialFilter: materialFilter,
            statusFilter: statusFilter,
            dateRangeStart: dateRangeStart,
            dateRangeEnd: dateRangeEnd,
          ),
        );
  }

  List<RawMaterial> _filterRawMaterials(
    List<RawMaterial> materials, {
    String? vendorFilter,
    String? materialFilter,
    String? statusFilter,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) {
    return materials.where((material) {
      return _matchesText(material.vendorName, vendorFilter) &&
          _matchesText(material.materialName, materialFilter) &&
          _matchesExact(material.status, statusFilter) &&
          _isWithinDateRange(
            material.expectedDeliveryDate,
            dateRangeStart,
            dateRangeEnd,
          );
    }).toList();
  }

  Future<RawMaterial?> getRawMaterialById(String id) async {
    try {
      final data =
          await _supabase.from('raw_materials').select().eq('id', id).single();
      return RawMaterial.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching raw material: $e');
      return null;
    }
  }

  Future<String> createRawMaterial(RawMaterial material, String userId) async {
    try {
      final json = material.toJson();
      json['entered_by_user_id'] = userId;

      final response =
          await _supabase.from('raw_materials').insert(json).select().single();

      await _logAudit(
          'raw_materials', response['id'].toString(), 'CREATE', json, userId);
      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating raw material: $e');
      rethrow;
    }
  }

  Future<void> updateRawMaterial(
    String id,
    RawMaterial material,
    String userId,
  ) async {
    try {
      final json = material.toJson();

      await _supabase.from('raw_materials').update({
        ...json,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit('raw_materials', id, 'UPDATE', json, userId);
    } catch (e) {
      debugPrint('Error updating raw material: $e');
      rethrow;
    }
  }

  Future<void> deleteRawMaterial(String id, String userId) async {
    try {
      final oldRecord =
          await _supabase.from('raw_materials').select().eq('id', id).single();

      await _supabase.from('raw_materials').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'raw_materials',
        id,
        'DELETE',
        Map<String, dynamic>.from(oldRecord),
        userId,
      );
    } catch (e) {
      debugPrint('Error deleting raw material: $e');
      rethrow;
    }
  }

  Future<void> updateRawMaterialStatus(
    String id,
    String status,
    String userId,
  ) async {
    try {
      final oldRecord = await _supabase
          .from('raw_materials')
          .select('status')
          .eq('id', id)
          .single();

      await _supabase.from('raw_materials').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'raw_materials',
        id,
        'STATUS_CHANGE',
        {
          'old_status': oldRecord['status'],
          'new_status': status,
        },
        userId,
      );
    } catch (e) {
      debugPrint('Error updating raw material status: $e');
      rethrow;
    }
  }

  Future<void> splitRawMaterialForPartialDispatch(
    RawMaterial item,
    double dispatchedQuantity,
    String userId,
  ) async {
    if (item.id == null) {
      throw Exception('Missing raw material id');
    }

    if (dispatchedQuantity <= 0 || dispatchedQuantity >= item.quantity) {
      throw Exception('Dispatched quantity must be less than total quantity');
    }

    final remainingQuantity = item.quantity - dispatchedQuantity;

    final remainingItem = RawMaterial(
      id: item.id,
      materialName: item.materialName,
      vendorName: item.vendorName,
      quantity: remainingQuantity,
      unit: item.unit,
      orderDate: item.orderDate,
      billNumber: item.billNumber,
      billAmount: item.billAmount,
      expectedDispatchDate: item.expectedDispatchDate,
      expectedDeliveryDate: item.expectedDeliveryDate,
      placedByUserId: item.placedByUserId,
      placedbyUserName: item.placedbyUserName,
      enteredByUserId: item.enteredByUserId,
      enteredByUserName: item.enteredByUserName,
      status: 'Pending',
    );

    final dispatchedItem = RawMaterial(
      materialName: item.materialName,
      vendorName: item.vendorName,
      quantity: dispatchedQuantity,
      unit: item.unit,
      orderDate: item.orderDate,
      billNumber: item.billNumber,
      billAmount: item.billAmount,
      expectedDispatchDate: item.expectedDispatchDate,
      expectedDeliveryDate: item.expectedDeliveryDate,
      placedByUserId: item.placedByUserId,
      placedbyUserName: item.placedbyUserName,
      enteredByUserId: item.enteredByUserId,
      enteredByUserName: item.enteredByUserName,
      status: 'Dispatched',
    );

    try {
      await updateRawMaterial(item.id!, remainingItem, userId);

      final createdDispatched = await _supabase
          .from('raw_materials')
          .insert({
            ...dispatchedItem.toJson(),
            'entered_by_user_id': dispatchedItem.enteredByUserId,
          })
          .select()
          .single();

      await _logAudit(
        'raw_materials',
        createdDispatched['id'].toString(),
        'CREATE',
        dispatchedItem.toJson(),
        userId,
      );

      await _logAudit(
        'raw_materials',
        item.id!,
        'SPLIT_PARTIAL_DISPATCH',
        {
          'dispatched_quantity': dispatchedQuantity,
          'remaining_quantity': remainingQuantity,
          'dispatched_order_id': createdDispatched['id'].toString(),
        },
        userId,
      );
    } catch (e) {
      debugPrint('Error splitting raw material: $e');
      rethrow;
    }
  }

  Future<List<RawMaterial>> getSupplierOrders(String supplierName) async {
    final data = await _supabase
        .from('raw_materials')
        .select()
        .eq('is_deleted', false)
        .eq('vendor_name', supplierName)
        .order('expected_delivery_date');

    return (data as List)
        .map((e) => RawMaterial.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ============ SUPPLY ORDERS ============

  Future<List<SupplyOrder>> getSupplyOrders({
    String? searchQuery,
  }) async {
    try {
      final data = await _supabase
          .from('customer_supply_orders')
          .select()
          .eq('is_deleted', false)
          .order('delivery_date');

      return _filterSupplyOrders(
        (data as List)
            .map((e) => SupplyOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        searchQuery: searchQuery,
      );
    } catch (e) {
      debugPrint('Error fetching supply orders: $e');
      return [];
    }
  }

  Stream<List<SupplyOrder>> watchSupplyOrders({
    String? searchQuery,
  }) {
    return _supabase
        .from('customer_supply_orders')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('delivery_date')
        .map(
          (rows) => _filterSupplyOrders(
            rows.map(SupplyOrder.fromJson).toList(),
            searchQuery: searchQuery,
          ),
        );
  }

  List<SupplyOrder> _filterSupplyOrders(
    List<SupplyOrder> orders, {
    String? searchQuery,
  }) {
    final query = searchQuery?.trim().toLowerCase();
    if (query == null || query.isEmpty) return orders;

    return orders.where((order) {
      return order.customerName.toLowerCase().contains(query) ||
          order.poNumber.toLowerCase().contains(query) ||
          order.materialProduct.toLowerCase().contains(query);
    }).toList();
  }

  Future<String> createSupplyOrder(SupplyOrder order, String userId) async {
    try {
      final json = order.toJson();
      json['entered_by_user_id'] = userId;

      final response = await _supabase
          .from('customer_supply_orders')
          .insert(json)
          .select()
          .single();

      await _logAudit(
        'customer_supply_orders',
        response['id'].toString(),
        'CREATE',
        json,
        userId,
      );
      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating supply order: $e');
      rethrow;
    }
  }

  Future<void> updateSupplyOrder(
    String id,
    SupplyOrder order,
    String userId,
  ) async {
    try {
      final json = order.toJson();

      await _supabase.from('customer_supply_orders').update({
        ...json,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit('customer_supply_orders', id, 'UPDATE', json, userId);
    } catch (e) {
      debugPrint('Error updating supply order: $e');
      rethrow;
    }
  }

  Future<void> deleteSupplyOrder(String id, String userId) async {
    try {
      final oldRecord = await _supabase
          .from('customer_supply_orders')
          .select()
          .eq('id', id)
          .single();

      await _supabase.from('customer_supply_orders').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'customer_supply_orders',
        id,
        'DELETE',
        Map<String, dynamic>.from(oldRecord),
        userId,
      );
    } catch (e) {
      debugPrint('Error deleting supply order: $e');
      rethrow;
    }
  }

  Future<void> updateSupplyOrderStatus(
    String id,
    String status,
    String userId,
  ) async {
    try {
      final oldRecord = await _supabase
          .from('customer_supply_orders')
          .select('status')
          .eq('id', id)
          .single();

      await _supabase.from('customer_supply_orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'customer_supply_orders',
        id,
        'STATUS_CHANGE',
        {
          'old_status': oldRecord['status'],
          'new_status': status,
        },
        userId,
      );
    } catch (e) {
      debugPrint('Error updating supply order status: $e');
      rethrow;
    }
  }

  Future<void> splitSupplyOrderForPartialDispatch(
    SupplyOrder order,
    double dispatchedQuantity,
    String userId,
  ) async {
    if (order.id == null) {
      throw Exception('Missing supply order id');
    }

    if (dispatchedQuantity <= 0 || dispatchedQuantity >= order.quantity) {
      throw Exception('Dispatched quantity must be less than total quantity');
    }

    final remainingQuantity = order.quantity - dispatchedQuantity;

    final remainingOrder = SupplyOrder(
      id: order.id,
      orderReceivedDate: order.orderReceivedDate,
      orderDate: order.orderDate,
      customerName: order.customerName,
      materialProduct: order.materialProduct,
      quantity: remainingQuantity,
      unit: order.unit,
      poNumber: order.poNumber,
      trayBatchNumber: order.trayBatchNumber,
      billNumber: order.billNumber,
      billAmount: order.billAmount,
      deliveryDate: order.deliveryDate,
      placedByUserId: order.placedByUserId,
      placedByUserName: order.placedByUserName,
      enteredByUserId: order.enteredByUserId,
      enteredByUserName: order.enteredByUserName,
      status: 'Pending',
    );

    final dispatchedOrder = SupplyOrder(
      orderReceivedDate: order.orderReceivedDate,
      orderDate: order.orderDate,
      customerName: order.customerName,
      materialProduct: order.materialProduct,
      quantity: dispatchedQuantity,
      unit: order.unit,
      poNumber: order.poNumber,
      trayBatchNumber: order.trayBatchNumber,
      billNumber: order.billNumber,
      billAmount: order.billAmount,
      deliveryDate: order.deliveryDate,
      placedByUserId: order.placedByUserId,
      placedByUserName: order.placedByUserName,
      enteredByUserId: order.enteredByUserId,
      enteredByUserName: order.enteredByUserName,
      status: 'Dispatched',
    );

    try {
      await updateSupplyOrder(order.id!, remainingOrder, userId);

      final createdDispatched = await _supabase
          .from('customer_supply_orders')
          .insert({
            ...dispatchedOrder.toJson(),
            'entered_by_user_id': dispatchedOrder.enteredByUserId,
          })
          .select()
          .single();

      await _logAudit(
        'customer_supply_orders',
        createdDispatched['id'].toString(),
        'CREATE',
        dispatchedOrder.toJson(),
        userId,
      );

      await _logAudit(
        'customer_supply_orders',
        order.id!,
        'SPLIT_PARTIAL_DISPATCH',
        {
          'dispatched_quantity': dispatchedQuantity,
          'remaining_quantity': remainingQuantity,
          'dispatched_order_id': createdDispatched['id'].toString(),
        },
        userId,
      );
    } catch (e) {
      debugPrint('Error splitting supply order: $e');
      rethrow;
    }
  }

  Future<List<SupplyOrder>> getCustomerOrders(String customerName) async {
    final data = await _supabase
        .from('customer_supply_orders')
        .select()
        .eq('is_deleted', false)
        .eq('customer_name', customerName)
        .order('delivery_date');

    return (data as List)
        .map((e) => SupplyOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ============ PRODUCTION JOBS ============

  Future<List<ProductionJob>> getProductionJobs({
    String? machineFilter,
    String? statusFilter,
    String? customerFilter,
  }) async {
    try {
      final data = await _supabase
          .from('production_jobs')
          .select()
          .eq('is_deleted', false)
          .order('delivery_date');

      return _filterProductionJobs(
        (data as List)
            .map((e) => ProductionJob.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        machineFilter: machineFilter,
        statusFilter: statusFilter,
        customerFilter: customerFilter,
      );
    } catch (e) {
      debugPrint('Error fetching production jobs: $e');
      return [];
    }
  }

  Stream<List<ProductionJob>> watchProductionJobs({
    String? machineFilter,
    String? statusFilter,
    String? customerFilter,
  }) {
    return _supabase
        .from('production_jobs')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('delivery_date')
        .map(
          (rows) => _filterProductionJobs(
            rows.map(ProductionJob.fromJson).toList(),
            machineFilter: machineFilter,
            statusFilter: statusFilter,
            customerFilter: customerFilter,
          ),
        );
  }

  List<ProductionJob> _filterProductionJobs(
    List<ProductionJob> jobs, {
    String? machineFilter,
    String? statusFilter,
    String? customerFilter,
  }) {
    return jobs.where((job) {
      return _matchesExact(job.machineId, machineFilter) &&
          _matchesExact(job.status, statusFilter) &&
          _matchesText(job.customerName, customerFilter);
    }).toList();
  }

  Future<void> updateProductionStatus(
    String id,
    String status,
    String userId,
  ) async {
    try {
      final oldRecord = await _supabase
          .from('production_jobs')
          .select('status')
          .eq('id', id)
          .single();

      await _supabase.from('production_jobs').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'production_jobs',
        id,
        'STATUS_CHANGE',
        {
          'old_status': oldRecord['status'],
          'new_status': status,
        },
        userId,
      );
    } catch (e) {
      debugPrint('Error updating production status: $e');
      rethrow;
    }
  }

  Future<String> createProductionJob(ProductionJob job, String userId) async {
    try {
      final json = job.toJson();
      json['entered_by_user_id'] = userId;

      final response = await _supabase
          .from('production_jobs')
          .insert(json)
          .select()
          .single();

      await _logAudit(
        'production_jobs',
        response['id'].toString(),
        'CREATE',
        json,
        userId,
      );
      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating production job: $e');
      rethrow;
    }
  }

  Future<void> updateProductionJob(
    String id,
    ProductionJob job,
    String userId,
  ) async {
    try {
      final json = job.toJson();

      await _supabase.from('production_jobs').update({
        ...json,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit('production_jobs', id, 'UPDATE', json, userId);
    } catch (e) {
      debugPrint('Error updating production job: $e');
      rethrow;
    }
  }

  Future<void> deleteProductionJob(String id, String userId) async {
    try {
      final oldRecord = await _supabase
          .from('production_jobs')
          .select()
          .eq('id', id)
          .single();

      await _supabase.from('production_jobs').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'production_jobs',
        id,
        'DELETE',
        Map<String, dynamic>.from(oldRecord),
        userId,
      );
    } catch (e) {
      debugPrint('Error deleting production job: $e');
      rethrow;
    }
  }

  // ============ MACHINES ============

  Future<List<Machine>> getMachines() async {
    try {
      final data = await _supabase
          .from('machines')
          .select()
          .eq('is_deleted', false)
          .order('name');
      return (data as List)
          .map((e) => Machine.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching machines: $e');
      return [];
    }
  }

  Stream<List<Machine>> watchMachines() {
    return _supabase
        .from('machines')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('name')
        .map((rows) => rows.map(Machine.fromJson).toList());
  }

  Future<void> createMachine(Machine machine) async {
    try {
      final createdBy = machine.createdBy;
      if (createdBy == null) {
        throw Exception('Missing user id for machine audit log');
      }

      final response = await _supabase
          .from('machines')
          .insert({
            'name': machine.name,
            'is_active': machine.isActive,
            'is_deleted': false,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': createdBy,
          })
          .select()
          .single();

      await _logAudit(
        'machines',
        response['id'].toString(),
        'CREATE',
        {
          'name': machine.name,
          'is_active': machine.isActive,
        },
        createdBy,
      );
    } catch (e) {
      throw Exception('Failed to create machine: $e');
    }
  }

  Future<void> updateMachine(
    String machineId,
    Machine machine,
    String userId,
  ) async {
    try {
      await _supabase.from('machines').update({
        'name': machine.name,
        'is_active': machine.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', machineId);

      await _logAudit(
        'machines',
        machineId,
        'UPDATE',
        {
          'name': machine.name,
          'is_active': machine.isActive,
        },
        userId,
      );
    } catch (e) {
      throw Exception('Failed to update machine: $e');
    }
  }

  Future<void> deleteMachine(
    String machineId,
    String userId,
  ) async {
    try {
      await _supabase.from('machines').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', machineId);

      await _logAudit(
        'machines',
        machineId,
        'DELETE',
        {
          'is_deleted': true,
        },
        userId,
      );
    } catch (e) {
      throw Exception('Failed to delete machine: $e');
    }
  }

  // ============ USERS ============

  Future<List<AppUser>> getUsers() async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('is_deleted', false)
          .order('display_name');
      return (data as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Stream<List<AppUser>> watchUsers() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('display_name')
        .map((rows) => rows.map(AppUser.fromJson).toList());
  }

  // ============ DASHBOARD ============

  Future<Map<String, int>> getDashboardSummary() async {
    try {
      final rawMaterials = await getRawMaterials();
      final supplyOrders = await getSupplyOrders();
      final productionJobs = await getProductionJobs();

      return _dashboardSummaryFromRows(
        rawMaterials: rawMaterials,
        supplyOrders: supplyOrders,
        productionJobs: productionJobs,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard summary: $e');
      return _emptyDashboardSummary();
    }
  }

  Stream<Map<String, int>> watchDashboardSummary() {
    late final StreamController<Map<String, int>> controller;
    StreamSubscription<List<RawMaterial>>? rawMaterialsSub;
    StreamSubscription<List<SupplyOrder>>? supplyOrdersSub;
    StreamSubscription<List<ProductionJob>>? productionJobsSub;

    var rawMaterials = <RawMaterial>[];
    var supplyOrders = <SupplyOrder>[];
    var productionJobs = <ProductionJob>[];
    var hasRawMaterials = false;
    var hasSupplyOrders = false;
    var hasProductionJobs = false;

    void emitIfReady() {
      if (!hasRawMaterials || !hasSupplyOrders || !hasProductionJobs) return;

      controller.add(
        _dashboardSummaryFromRows(
          rawMaterials: rawMaterials,
          supplyOrders: supplyOrders,
          productionJobs: productionJobs,
        ),
      );
    }

    controller = StreamController<Map<String, int>>(
      onListen: () {
        rawMaterialsSub = watchRawMaterials().listen(
          (value) {
            rawMaterials = value;
            hasRawMaterials = true;
            emitIfReady();
          },
          onError: controller.addError,
        );
        supplyOrdersSub = watchSupplyOrders().listen(
          (value) {
            supplyOrders = value;
            hasSupplyOrders = true;
            emitIfReady();
          },
          onError: controller.addError,
        );
        productionJobsSub = watchProductionJobs().listen(
          (value) {
            productionJobs = value;
            hasProductionJobs = true;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await rawMaterialsSub?.cancel();
        await supplyOrdersSub?.cancel();
        await productionJobsSub?.cancel();
      },
    );

    return controller.stream;
  }

  Map<String, int> _dashboardSummaryFromRows({
    required List<RawMaterial> rawMaterials,
    required List<SupplyOrder> supplyOrders,
    required List<ProductionJob> productionJobs,
  }) {
    final today = DateTime.now();

    return {
      'rawMaterials': rawMaterials.where((m) => m.status != 'Received').length,
      'supplyOrders': supplyOrders.where((o) => o.status != 'Delivered').length,
      'production': productionJobs.where((j) => j.status != 'Done').length,
      'duesToday': productionJobs
          .where(
            (j) => j.status != 'Done' && _isSameDate(j.deliveryDate, today),
          )
          .length,
    };
  }

  Map<String, int> _emptyDashboardSummary() {
    return {
      'rawMaterials': 0,
      'supplyOrders': 0,
      'production': 0,
      'duesToday': 0,
    };
  }

  // ============ AUDIT LOG ============

  Future<void> _logAudit(
    String tableName,
    String recordId,
    String action,
    Map<String, dynamic>? data,
    String userId,
  ) async {
    try {
      String? userName;

      try {
        final user = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', userId)
            .single();

        userName = user['display_name'];
      } catch (_) {}

      await _supabase.from('audit_log').insert({
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'new_data': data,
        'performed_by': userId,
        'performed_by_name': userName,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Audit log error: $e');
    }
  }

  Future<List<AuditLog>> getAuditLogs({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final data = await _supabase
          .from('audit_log')
          .select()
          .order(
            'created_at',
            ascending: false,
          )
          .range(
            offset,
            offset + limit - 1,
          );

      return (data as List)
          .map(
            (e) => AuditLog.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  Stream<List<AuditLog>> watchAuditLogs({int limit = 50}) {
    return _supabase
        .from('audit_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(AuditLog.fromJson).toList());
  }

  bool _matchesText(String value, String? query) {
    final normalizedQuery = query?.trim().toLowerCase();
    if (normalizedQuery == null || normalizedQuery.isEmpty) return true;

    return value.toLowerCase().contains(normalizedQuery);
  }

  bool _matchesExact(String value, String? query) {
    final normalizedQuery = query?.trim();
    if (normalizedQuery == null || normalizedQuery.isEmpty) return true;

    return value == normalizedQuery;
  }

  bool _isWithinDateRange(
    DateTime value,
    DateTime? start,
    DateTime? end,
  ) {
    final date = DateTime(value.year, value.month, value.day);
    final startDate =
        start == null ? null : DateTime(start.year, start.month, start.day);
    final endDate = end == null ? null : DateTime(end.year, end.month, end.day);

    if (startDate != null && date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate)) return false;
    return true;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

// ====== CUSTOMERS =======

  Future<List<Customer>> getCustomers() async {
    try {
      final data = await _supabase
          .from('customers')
          .select()
          .eq('is_deleted', false)
          .order('name');

      return (data as List)
          .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      return [];
    }
  }

  Stream<List<Customer>> watchCustomers() {
    return _supabase
        .from('customers')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('name')
        .map(
          (rows) => rows.map(Customer.fromJson).toList(),
        );
  }

  Future<Customer?> getCustomerById(String id) async {
    try {
      final data =
          await _supabase.from('customers').select().eq('id', id).single();

      return Customer.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching customer: $e');
      return null;
    }
  }

  Future<String> createCustomer(Customer customer, String userId) async {
    try {
      final json = customer.toJson();

      final response =
          await _supabase.from('customers').insert(json).select().single();

      await _logAudit(
        'customers',
        response['id'].toString(),
        'CREATE',
        json,
        userId,
      );

      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating customer: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(
    String id,
    Customer customer,
    String userId,
  ) async {
    try {
      final json = customer.toJson();

      await _supabase.from('customers').update({
        ...json,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'customers',
        id,
        'UPDATE',
        json,
        userId,
      );
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(
    String id,
    String userId,
  ) async {
    try {
      final oldRecord =
          await _supabase.from('customers').select().eq('id', id).single();

      await _supabase.from('customers').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'customers',
        id,
        'DELETE',
        Map<String, dynamic>.from(oldRecord),
        userId,
      );
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      rethrow;
    }
  }

// ====== SUPPLIERS =======

  Future<List<Supplier>> getSuppliers() async {
    try {
      final data = await _supabase
          .from('suppliers')
          .select()
          .eq('is_deleted', false)
          .order('name');

      return (data as List)
          .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
      return [];
    }
  }

  Stream<List<Supplier>> watchSuppliers() {
    return _supabase
        .from('suppliers')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('name')
        .map(
          (rows) => rows.map(Supplier.fromJson).toList(),
        );
  }

  Future<Supplier?> getSupplierById(String id) async {
    try {
      final data =
          await _supabase.from('suppliers').select().eq('id', id).single();

      return Supplier.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching supplier: $e');
      return null;
    }
  }

  Future<String> createSupplier(
    Supplier supplier,
    String userId,
  ) async {
    try {
      final json = supplier.toJson();

      final response =
          await _supabase.from('suppliers').insert(json).select().single();

      await _logAudit(
        'suppliers',
        response['id'].toString(),
        'CREATE',
        json,
        userId,
      );

      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating supplier: $e');
      rethrow;
    }
  }

  Future<void> updateSupplier(
    String id,
    Supplier supplier,
    String userId,
  ) async {
    try {
      final json = supplier.toJson();

      await _supabase.from('suppliers').update({
        ...json,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'suppliers',
        id,
        'UPDATE',
        json,
        userId,
      );
    } catch (e) {
      debugPrint('Error updating supplier: $e');
      rethrow;
    }
  }

  Future<void> deleteSupplier(
    String id,
    String userId,
  ) async {
    try {
      final oldRecord =
          await _supabase.from('suppliers').select().eq('id', id).single();

      await _supabase.from('suppliers').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await _logAudit(
        'suppliers',
        id,
        'DELETE',
        Map<String, dynamic>.from(oldRecord),
        userId,
      );
    } catch (e) {
      debugPrint('Error deleting supplier: $e');
      rethrow;
    }
  }
}
