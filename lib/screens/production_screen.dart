import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manufacturing_app/widget/date_field.dart';
import 'package:manufacturing_app/widget/dropdown_field.dart';
import 'package:manufacturing_app/widget/numeric_field.dart';
import 'package:manufacturing_app/widget/text_field.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<ProductionJob> _jobs = [];
  List<Machine> _machines = [];

  bool _loading = true;

  String? _machineFilter;
  String? _statusFilter;
  String? _customerFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final jobs = await _databaseService.getProductionJobs(
        machineFilter: _machineFilter,
        statusFilter: _statusFilter,
        customerFilter: _customerFilter,
      );

      final machines = await _databaseService.getMachines();

      setState(() {
        _jobs = jobs;
        _machines = machines;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  String getMachineName(String machineId) {
    final machine = _machines.firstWhere(
      (m) => m.id == machineId,
      orElse: () => Machine(
        id: machineId,
        name: machineId,
      ),
    );

    return machine.name;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Production',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.black54),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _buildBody(auth),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        onPressed: () => _showJobForm(),
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

    if (_jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Icon(
              Icons.factory_outlined,
              size: 80,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No production jobs found',
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
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          return _buildJobCard(
            _jobs[index],
            auth,
          );
        },
      ),
    );
  }

  Widget _buildJobCard(
    ProductionJob job,
    AuthService auth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(
            color: Colors.redAccent,
            width: 4,
          ),
        ),
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
                  job.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              _statusBadge(job.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Customer: ${job.customerName}",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          _infoRow(
            Icons.settings,
            "Machine: ${getMachineName(job.machineId)}",
          ),
          _infoRow(Icons.inventory_2_outlined, "Qty: ${job.quantity}"),
          _infoRow(
            Icons.calendar_today_outlined,
            "Start: ${DateFormat('yyyy-MM-dd').format(job.orderReceivedDate)}",
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 15,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  "Delivery: ${DateFormat('yyyy-MM-dd').format(job.deliveryDate)}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                  job,
                  "Not Started",
                  Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  job,
                  "In Progress",
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  job,
                  "QC",
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusButton(
                  job,
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
                  onPressed: () => _showJobForm(job: job),
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
                  onPressed: () => _deleteJob(job),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blue,
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
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    final customerController = TextEditingController(
      text: _customerFilter ?? '',
    );

    String? selectedMachine = _machineFilter;

    String? selectedStatus = _statusFilter;

    showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                    AppDropdownField<String>(
                      label: 'Machine',
                      value: selectedMachine,
                      items: _machines.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            child: Text(m.name),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setSheet(() {
                          selectedMachine = v;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    AppDropdownField<String>(
                      label: 'Status',
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'Not Started',
                          child: Text('Not Started'),
                        ),
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'QC',
                          child: Text('QC'),
                        ),
                        DropdownMenuItem(
                          value: 'Completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (v) {
                        setSheet(() {
                          selectedStatus = v;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'Customer Name',
                      controller: customerController,
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
                                backgroundColor: const Color(
                                  0xffF2F2F2,
                                ),
                                foregroundColor: Colors.grey.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _machineFilter = null;
                                  _statusFilter = null;
                                  _customerFilter = null;
                                });

                                Navigator.pop(context);

                                _loadData();
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
                                  _machineFilter = selectedMachine;

                                  _statusFilter = selectedStatus;

                                  _customerFilter =
                                      customerController.text.trim().isEmpty
                                          ? null
                                          : customerController.text.trim();
                                });

                                Navigator.pop(context);

                                _loadData();
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

  Future<void> _showJobForm({
    ProductionJob? job,
  }) async {
    final auth = context.read<AuthService>();

    final productController = TextEditingController(
      text: job?.productName ?? '',
    );

    final customerController = TextEditingController(
      text: job?.customerName ?? '',
    );

    final quantityController = TextEditingController(
      text: job?.quantity.toString() ?? '',
    );

    final materialController = TextEditingController(
      text: job?.materialUsed ?? '',
    );

    String? selectedMachine = job?.machineId;

    String status = job?.status ?? 'Not Started';

    DateTime orderReceivedDate = job?.orderReceivedDate ?? DateTime.now();

    DateTime? manufacturingStartDate = job?.manufacturingStartDate;

    DateTime deliveryDate = job?.deliveryDate ?? DateTime.now();

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
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              job == null
                                  ? 'New Production Job'
                                  : 'Edit Production Job',
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
                          label: 'Product Name',
                          controller: productController,
                          required: true,
                          errorMessage: 'Product name is required',
                        ),
                        const SizedBox(height: 16),
                        AppDropdownField<String>(
                          label: 'Machine Name',
                          value: selectedMachine,
                          required: true,
                          errorMessage: 'Please select a machine',
                          items: _machines.map((machine) {
                            return DropdownMenuItem(
                              value: machine.id,
                              child: Text(machine.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMachine = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(
                          height: 12,
                        ),
                        AppFormField(
                          label: 'Customer Name',
                          controller: customerController,
                          required: true,
                          errorMessage: 'Customer name is required',
                        ),
                        const SizedBox(height: 16),
                        AppNumberField(
                          label: 'Quantity',
                          controller: quantityController,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        AppFormField(
                          label: 'Material Used',
                          controller: materialController,
                        ),
                        const SizedBox(height: 16),
                        AppDateField(
                          label: 'Order Received Date',
                          date: orderReceivedDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: orderReceivedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(
                                          0xFF2196F3), // blue selected date
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setDialogState(() {
                                orderReceivedDate = picked;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        AppDateField(
                          label: 'Manufacturing Start Date',
                          date: manufacturingStartDate ?? DateTime.now(),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  manufacturingStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setDialogState(() {
                                manufacturingStartDate = picked;
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
                                    backgroundColor: const Color(0xff4CAF50),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }

                                    try {
                                      final productionJob = ProductionJob(
                                        id: job?.id,
                                        productName: productController.text,
                                        machineId: selectedMachine!,
                                        orderReceivedDate: orderReceivedDate,
                                        manufacturingStartDate:
                                            manufacturingStartDate,
                                        customerName: customerController.text,
                                        quantity: double.parse(
                                          quantityController.text,
                                        ),
                                        materialUsed: materialController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : materialController.text,
                                        deliveryDate: deliveryDate,
                                        enteredByUserId: auth.currentUser!.uid,
                                        enteredByUserName:
                                            auth.currentUser!.displayName ?? '',
                                        status: status,
                                      );

                                      if (job == null) {
                                        await _databaseService
                                            .createProductionJob(
                                          productionJob,
                                          auth.currentUser!.uid,
                                        );
                                      } else {
                                        await _databaseService
                                            .updateProductionJob(
                                          job.id!,
                                          productionJob,
                                          auth.currentUser!.uid,
                                        );
                                      }

                                      if (!mounted) return;

                                      Navigator.pop(context);

                                      await _loadData();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            job == null
                                                ? 'Production job created'
                                                : 'Production job updated',
                                          ),
                                        ),
                                      );
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
                                    job == null ? 'Create' : 'Update',
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
            );
          },
        );
      },
    );
  }

  Widget _statusButton(
    ProductionJob job,
    String status,
    Color color,
  ) {
    final selected = job.status == status;
    final auth = Provider.of<AuthService>(
      context,
      listen: false,
    );

    return GestureDetector(
      onTap: () async {
        await _databaseService.updateProductionStatus(
          job.id!,
          status,
          auth.currentUser!.uid,
        );

        await _loadData();
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
        DateFormat('dd MMM yyyy').format(date),
      ),
      trailing: const Icon(
        Icons.calendar_today,
      ),
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

  Future<void> _deleteJob(
    ProductionJob job,
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
                'Delete Job',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            'Delete "${job.productName}"?',
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

    if (confirm != true) {
      return;
    }

    try {
      await _databaseService.deleteProductionJob(
        job.id!,
        auth.currentUser!.uid,
      );

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job Deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }
}
