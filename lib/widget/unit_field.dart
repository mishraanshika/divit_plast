import 'package:flutter/material.dart';

class AppUnitField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool required;

  const AppUnitField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
  });

  @override
  State<AppUnitField> createState() => _AppUnitFieldState();
}

class _AppUnitFieldState extends State<AppUnitField> {
  static const List<String> _units = [
    'kg',
    'kgs',
    'g',
    'mg',
    'tonne',
    'tonnes',
    'quintal',
    'lb',
    'oz',
    'piece',
    'pcs',
    'unit',
    'box',
    'carton',
    'bag',
    'sack',
    'roll',
    'sheet',
    'bundle',
    'tray',
    'meter',
    'cm',
    'mm',
    'litre',
    'litres',
    'ml',
    'drum',
    'barrel',
    'set',
    'pair',
    'dozen',
  ];

  Future<void> _showPicker(BuildContext context) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _UnitPickerSheet(
        units: _units,
        currentValue: widget.controller.text,
        maxHeight: screenHeight * 0.65,
      ),
    );
    if (picked != null) {
      setState(() => widget.controller.text = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = widget.controller.text;

    return FormField<String>(
      key: ValueKey(value),
      initialValue: value,
      validator: (_) {
        if (widget.required && value.isEmpty) {
          return '${widget.label} is required';
        }
        return null;
      },
      builder: (state) {
        final borderColor = state.hasError
            ? cs.error
            : value.isNotEmpty
                ? cs.primary
                : cs.outline;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.required ? '${widget.label} *' : widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: state.hasError
                    ? cs.error
                    : cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showPicker(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.isEmpty ? 'Select Unit' : value,
                        style: TextStyle(
                          fontSize: 16,
                          color: value.isEmpty
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : cs.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 4),
              Text(
                state.errorText!,
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _UnitPickerSheet extends StatefulWidget {
  final List<String> units;
  final String currentValue;
  final double maxHeight;

  const _UnitPickerSheet({
    required this.units,
    required this.currentValue,
    required this.maxHeight,
  });

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.units;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.units
          : widget.units.where((u) => u.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _searchController.text.trim();
    final showCustom = q.isNotEmpty &&
        !widget.units.any((u) => u.toLowerCase() == q.toLowerCase());

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
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
                const Text(
                  'Unit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search or type a custom unit…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (showCustom)
                  InkWell(
                    onTap: () => Navigator.pop(context, q),
                    child: Container(
                      color: cs.primary.withValues(alpha: 0.06),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Use "'),
                                TextSpan(
                                  text: q,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                                const TextSpan(text: '" as custom unit'),
                              ]),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 14,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),
                ..._filtered.map((unit) {
                  final isSelected = unit == widget.currentValue;
                  return InkWell(
                    onTap: () => Navigator.pop(context, unit),
                    child: Container(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              unit,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: cs.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
