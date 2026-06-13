import 'dart:async';

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
  StreamSubscription<List<ProductionJob>>? _jobsSubscription;
  StreamSubscription<List<Machine>>? _machinesSubscription;

  bool _loading = true;

  String? _machineFilter;
  String? _statusFilter;
  String? _customerFilter;

  @override
  void initState() {
    super.initState();
    _subscribeJobs();
    _subscribeMachines();
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    _machinesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeJobs() {
    setState(() => _loading = true);
    _jobsSubscription?.cancel();
    _jobsSubscription = _databaseService
        .watchProductionJobs(
      machineFilter: _machineFilter,
      statusFilter: _statusFilter,
      customerFilter: _customerFilter,
    )
        .listen(
      (jobs) {
        if (!mounted) return;
        setState(() {
          _jobs = jobs;
          _loading = false;
        });
      },
      onError: (Object error) {
        debugPrint('Production job stream error: $error');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  void _subscribeMachines() {
    _machinesSubscription?.cancel();
    _machinesSubscription = _databaseService.watchMachines().listen(
      (machines) {
        if (!mounted) return;
        setState(() => _machines = machines);
      },
      onError: (Object error) {
        debugPrint('Machine stream error: $error');
      },
    );
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
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _machines = machines;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String getMachineName(String machineId) {
    return _machines
        .firstWhere(
          (m) => m.id == machineId,
          orElse: () => Machine(id: machineId, name: machineId),
        )
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Production'),
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
        onPressed: _showJobForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(AuthService auth) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Icon(Icons.factory_outlined, size: 80),
            SizedBox(height: 16),
            Center(child: Text('No production jobs found')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _jobs.length,
        itemBuilder: (context, index) => _buildJobCard(_jobs[index], auth),
      ),
    );
  }

  Widget _buildJobCard(ProductionJob job, AuthService auth) {
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
                  job.productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              _statusBadge(job.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Customer: ${job.customerName}',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.settings, 'Machine: ${getMachineName(job.machineId)}'),
          _infoRow(Icons.inventory_2_outlined, 'Qty: ${job.quantity}'),
          _infoRow(
            Icons.calendar_today_outlined,
            'Start: ${DateFormat('yyyy-MM-dd').format(job.orderReceivedDate)}',
          ),
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 15, color: cs.error),
              const SizedBox(width: 8),
              Text(
                'Delivery: ${DateFormat('yyyy-MM-dd').format(job.deliveryDate)}',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
              ),
            ],
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
                onTap: () => _showStatusPicker(job),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor(job.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _statusColor(job.status).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(job.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          job.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(job.status),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.unfold_more,
                        size: 18,
                        color: _statusColor(job.status).withValues(alpha: 0.7),
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
                  onPressed: () => _showJobForm(job: job),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
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
                  onPressed: () => _deleteJob(job),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Not Started':
        return Colors.blueGrey.shade600;
      case 'In Progress':
        return Colors.blue;
      case 'QC':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      default:
        return Colors.blueGrey;
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

  void _showFilterSheet() {
    final customerController =
        TextEditingController(text: _customerFilter ?? '');
    String? selectedMachine = _machineFilter;
    String? selectedStatus = _statusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
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
                              fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppDropdownField<String>(
                      label: 'Machine',
                      value: selectedMachine,
                      items: _machines
                          .map((m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(m.name),
                              ))
                          .toList(),
                      onChanged: (v) => setSheet(() => selectedMachine = v),
                    ),
                    const SizedBox(height: 16),
                    AppDropdownField<String>(
                      label: 'Status',
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(
                            value: 'Not Started', child: Text('Not Started')),
                        DropdownMenuItem(
                            value: 'In Progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'QC', child: Text('QC')),
                        DropdownMenuItem(value: 'Done', child: Text('Done')),
                      ],
                      onChanged: (v) => setSheet(() => selectedStatus = v),
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
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _machineFilter = null;
                                  _statusFilter = null;
                                  _customerFilter = null;
                                });
                                Navigator.pop(context);
                                _subscribeJobs();
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
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
                                _subscribeJobs();
                              },
                              child: const Text('Apply'),
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

  Future<void> _showJobForm({ProductionJob? job}) async {
    final auth = context.read<AuthService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final productController =
        TextEditingController(text: job?.productName ?? '');
    final customerController =
        TextEditingController(text: job?.customerName ?? '');
    final quantityController =
        TextEditingController(text: job?.quantity.toString() ?? '');
    final materialController =
        TextEditingController(text: job?.materialUsed ?? '');

    String? selectedMachine = job?.machineId;
    String status = job?.status ?? 'Not Started';
    DateTime orderReceivedDate = job?.orderReceivedDate ?? DateTime.now();
    DateTime? manufacturingStartDate = job?.manufacturingStartDate;
    DateTime deliveryDate = job?.deliveryDate ?? DateTime.now();

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
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
                              job == null
                                  ? 'New Production Job'
                                  : 'Edit Production Job',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700),
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
                                  items: _machines
                                      .map((m) => DropdownMenuItem(
                                            value: m.id,
                                            child: Text(m.name),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => selectedMachine = v),
                                ),
                                const SizedBox(height: 16),
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
                                    );
                                    if (picked != null) {
                                      setDialogState(
                                          () => orderReceivedDate = picked);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppDateField(
                                  label: 'Manufacturing Start Date',
                                  date:
                                      manufacturingStartDate ?? DateTime.now(),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: manufacturingStartDate ??
                                          DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() =>
                                          manufacturingStartDate = picked);
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
                                      setDialogState(
                                          () => deliveryDate = picked);
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
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
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
                                                const Color(0xff4CAF50),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            try {
                                              final productionJob =
                                                  ProductionJob(
                                                id: job?.id,
                                                productName:
                                                    productController.text,
                                                machineId: selectedMachine!,
                                                orderReceivedDate:
                                                    orderReceivedDate,
                                                manufacturingStartDate:
                                                    manufacturingStartDate,
                                                customerName:
                                                    customerController.text,
                                                quantity: double.parse(
                                                    quantityController.text),
                                                materialUsed: materialController
                                                        .text
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : materialController.text,
                                                deliveryDate: deliveryDate,
                                                enteredByUserId:
                                                    auth.currentUser!.uid,
                                                enteredByUserName: auth
                                                        .currentUser!
                                                        .displayName ??
                                                    '',
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

                                              if (!mounted || !context.mounted) return;
                                              Navigator.pop(context);
                                              await _loadData();
                                              if (!mounted) return;
                                              scaffoldMessenger.showSnackBar(
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
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                    content:
                                                        Text(e.toString())),
                                              );
                                            }
                                          },
                                          child: Text(job == null
                                              ? 'Create'
                                              : 'Update'),
                                        ),
                                      ),
                                    ),
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

  static const List<String> _statusOptions = [
    'Not Started',
    'In Progress',
    'QC',
    'Done',
  ];

  Future<void> _showStatusPicker(ProductionJob job) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.45),
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
                  final isCurrent = job.status == status;
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

    if (selected == null || selected == job.status) return;
    await _databaseService.updateProductionStatus(
        job.id!, selected, auth.currentUser!.uid);
    await _loadData();
  }

  Future<void> _deleteJob(ProductionJob job) async {
    final auth = context.read<AuthService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Delete Job', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Delete "${job.productName}"?',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          SizedBox(
            width: 100,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                side: const BorderSide(color: Color(0xFF2196F3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _databaseService.deleteProductionJob(
          job.id!, auth.currentUser!.uid);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Job deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
