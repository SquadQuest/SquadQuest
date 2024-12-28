import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeFilterBar extends ConsumerWidget {
  final List<({String label, String description})> filters;
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;

  const HomeFilterBar({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: filters.asMap().entries.map((entry) {
                final index = entry.key;
                final filter = entry.value;
                final isSelected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(filter.label),
                    onSelected: (selected) {
                      if (selected) {
                        onFilterSelected(index);
                      }
                    },
                    avatar:
                        isSelected ? const Icon(Icons.check, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              filters[selectedIndex].description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
