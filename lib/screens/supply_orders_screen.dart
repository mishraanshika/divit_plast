import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manufacturing_app/widget/date_field.dart';
import 'package:manufacturing_app/widget/numeric_field.dart';
import 'package:manufacturing_app/widget/text_field.dart';
import 'package:manufacturing_app/widget/unit_field.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class SupplyOrdersScreen extends StatefulWidget {
  const SupplyOrdersScreen({
    super.key,
    this.initialCustomerName,
    this.lockCustomerFilter = false,
    this.title = 'Customers',
  });

  final String? initialCustomerName;
  final bool lockCustomerFilter;
  final String title;

  @override
  State<SupplyOrdersScreen> createState() => _SupplyOrdersScreenState();
}

class _SupplyOrdersScreenState extends State<SupplyOrdersScreen> {
  final DatabaseService _databaseService = DatabaseService();
  static const List<String> _statusOptions = [
    'Received',
    'In Progress',
    'Partially Delivered',
    'Delivered',
  ];

  List<SupplyOrder> _orders = [];
  StreamSubscription<List<SupplyOrder>>? _ordersSubscription;

  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();

  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialCustomerName;
    _searchController.text = widget.initialCustomerName ?? '';
    _subscribeOrders();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeOrders() {
    setState(() => _loading = true);
    _ordersSubscription?.cancel();
    _ordersSubscription = _databaseService
        .watchSupplyOrders(
      searchQuery: _searchQuery,
    )
        .listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _loading = false;
        });
      },
      onError: (Object error) {
        debugPrint('Supply order stream error: $error');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final orders = await _databaseService.getSupplyOrders(
        searchQuery: _searchQuery,
      );

      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
        bottom: widget.lockCustomerFilter
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search customer or PO',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = _searchController.text.trim().isEmpty
                                  ? null
                                  : _searchController.text.trim();
                            });

                            _subscribeOrders();
                          },
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: _buildBody(auth),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        onPressed: () => _showOrderForm(),
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

    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No supply orders found',
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
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(
            _orders[index],
            auth,
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    SupplyOrder order,
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              _statusBadge(order.status),
            ],
          ),
          Text(
            order.materialProduct,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.description_outlined,
            "PO: ${order.poNumber}",
          ),
          _infoRow(
            Icons.inventory_2_outlined,
            "Qty: ${order.quantity} ${order.unit}",
          ),
          _infoRow(
            Icons.calendar_today_outlined,
            "Delivery: ${DateFormat('yyyy-MM-dd').format(order.deliveryDate)}",
          ),
          const SizedBox(height: 12),
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
                onTap: () => _showStatusPicker(order),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            _statusColor(order.status).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(order.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(order.status),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.unfold_more,
                        size: 18,
                        color:
                            _statusColor(order.status).withValues(alpha: 0.7),
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
                  onPressed: () => _showOrderForm(order: order),
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
                  onPressed: () => _deleteOrder(order),
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
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
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
      case 'In Progress':
        return Colors.blue;
      case 'Partially Delivered':
        return Colors.teal;
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _infoRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Future<void> _showOrderForm({
    SupplyOrder? order,
  }) async {
    final auth = context.read<AuthService>();

    final customerController = TextEditingController(
      text: order?.customerName ?? '',
    );

    final productController = TextEditingController(
      text: order?.materialProduct ?? '',
    );

    final quantityController = TextEditingController(
      text: order?.quantity.toString() ?? '',
    );

    final unitController = TextEditingController(
      text: order?.unit ?? '',
    );

    final poController = TextEditingController(
      text: order?.poNumber ?? '',
    );

    final batchController = TextEditingController(
      text: order?.trayBatchNumber ?? '',
    );

    final billNumberController = TextEditingController(
      text: order?.billNumber ?? '',
    );

    final billAmountController = TextEditingController(
      text: order?.billAmount?.toString() ?? '',
    );

    DateTime receivedDate = order?.orderReceivedDate ?? DateTime.now();

    DateTime orderDate = order?.orderDate ?? DateTime.now();

    DateTime deliveryDate = order?.deliveryDate ?? DateTime.now();

    String status = order?.status ?? 'Received';

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
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
                              order == null
                                  ? 'New Customer Order'
                                  : 'Edit Customer Order',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
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
                              children: [
                                AppFormField(
                                  label: 'Customer Name',
                                  controller: customerController,
                                  required: true,
                                  errorMessage: 'Customer name is required',
                                ),
                                const SizedBox(height: 16),
                                AppFormField(
                                  label: 'Material/Product',
                                  controller: productController,
                                  required: true,
                                  errorMessage: 'Material/Product is required',
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
                                  label: 'PO Number',
                                  controller: poController,
                                  required: true,
                                  errorMessage: 'PO Number is required',
                                ),
                                const SizedBox(height: 16),
                                AppFormField(
                                  label: 'Tray/Batch Number',
                                  controller: batchController,
                                ),
                                const SizedBox(height: 16),
                                AppFormField(
                                  label: 'Bill Number',
                                  controller: billNumberController,
                                ),
                                const SizedBox(height: 16),
                                AppFormField(
                                  label: 'Bill Amount',
                                  controller: billAmountController,
                                  keyboardType: TextInputType.number,
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
                                  label: 'Order Received Date',
                                  date: receivedDate,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: receivedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );

                                    if (picked != null) {
                                      setDialogState(() {
                                        receivedDate = picked;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppDateField(
                                  label: 'Committed Delivery Date',
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
                                const SizedBox(height: 16),
                                Builder(builder: (ctx) {
                                  final cs = Theme.of(ctx).colorScheme;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Placed/Approved By',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: cs.outline
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock_outline,
                                                size: 16,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.45)),
                                            const SizedBox(width: 8),
                                            Text(
                                              auth.currentUser?.displayName ??
                                                  '',
                                              style: TextStyle(
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.7)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 24),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
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
                                                const Color(0xff2196F3),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            final item = SupplyOrder(
                                              id: order?.id,
                                              orderReceivedDate: receivedDate,
                                              orderDate: orderDate,
                                              customerName:
                                                  customerController.text,
                                              materialProduct:
                                                  productController.text,
                                              quantity: double.parse(
                                                quantityController.text,
                                              ),
                                              unit: unitController.text,
                                              poNumber: poController.text,
                                              trayBatchNumber:
                                                  batchController.text.isEmpty
                                                      ? null
                                                      : batchController.text,
                                              billNumber: billNumberController
                                                      .text.isEmpty
                                                  ? null
                                                  : billNumberController.text,
                                              billAmount: billAmountController
                                                      .text.isEmpty
                                                  ? null
                                                  : double.parse(
                                                      billAmountController.text,
                                                    ),
                                              deliveryDate: deliveryDate,
                                              placedByUserId:
                                                  auth.currentUser!.uid,
                                              placedByUserName: auth
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
                                              if (order == null) {
                                                await _databaseService
                                                    .createSupplyOrder(
                                                  item,
                                                  auth.currentUser!.uid,
                                                );
                                              } else {
                                                await _databaseService
                                                    .updateSupplyOrder(
                                                  order.id!,
                                                  item,
                                                  auth.currentUser!.uid,
                                                );
                                              }

                                              if (!context.mounted) return;

                                              Navigator.pop(context);
                                              _loadOrders();
                                            } catch (e) {
                                              if (!context.mounted) return;

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    e.toString(),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            order == null ? 'Create' : 'Update',
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
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

  Future<void> _showStatusPicker(SupplyOrder order) async {
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
                  final isCurrent = order.status == status;
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

    if (selected == null || selected == order.status) return;
    try {
      if (selected == 'Partially Delivered') {
        final deliveredQuantity = await _promptPartialDeliveryQuantity(
          title: order.customerName,
          subtitle: order.materialProduct,
          totalQuantity: order.quantity,
          unit: order.unit,
        );

        if (deliveredQuantity == null) return;

        await _databaseService.splitSupplyOrderForPartialDelivery(
          order,
          deliveredQuantity,
          auth.currentUser!.uid,
        );
      } else {
        await _databaseService.updateSupplyOrderStatus(
          order.id!,
          selected,
          auth.currentUser!.uid,
        );
      }

      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<double?> _promptPartialDeliveryQuantity({
    required String title,
    required String subtitle,
    required double totalQuantity,
    required String unit,
  }) async {
    final controller = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: Color(0xFF2196F3)),
              SizedBox(width: 8),
              Text(
                'Partial Delivery',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total quantity: $totalQuantity $unit',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Delivered quantity',
                    hintText: 'Enter quantity in $unit',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 110,
              height: 42,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(color: Color(0xFF2196F3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              width: 130,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final value = double.tryParse(controller.text.trim());
                  if (value == null || value <= 0 || value >= totalQuantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Enter a quantity greater than 0 and less than $totalQuantity',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, value);
                },
                child: const Text('Split Order'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOrder(
    SupplyOrder order,
  ) async {
    final auth = context.read<AuthService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Delete Order',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text('Delete order "${order.customerName}"?'),
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
                onPressed: () => Navigator.pop(
                  context,
                  false,
                ),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              width: 100,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  true,
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _databaseService.deleteSupplyOrder(
        order.id!,
        auth.currentUser!.uid,
      );

      await _loadOrders();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete order: $e',
          ),
        ),
      );
    }
  }
}
