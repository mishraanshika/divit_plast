import 'package:flutter/material.dart';

class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final bool required;
  final String? errorMessage;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.errorMessage,
  });

  Widget? _selectedChild() {
    if (value == null) return null;
    return items.where((item) => item.value == value).firstOrNull?.child;
  }

  Future<void> _showPicker(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    final T? picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ConstrainedBox(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final isSelected = item.value == value;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, item.value),
                      child: Container(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: DefaultTextStyle.merge(
                                style: TextStyle(
                                    fontSize: 15, color: cs.onSurface),
                                child: item.child,
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle,
                                  color: cs.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedChild = _selectedChild();

    return FormField<T>(
      key: ValueKey(value),
      initialValue: value,
      validator: (_) =>
          required && value == null ? (errorMessage ?? 'Required') : null,
      builder: (state) {
        final hasError = state.hasError;
        final borderColor =
            hasError ? cs.error : (value != null ? cs.primary : cs.outline);
        final borderWidth = (hasError || value != null) ? 1.5 : 1.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPicker(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selectedChild != null
                          ? DefaultTextStyle.merge(
                              style:
                                  TextStyle(fontSize: 14, color: cs.onSurface),
                              child: selectedChild,
                            )
                          : Text(
                              'Select $label',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  state.errorText!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
