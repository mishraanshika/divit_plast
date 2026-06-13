import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_services.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final DatabaseService _db = DatabaseService();
  List<AuditLog> _logs = [];
  StreamSubscription<List<AuditLog>>? _sub;
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchAuditLogs(limit: 50).listen(
      (logs) {
        if (!mounted) return;
        setState(() {
          _logs = logs;
          _offset = logs.length;
          _hasMore = logs.length >= 50;
          _loading = false;
        });
      },
      onError: (e) {
        debugPrint('Audit log stream error: $e');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    final more = await _db.getAuditLogs(limit: 10, offset: _offset);
    if (!mounted) return;
    setState(() {
      _logs.addAll(more);
      _offset += more.length;
      _hasMore = more.length >= 10;
    });
    _loadingMore = false;
  }

  Future<void> _refresh() async {
    setState(() {
      _logs.clear();
      _offset = 0;
      _hasMore = true;
    });
    _sub?.cancel();
    _sub = _db.watchAuditLogs(limit: 50).listen(
      (logs) {
        if (!mounted) return;
        setState(() {
          _logs = logs;
          _offset = logs.length;
          _hasMore = logs.length >= 50;
        });
      },
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      case 'STATUS_CHANGE':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text('No audit logs found',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _actionColor(log.action),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          log.action,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd MMM yyyy • hh:mm a')
                                            .format(log.createdAt),
                                        style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    log.tableName
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Record ID: ${log.recordId}',
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.65)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Performed By: ${log.performedByName}',
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.65)),
                                  ),
                                  if (log.newData != null) ...[
                                    const SizedBox(height: 12),
                                    ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding:
                                          const EdgeInsets.only(bottom: 8),
                                      title: const Text(
                                        'View Details',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: SelectableText(
                                            const JsonEncoder.withIndent('  ')
                                                .convert(log.newData),
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loadMore,
                            child: const Text('Load More'),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
