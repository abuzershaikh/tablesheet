import 'package:flutter/material.dart';

/// Bottom toolbar with common actions including theme customization
class BottomToolbar extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onTheme;
  final VoidCallback? onFooter;
  final VoidCallback? onFormat;
  final VoidCallback? onSort;
  final VoidCallback? onFilter;
  final VoidCallback? onSearch;

  const BottomToolbar({
    Key? key,
    this.onUndo,
    this.onRedo,
    this.onTheme,
    this.onFooter,
    this.onFormat,
    this.onSort,
    this.onFilter,
    this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(
            icon: Icons.undo,
            onTap: onUndo,
            tooltip: 'Undo',
          ),
          _buildToolbarButton(
            icon: Icons.redo,
            onTap: onRedo,
            tooltip: 'Redo',
          ),
          _buildToolbarButton(
            icon: Icons.palette,
            onTap: onTheme,
            tooltip: 'Theme Customization',
          ),
          _buildToolbarButton(
            icon: Icons.functions,
            onTap: onFooter,
            tooltip: 'Summary Footer',
          ),
          _buildToolbarButton(
            icon: Icons.format_paint,
            onTap: onFormat,
            tooltip: 'Format',
          ),
          _buildToolbarButton(
            icon: Icons.sort,
            onTap: onSort,
            tooltip: 'Sort',
          ),
          _buildToolbarButton(
            icon: Icons.filter_list,
            onTap: onFilter,
            tooltip: 'Filter',
          ),
          _buildToolbarButton(
            icon: Icons.search,
            onTap: onSearch,
            tooltip: 'Search',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onTap != null ? Colors.black87 : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}