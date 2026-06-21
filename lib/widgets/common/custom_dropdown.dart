import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A reusable styled dropdown widget.
class CustomDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final IconData? prefixIcon;
  final String Function(String)? itemLabelBuilder;

  const CustomDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.prefixIcon,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Row(
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                      child: Text(hint ?? '',
                          style: TextStyle(color: Colors.grey[500]))),
                ],
              ),
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(itemLabelBuilder != null
                            ? itemLabelBuilder!(item)
                            : item),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
