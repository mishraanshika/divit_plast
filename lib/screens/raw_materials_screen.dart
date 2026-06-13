import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manufacturing_app/widget/date_field.dart';
import 'package:manufacturing_app/widget/date_picker.dart';
import 'package:manufacturing_app/widget/dropdown_field.dart';
import 'package:manufacturing_app/widget/numeric_field.dart';
import 'package:manufacturing_app/widget/text_field.dart';
import 'package:manufacturing_app/widget/unit_field.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  static const List<String> _statusOptions = [
    'Pending',
    'Partially Dispatched',
    'Dispatched',
    'Partially Received',
    'Received',
  ];

  List<RawMaterial> _materials = [];
  StreamSubscription<List<RawMaterial>>? _materialsSubscription;

  bool _loading = true;

  String? _vendorFilter;
  String? _materialFilter;
  String? _statusFilter;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _subscribeMaterials();
  }

  @override
  void dispose() {
    _materialsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeMaterials() {
    setState(() => _loading = true);
    _materialsSubscription?.cancel();
    _materialsSubscription = _databaseService
        .watchRawMaterials(
      vendorFilter: _vendorFilter,
      materialFilter: _materialFilter,
      statusFilter: _statusFilter,
      dateRangeStart: _startDate,
      dateRangeEnd: _endDate,
    )
        .listen(
      (materials) {
        if (!mounted) return;
        setState(() {
          _materials = materials;
          _loading = false;
        });
      },
      onError: (Object error) {
        debugPrint('Raw material stream error: $error');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadMaterials() async {
    setState(() => _loading = true);

    try {
      final materials = await _databaseService.getRawMaterials(
        vendorFilter: _vendorFilter,
        materialFilter: _materialFilter,
        statusFilter: _statusFilter,
        dateRangeStart: _startDate,
        dateRangeEnd: _endDate,
      );

      if (!mounted) return;
      setState(() {
        _materials = materials;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _loadMaterials();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _buildBody(auth),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        onPressed: () => _showMaterialForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(AuthService auth) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_materials.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No raw material orders found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Tap Add Order to create one.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _materials.length,
        itemBuilder: (context, index) {
          final item = _materials[index];

          return _buildMaterialCard(item, auth);
        },
      ),
    );
  }

  Widget _buildMaterialCard(
    RawMaterial item,
    AuthService auth,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.materialName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusBadge(item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vendor: ${item.vendorName}',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          _infoRow(
              Icons.inventory_2_outlined, "Qty: ${item.quantity} ${item.unit}"),
          const SizedBox(height: 6),
          _infoRow(
            Icons.calendar_today_outlined,
            "Dispatch: ${DateFormat('yyyy-MM-dd').format(item.expectedDispatchDate)}",
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.local_shipping_outlined,
            "Delivery: ${DateFormat('yyyy-MM-dd').format(item.expectedDeliveryDate)}",
          ),
          const SizedBox(height: 14),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showStatusPicker(item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            _statusColor(item.status).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(item.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(item.status),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.unfold_more,
                        size: 18,
                        color: _statusColor(item.status).withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showMaterialForm(material: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    foregroundColor: cs.primary,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _deleteMaterial(item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.error.withValues(alpha: 0.12),
                    foregroundColor: cs.error,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;

    color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Partially Dispatched':
        return Colors.lightBlue.shade700;
      case 'Dispatched':
        return Colors.blue;
      case 'Partially Received':
        return Colors.teal;
      case 'Received':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _infoRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
      ],
    );
  }

  Future<void> _showStatusPicker(RawMaterial item) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Change Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _statusOptions.map((status) {
                  final isCurrent = item.status == status;
                  final color = _statusColor(status);
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, status),
                    child: Container(
                      color: isCurrent
                          ? color.withValues(alpha: 0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Icon(Icons.check, color: color, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || selected == item.status) return;
    await _databaseService.updateRawMaterialStatus(
        item.id!, selected, auth.currentUser!.uid);
    _loadMaterials();
  }

  Future<void> _showMaterialForm({
    RawMaterial? material,
  }) async {
    final auth = context.read<AuthService>();

    final materialController =
        TextEditingController(text: material?.materialName ?? '');

    final vendorController =
        TextEditingController(text: material?.vendorName ?? '');

    final quantityController = TextEditingController(
      text: material?.quantity.toString() ?? '',
    );

    final unitController = TextEditingController(text: material?.unit ?? '');

    final billNumberController =
        TextEditingController(text: material?.billNumber ?? '');

    final billAmountController = TextEditingController(
      text: material?.billAmount?.toString() ?? '',
    );

    DateTime orderDate = material?.orderDate ?? DateTime.now();

    DateTime dispatchDate = material?.expectedDispatchDate ?? DateTime.now();

    DateTime deliveryDate = material?.expectedDeliveryDate ?? DateTime.now();

    String status = material?.status ?? 'Pending';

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      // ── Sticky Header ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              material == null
                                  ? 'New Material Order'
                                  : 'Edit Material Order',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      // ── Scrollable Form Body ─────────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppFormField(
                                    label: 'Material Name',
                                    controller: materialController,
                                    required: true,
                                    errorMessage: 'Material name is required',
                                  ),
                                  const SizedBox(height: 16),
                                  AppFormField(
                                    label: 'Vendor Name',
                                    controller: vendorController,
                                    required: true,
                                    errorMessage: 'Vendor name is required',
                                  ),
                                  const SizedBox(height: 16),
                                  AppNumberField(
                                    label: 'Quantity',
                                    controller: quantityController,
                                    required: true,
                                  ),
                                  const SizedBox(height: 16),
                                  AppUnitField(
                                    label: 'Unit',
                                    controller: unitController,
                                    required: true,
                                  ),
                                  const SizedBox(height: 16),
                                  AppFormField(
                                    label: 'Bill Number',
                                    controller: billNumberController,
                                  ),
                                  const SizedBox(height: 16),
                                  AppNumberField(
                                    label: 'Bill Amount',
                                    controller: billAmountController,
                                  ),
                                  const SizedBox(height: 16),
                                  AppDateField(
                                    label: 'Order Date',
                                    date: orderDate,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: orderDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );

                                      if (picked != null) {
                                        setDialogState(() {
                                          orderDate = picked;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppDateField(
                                    label: 'Expected Dispatch Date *',
                                    date: dispatchDate,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: dispatchDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );

                                      if (picked != null) {
                                        setDialogState(() {
                                          dispatchDate = picked;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppDateField(
                                    label: 'Expected Delivery Date *',
                                    date: deliveryDate,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: deliveryDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );

                                      if (picked != null) {
                                        setDialogState(() {
                                          deliveryDate = picked;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              foregroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                              elevation: 0,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xffFF9800),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              if (!formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }

                                              final item = RawMaterial(
                                                id: material?.id,
                                                materialName:
                                                    materialController.text,
                                                vendorName:
                                                    vendorController.text,
                                                quantity: double.parse(
                                                  quantityController.text,
                                                ),
                                                unit: unitController.text,
                                                orderDate: orderDate,
                                                billNumber:
                                                    billNumberController.text,
                                                billAmount: billAmountController
                                                        .text.isEmpty
                                                    ? null
                                                    : double.parse(
                                                        billAmountController
                                                            .text,
                                                      ),
                                                expectedDispatchDate:
                                                    dispatchDate,
                                                expectedDeliveryDate:
                                                    deliveryDate,
                                                placedByUserId:
                                                    auth.currentUser!.uid,
                                                placedbyUserName: auth
                                                        .currentUser!
                                                        .displayName ??
                                                    '',
                                                enteredByUserId:
                                                    auth.currentUser!.uid,
                                                enteredByUserName: auth
                                                        .currentUser!
                                                        .displayName ??
                                                    '',
                                                status: status,
                                              );

                                              try {
                                                if (material == null) {
                                                  await _databaseService
                                                      .createRawMaterial(
                                                    item,
                                                    auth.currentUser!.uid,
                                                  );
                                                } else {
                                                  await _databaseService
                                                      .updateRawMaterial(
                                                    material.id!,
                                                    item,
                                                    auth.currentUser!.uid,
                                                  );
                                                }

                                                if (!context.mounted) return;

                                                Navigator.pop(context);
                                                _loadMaterials();
                                              } catch (e) {
                                                if (!context.mounted) return;

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.toString()),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(
                                              material == null
                                                  ? 'Create'
                                                  : 'Update',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              )),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMaterial(
    RawMaterial item,
  ) async {
    final auth = context.read<AuthService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.blue,
              ),
              SizedBox(width: 8),
              Text(
                'Delete Order',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text('Delete "${item.materialName}" order?'),
          actionsPadding: const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20,
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            SizedBox(
              width: 100,
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(
                    color: Color(0xFF2196F3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0, // remove shadow
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _databaseService.deleteRawMaterial(
        item.id!,
        auth.currentUser!.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order deleted'),
        ),
      );

      _loadMaterials();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    }
  }

  void _showFilterSheet() {
    final vendorController = TextEditingController(
      text: _vendorFilter ?? '',
    );

    final materialController = TextEditingController(
      text: _materialFilter ?? '',
    );

    String? tempStatus = _statusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppFormField(
                      label: 'Vendor Name',
                      controller: vendorController,
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'Material Name',
                      controller: materialController,
                    ),
                    const SizedBox(height: 16),
                    AppDropdownField<String>(
                      label: 'Status',
                      value: tempStatus,
                      items: _statusOptions
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          tempStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    AppDateField(
                      label: 'Start Date',
                      date: _startDate ?? DateTime.now(),
                      onTap: () async {
                        final picked = await appDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                        );

                        if (picked != null) {
                          setSheetState(() {
                            _startDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    AppDateField(
                      label: 'End Date',
                      date: _endDate ?? DateTime.now(),
                      onTap: () async {
                        final picked = await appDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                        );

                        if (picked != null) {
                          setSheetState(() {
                            _endDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _vendorFilter = null;
                                  _materialFilter = null;
                                  _statusFilter = null;
                                  _startDate = null;
                                  _endDate = null;
                                });

                                Navigator.pop(context);

                                _subscribeMaterials();
                              },
                              child: const Text(
                                'Clear',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF2196F3,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _vendorFilter =
                                      vendorController.text.trim().isEmpty
                                          ? null
                                          : vendorController.text.trim();

                                  _materialFilter =
                                      materialController.text.trim().isEmpty
                                          ? null
                                          : materialController.text.trim();

                                  _statusFilter = tempStatus;
                                });

                                Navigator.pop(context);

                                _subscribeMaterials();
                              },
                              child: const Text(
                                'Apply',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
