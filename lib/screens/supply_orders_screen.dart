import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manufacturing_app/widget/date_field.dart';
import 'package:manufacturing_app/widget/numeric_field.dart';
import 'package:manufacturing_app/widget/text_field.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class SupplyOrdersScreen extends StatefulWidget {
  const SupplyOrdersScreen({super.key});

  @override
  State<SupplyOrdersScreen> createState() => _SupplyOrdersScreenState();
}

class _SupplyOrdersScreenState extends State<SupplyOrdersScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<SupplyOrder> _orders = [];

  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();

  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final orders = await _databaseService.getSupplyOrders(
        searchQuery: _searchQuery,
      );

      setState(() {
        _orders = orders;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          'Customers',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search customer or PO',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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

                      _loadOrders();
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
        backgroundColor: Colors.blue,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
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
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.description_outlined,
            "PO: ${order.poNumber}",
          ),
          _infoRow(
            Icons.inventory_2_outlined,
            "Qty: ${order.quantity}",
          ),
          _infoRow(
            Icons.calendar_today_outlined,
            "Delivery: ${DateFormat('yyyy-MM-dd').format(order.deliveryDate)}",
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Text(
            "Change Status:",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statusButton(
                  order,
                  "Pending",
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  order,
                  "In Progress",
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  order,
                  "Done",
                  Colors.green,
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
                    backgroundColor: const Color(0xffE3F2FD),
                    foregroundColor: Colors.blue,
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
                    backgroundColor: const Color(0xffFFEBEE),
                    foregroundColor: Colors.red,
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
    Color color = Colors.orange;

    if (status == "In Progress") {
      color = Colors.blue;
    }

    if (status == "Done") {
      color = Colors.green;
    }

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
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(text),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        Row(
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
                        const SizedBox(height: 24),
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
                        AppFormField(
                          label: 'Unit',
                          controller: unitController,
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
                        const SizedBox(
                          height: 16,
                        ),
                        const SizedBox(height: 16),
                        AppFormField(
                          label: 'Placed/Approved By',
                          controller: TextEditingController(
                            text: auth.currentUser?.displayName ?? '',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xffF2F2F2),
                                    foregroundColor: Colors.grey.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                    backgroundColor: const Color(0xff2196F3),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }

                                    final item = SupplyOrder(
                                      id: order?.id,
                                      orderReceivedDate: receivedDate,
                                      orderDate: orderDate,
                                      customerName: customerController.text,
                                      materialProduct: productController.text,
                                      quantity: double.parse(
                                        quantityController.text,
                                      ),
                                      unit: unitController.text,
                                      poNumber: poController.text,
                                      trayBatchNumber:
                                          batchController.text.isEmpty
                                              ? null
                                              : batchController.text,
                                      billNumber:
                                          billNumberController.text.isEmpty
                                              ? null
                                              : billNumberController.text,
                                      billAmount:
                                          billAmountController.text.isEmpty
                                              ? null
                                              : double.parse(
                                                  billAmountController.text,
                                                ),
                                      deliveryDate: deliveryDate,
                                      placedByUserId: auth.currentUser!.uid,
                                      placedByUserName:
                                          auth.currentUser!.displayName ?? '',
                                      enteredByUserId: auth.currentUser!.uid,
                                      enteredByUserName:
                                          auth.currentUser!.displayName ?? '',
                                      status: 'Pending',
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

                                      Navigator.pop(context);

                                      _loadOrders();
                                    } catch (e) {
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusButton(
    SupplyOrder order,
    String status,
    Color color,
  ) {
    final selected = order.status == status;
    final auth = Provider.of<AuthService>(
      context,
      listen: false,
    );

    return GestureDetector(
      onTap: () async {
        try {
          await _databaseService.updateSupplyOrderStatus(
            order.id!,
            status,
            auth.currentUser!.uid,
          );

          await _loadOrders();
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update status: $e',
              ),
            ),
          );
        }
      },
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            status,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePickerTile({
    required String title,
    required DateTime date,
    required Function(DateTime) onPicked,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        DateFormat(
          'dd MMM yyyy',
        ).format(date),
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (picked != null) {
          onPicked(picked);
        }
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
          backgroundColor: Colors.white,
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
          content: Text(
            'Delete order "${order.customerName}"?',
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
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
