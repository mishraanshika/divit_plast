// lib/services/database_service.dart
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;
import '../models/models.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============ RAW MATERIALS ============

  Future<List<RawMaterial>> getRawMaterials({
    String? vendorFilter,
    String? materialFilter,
    String? statusFilter,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) async {
    try {
      dynamic query = _supabase.from('raw_materials').select();

      query = query.eq('is_deleted', false).order('expected_delivery_date');

      if (vendorFilter != null) query = query.eq('vendor_name', vendorFilter);
      if (materialFilter != null)
        query = query.eq('material_name', materialFilter);
      if (statusFilter != null) query = query.eq('status', statusFilter);

      final data = await query;
      return (data as List).map((e) => RawMaterial.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching raw materials: $e');
      return [];
    }
  }

  Future<RawMaterial?> getRawMaterialById(String id) async {
    try {
      final data =
          await _supabase.from('raw_materials').select().eq('id', id).single();
      return RawMaterial.fromJson(data);
    } catch (e) {
      print('Error fetching raw material: $e');
      return null;
    }
  }

  Future<String> createRawMaterial(RawMaterial material, String userId) async {
    try {
      final json = material.toJson();
      json['entered_by_user_id'] = userId;

      final response =
          await _supabase.from('raw_materials').insert(json).select().single();

      await _logAudit('raw_materials', response['id'], 'CREATE', json, userId);
      return response['id'];
    } catch (e) {
      print('Error creating raw material: $e');
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

      await _supabase
          .from('raw_materials')
          .update({...json, 'updated_at': DateTime.now().toIso8601String()}).eq(
              'id', id);

      await _logAudit('raw_materials', id, 'UPDATE', json, userId);
    } catch (e) {
      print('Error updating raw material: $e');
      rethrow;
    }
  }

  Future<void> deleteRawMaterial(String id, String userId) async {
    try {
      await _supabase.from('raw_materials').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      final oldRecord =
          await _supabase.from('raw_materials').select().eq('id', id).single();

      await _logAudit(
        'raw_materials',
        id,
        'DELETE',
        oldRecord,
        userId,
      );
    } catch (e) {
      print('Error deleting raw material: $e');
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
      print('Error updating raw material status: $e');
      rethrow;
    }
  }

  // ============ SUPPLY ORDERS ============

  Future<List<SupplyOrder>> getSupplyOrders({
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from('customer_supply_orders')
          .select()
          .eq('is_deleted', false);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.or(
          'customer_name.ilike.%$searchQuery%,po_number.ilike.%$searchQuery%',
        );
      }

      final data = await query;

      return (data as List).map((e) => SupplyOrder.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching supply orders: $e');
      return [];
    }
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
        response['id'],
        'CREATE',
        json,
        userId,
      );
      return response['id'];
    } catch (e) {
      print('Error creating supply order: $e');
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

      await _supabase
          .from('customer_supply_orders')
          .update({...json, 'updated_at': DateTime.now().toIso8601String()}).eq(
              'id', id);

      await _logAudit('customer_supply_orders', id, 'UPDATE', json, userId);
    } catch (e) {
      print('Error updating supply order: $e');
      rethrow;
    }
  }

  Future<void> deleteSupplyOrder(String id, String userId) async {
    try {
      await _supabase.from('customer_supply_orders').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      final oldRecord = await _supabase
          .from('customer_supply_orders')
          .select()
          .eq('id', id)
          .single();

      await _logAudit(
        'customer_supply_orders',
        id,
        'DELETE',
        oldRecord,
        userId,
      );
    } catch (e) {
      print('Error deleting supply order: $e');
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
      print('Error updating supply order status: $e');
      rethrow;
    }
  }

  // ============ PRODUCTION JOBS ============

  Future<List<ProductionJob>> getProductionJobs({
    String? machineFilter,
    String? statusFilter,
    String? customerFilter,
  }) async {
    try {
      dynamic query = _supabase.from('production_jobs').select();

      query = query.eq('is_deleted', false).order('delivery_date');

      if (machineFilter != null) query = query.eq('machine_id', machineFilter);
      if (statusFilter != null) query = query.eq('status', statusFilter);
      if (customerFilter != null)
        query = query.ilike('customer_name', '%$customerFilter%');

      final data = await query;
      return (data as List).map((e) => ProductionJob.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching production jobs: $e');
      return [];
    }
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
      print('Error updating production status: $e');
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
        response['id'],
        'CREATE',
        json,
        userId,
      );
      return response['id'];
    } catch (e) {
      print('Error creating production job: $e');
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

      await _supabase
          .from('production_jobs')
          .update({...json, 'updated_at': DateTime.now().toIso8601String()}).eq(
              'id', id);

      await _logAudit('production_jobs', id, 'UPDATE', json, userId);
    } catch (e) {
      print('Error updating production job: $e');
      rethrow;
    }
  }

  Future<void> deleteProductionJob(String id, String userId) async {
    try {
      await _supabase.from('production_jobs').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      final oldRecord = await _supabase
          .from('production_jobs')
          .select()
          .eq('id', id)
          .single();

      await _logAudit(
        'production_jobs',
        id,
        'DELETE',
        oldRecord,
        userId,
      );
    } catch (e) {
      print('Error deleting production job: $e');
      rethrow;
    }
  }

  // ============ MACHINES ============

  Future<List<Machine>> getMachines() async {
    try {
      final data =
          await _supabase.from('machines').select().eq('is_deleted', false);
      return (data as List).map((e) => Machine.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching machines: $e');
      return [];
    }
  }

  Future<void> createMachine(Machine machine) async {
    try {
      final response = await _supabase
          .from('machines')
          .insert({
            'name': machine.name,
            'is_active': machine.isActive,
            'is_deleted': false,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': machine.createdBy,
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
        machine.createdBy!,
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

  Future<List<User>> getUsers() async {
    try {
      final data =
          await _supabase.from('users').select().eq('is_deleted', false);
      return (data as List).map((e) => User.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // ============ DASHBOARD ============

  Future<Map<String, int>> getDashboardSummary() async {
    try {
      final rawMaterialsList = await _supabase
          .from('raw_materials')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'Pending');

      final rawMaterials = (rawMaterialsList as List).length;

      final supplyOrdersList = await _supabase
          .from('customer_supply_orders')
          .select()
          .eq('is_deleted', false)
          .eq('status', 'In Progress');
      final supplyOrders = (supplyOrdersList as List).length;

      final productionList = await _supabase
          .from('production_jobs')
          .select()
          .eq('is_deleted', false)
          .neq('status', 'Completed');

      final production = (productionList as List).length;

      final today = DateTime.now();
      final duesTodayList = await _supabase
          .from('production_jobs')
          .select()
          .eq('is_deleted', false)
          .lt('delivery_date', today.add(Duration(days: 1)).toIso8601String())
          .gt('delivery_date', today.toIso8601String());

      final duesToday = (duesTodayList as List).length;

      return {
        'rawMaterials': rawMaterials,
        'supplyOrders': supplyOrders,
        'production': production,
        'duesToday': duesToday,
      };
    } catch (e) {
      print('Error fetching dashboard summary: $e');
      return {
        'rawMaterials': 0,
        'supplyOrders': 0,
        'production': 0,
        'duesToday': 0,
      };
    }
  }

  // ============ AUDIT LOG ============

  Future<void> _logAudit(
    String tableName,
    String recordId,
    String action,
    Map<String, dynamic>? data,
    String userId,
  ) async {
    print('AUDIT CALLED: $action $tableName');
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
      print('Audit log error: $e');
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
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      print('Error fetching audit logs: $e');
      return [];
    }
  }
}
