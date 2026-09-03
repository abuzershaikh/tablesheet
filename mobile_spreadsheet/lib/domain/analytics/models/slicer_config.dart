class SlicerItem {
  final String value;
  final bool isSelected;
  final bool isEnabled; // Cross-filtering: false if greyed out
  final int recordCount;

  const SlicerItem({
    required this.value,
    this.isSelected = true,
    this.isEnabled = true,
    this.recordCount = 0,
  });
}

class SlicerConfig {
  final String fieldName;
  final List<SlicerItem> items;
  final String searchQuery;

  const SlicerConfig({
    required this.fieldName,
    required this.items,
    this.searchQuery = '',
  });

  SlicerConfig copyWith({
    String? fieldName,
    List<SlicerItem>? items,
    String? searchQuery,
  }) {
    return SlicerConfig(
      fieldName: fieldName ?? this.fieldName,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
