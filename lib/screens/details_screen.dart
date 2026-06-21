import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manufacturing_app/models/models.dart';
import 'package:manufacturing_app/services/auth_service.dart';
import 'package:manufacturing_app/services/database_services.dart';
import 'package:manufacturing_app/screens/raw_materials_screen.dart';
import 'package:manufacturing_app/screens/supply_orders_screen.dart';
import 'package:manufacturing_app/widget/text_field.dart';
import 'package:provider/provider.dart';

class DetailsScreen extends StatefulWidget {
  DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _supplierSearchController =
      TextEditingController();

  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  String _customerSearchQuery = '';
  String _supplierSearchQuery = '';

  bool _loading = true;

  StreamSubscription<List<Customer>>? _customerSubscription;
  StreamSubscription<List<Supplier>>? _supplierSubscription;

  bool get isCustomers => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _loadCustomers();

    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _subscribeCustomers();
    _subscribeSuppliers();
  }

  @override
  void dispose() {
    _customerSubscription?.cancel();
    _supplierSubscription?.cancel();
    _customerSearchController.dispose();
    _supplierSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeCustomers() {
    setState(() => _loading = true);

    _customerSubscription?.cancel();

    _customerSubscription = _databaseService.watchCustomers().listen(
      (customers) {
        if (!mounted) return;

        setState(() {
          _customers = customers;
          _loading = false;
        });
      },
      onError: (Object error) {
        debugPrint('Customer stream error: $error');

        if (!mounted) return;

        setState(() => _loading = false);
      },
    );
  }

  void _subscribeSuppliers() {
    setState(() => _loading = true);

    _supplierSubscription?.cancel();

    _supplierSubscription = _databaseService.watchSuppliers().listen(
      (suppliers) {
        if (!mounted) return;

        setState(() {
          _suppliers = suppliers;
          _loading = false;
        });
      },
      onError: (Object error) {
        debugPrint('Supplier stream error: $error');

        if (!mounted) return;

        setState(() => _loading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Details"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant),
                    bottom: BorderSide(color: cs.outlineVariant),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2196F3),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF2196F3),
                  unselectedLabelColor:
                      Theme.of(context).textTheme.bodyMedium?.color,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: "Customers"),
                    Tab(text: "Suppliers"),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _buildSearchField(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _customersTab(),
          _suppliersTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        onPressed: () {
          if (isCustomers) {
            _showCustomerForm();
          } else {
            _showSupplierForm();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
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

  Widget _buildSearchField() {
    final cs = Theme.of(context).colorScheme;
    final isCustomerTab = isCustomers;
    final controller =
        isCustomerTab ? _customerSearchController : _supplierSearchController;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onChanged: (value) {
          setState(() {
            if (isCustomerTab) {
              _customerSearchQuery = value.trim().toLowerCase();
            } else {
              _supplierSearchQuery = value.trim().toLowerCase();
            }
          });
        },
        decoration: InputDecoration(
          hintText:
              isCustomerTab ? 'Search customers' : 'Search suppliers',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    setState(() {
                      if (isCustomerTab) {
                        _customerSearchQuery = '';
                      } else {
                        _supplierSearchQuery = '';
                      }
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _customersTab() {
    final customers = _customers.where(_matchesCustomerSearch).toList();

    if (customers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCustomers,
        child: ListView(
          children: [
            const SizedBox(height: 150),
            const Icon(
              Icons.people_outline,
              size: 80,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _customerSearchQuery.isEmpty
                    ? 'No customers found'
                    : 'No matching customers found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _customerSearchQuery.isEmpty
                    ? 'Tap + to add a customer.'
                    : 'Try a different search.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          return _customerCard(customers[index]);
        },
      ),
    );
  }

  Widget _suppliersTab() {
    final suppliers = _suppliers.where(_matchesSupplierSearch).toList();

    if (suppliers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: ListView(
          children: [
            const SizedBox(height: 150),
            const Icon(
              Icons.local_shipping_outlined,
              size: 80,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _supplierSearchQuery.isEmpty
                    ? 'No suppliers found'
                    : 'No matching suppliers found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _supplierSearchQuery.isEmpty
                    ? 'Tap + to add a supplier.'
                    : 'Try a different search.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuppliers,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          return _supplierCard(suppliers[index]);
        },
      ),
    );
  }

  Widget _customerCard(Customer customer) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCustomerOrders(customer),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
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
                  const CircleAvatar(
                    radius: 22,
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _infoRow(Icons.badge_outlined, customer.gstin),
              const SizedBox(height: 10),
              _infoRow(Icons.location_on_outlined, customer.address),
              const SizedBox(height: 8),
              Text(
                'Tap to view all customer orders',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCustomerForm(customer: customer),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary.withValues(alpha: .12),
                        foregroundColor: cs.primary,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteCustomer(customer),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.error.withValues(alpha: .12),
                        foregroundColor: cs.error,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesCustomerSearch(Customer customer) {
    final query = _customerSearchQuery;
    if (query.isEmpty) return true;

    return customer.name.toLowerCase().contains(query) ||
        customer.gstin.toLowerCase().contains(query) ||
        customer.address.toLowerCase().contains(query);
  }

  bool _matchesSupplierSearch(Supplier supplier) {
    final query = _supplierSearchQuery;
    if (query.isEmpty) return true;

    return supplier.name.toLowerCase().contains(query) ||
        supplier.gstin.toLowerCase().contains(query) ||
        supplier.address.toLowerCase().contains(query);
  }

  Widget _supplierCard(Supplier supplier) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openSupplierOrders(supplier),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
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
                  const CircleAvatar(
                    radius: 22,
                    child: Icon(Icons.local_shipping_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      supplier.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _infoRow(Icons.badge_outlined, supplier.gstin),
              const SizedBox(height: 10),
              _infoRow(Icons.location_on_outlined, supplier.address),
              const SizedBox(height: 8),
              Text(
                'Tap to view all raw material orders',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showSupplierForm(supplier: supplier),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary.withValues(alpha: .12),
                        foregroundColor: cs.primary,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteSupplier(supplier),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.error.withValues(alpha: .12),
                        foregroundColor: cs.error,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCustomerOrders(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplyOrdersScreen(
          initialCustomerName: customer.name,
          lockCustomerFilter: true,
          title: customer.name,
        ),
      ),
    );
  }

  void _openSupplierOrders(Supplier supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RawMaterialsScreen(
          initialVendorName: supplier.name,
          lockVendorFilter: true,
          title: supplier.name,
        ),
      ),
    );
  }

  Future<void> _showCustomerForm({
    Customer? customer,
  }) async {
    final auth = context.read<AuthService>();

    final nameController = TextEditingController(
      text: customer?.name ?? '',
    );

    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );

    final gstinController = TextEditingController(
      text: customer?.gstin ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          customer == null ? 'New Customer' : 'Edit Customer',
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
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            AppFormField(
                              label: 'Name',
                              controller: nameController,
                              required: true,
                              errorMessage: 'Name is required',
                            ),
                            const SizedBox(height: 16),
                            AppFormField(
                              label: 'Address',
                              controller: addressController,
                              required: true,
                              errorMessage: 'Address is required',
                            ),
                            const SizedBox(height: 16),
                            AppFormField(
                              label: 'GSTIN',
                              controller: gstinController,
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
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Cancel"),
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
                                            const Color(0xFF2196F3),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }

                                        final item = Customer(
                                          id: customer?.id,
                                          name: nameController.text.trim(),
                                          address:
                                              addressController.text.trim(),
                                          gstin: gstinController.text.trim(),
                                        );

                                        try {
                                          if (customer == null) {
                                            await _databaseService
                                                .createCustomer(
                                              item,
                                              auth.currentUser!.uid,
                                            );
                                          } else {
                                            await _databaseService
                                                .updateCustomer(
                                              customer.id!,
                                              item,
                                              auth.currentUser!.uid,
                                            );
                                          }

                                          if (!mounted) return;

                                          Navigator.pop(context);
                                          _loadCustomers();
                                        } catch (e) {
                                          if (!mounted) return;

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        customer == null ? 'Create' : 'Update',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
  }

  Future<void> _showSupplierForm({
    Supplier? supplier,
  }) async {
    final auth = context.read<AuthService>();

    final nameController = TextEditingController(
      text: supplier?.name ?? '',
    );

    final addressController = TextEditingController(
      text: supplier?.address ?? '',
    );

    final gstinController = TextEditingController(
      text: supplier?.gstin ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          supplier == null ? 'New Supplier' : 'Edit Supplier',
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
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            AppFormField(
                              label: 'Name',
                              controller: nameController,
                              required: true,
                              errorMessage: 'Name is required',
                            ),
                            const SizedBox(height: 16),
                            AppFormField(
                              label: 'Address',
                              controller: addressController,
                              required: true,
                              errorMessage: 'Address is required',
                            ),
                            const SizedBox(height: 16),
                            AppFormField(
                              label: 'GSTIN',
                              controller: gstinController,
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
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Cancel"),
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
                                            const Color(0xFF2196F3),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }

                                        final item = Supplier(
                                          id: supplier?.id,
                                          name: nameController.text.trim(),
                                          address:
                                              addressController.text.trim(),
                                          gstin: gstinController.text.trim(),
                                        );

                                        try {
                                          if (supplier == null) {
                                            await _databaseService
                                                .createSupplier(
                                              item,
                                              auth.currentUser!.uid,
                                            );
                                          } else {
                                            await _databaseService
                                                .updateSupplier(
                                              supplier.id!,
                                              item,
                                              auth.currentUser!.uid,
                                            );
                                          }

                                          if (!mounted) return;

                                          Navigator.pop(context);
                                          _loadSuppliers();
                                        } catch (e) {
                                          if (!mounted) return;

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        supplier == null ? 'Create' : 'Update',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
  }

  Future<void> _deleteCustomer(
    Customer customer,
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
                'Delete Customer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text('Delete "${customer.name}"?'),
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
                  elevation: 0,
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
      await _databaseService.deleteCustomer(
        customer.id!,
        auth.currentUser!.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted'),
        ),
      );

      _loadCustomers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
        ),
      );
    }
  }

  Future<void> _deleteSupplier(
    Supplier supplier,
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
                'Delete Supplier',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text('Delete "${supplier.name}"?'),
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
                  elevation: 0,
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
      await _databaseService.deleteSupplier(
        supplier.id!,
        auth.currentUser!.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplier deleted'),
        ),
      );

      _loadSuppliers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
        ),
      );
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);

    try {
      final customers = await _databaseService.getCustomers();

      if (!mounted) return;

      setState(() {
        _customers = customers;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);

    try {
      final suppliers = await _databaseService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
