import 'package:flutter/material.dart';

enum SwipeActionType {
  left,  // Actions: Delete, Hide, Sort, Filter
  right, // Actions: Insert Left, Insert Right, Duplicate
}

class ColumnSwipeMenu extends StatelessWidget {
  final int columnIndex;
  final SwipeActionType actionType;
  final VoidCallback onDismiss;
  final double horizontalOffset;
  
  // Left Swipe Actions
  final VoidCallback? onSelectColumn;
  final VoidCallback? onDelete;
  final VoidCallback? onHide;
  final VoidCallback? onSort;
  final VoidCallback? onFilter;
  
  // Right Swipe Actions
  final VoidCallback? onInsertLeft;
  final VoidCallback? onInsertRight;
  final VoidCallback? onDuplicate;

  const ColumnSwipeMenu({
    Key? key,
    required this.columnIndex,
    required this.actionType,
    required this.onDismiss,
    required this.horizontalOffset,
    this.onSelectColumn,
    this.onDelete,
    this.onHide,
    this.onSort,
    this.onFilter,
    this.onInsertLeft,
    this.onInsertRight,
    this.onDuplicate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Menu width estimate based on action type
    final menuWidth = actionType == SwipeActionType.left ? 250.0 : 220.0;

    // Clamp left offset so menu doesn't go off screen right edge
    final clampedLeft = horizontalOffset.clamp(0.0, screenWidth - menuWidth);

    return Stack(
      children: [
        // Full screen transparent detector to dismiss overlay
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            onPanStart: (_) => onDismiss(),
          ),
        ),
        
        // The Floating Menu — positioned just below column header (top: 44)
        Positioned(
          top: 44.0,
          left: clampedLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: menuWidth,
              // Ensure menu doesn't exceed screen bottom
              maxHeight: screenHeight - 100,
            ),
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black26,
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: actionType == SwipeActionType.left
                    ? _buildLeftActions()
                    : _buildRightActions(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftActions() {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionBtn(
            icon: Icons.select_all_rounded,
            label: 'Select',
            color: Colors.blue,
            onTap: onSelectColumn,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.red,
            onTap: onDelete,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.visibility_off_outlined,
            label: 'Hide',
            color: Colors.orange,
            onTap: onHide,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.sort,
            label: 'Sort',
            color: Colors.blue.shade700,
            onTap: onSort,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.filter_alt_outlined,
            label: 'Filter',
            color: Colors.purple,
            onTap: onFilter,
          ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionBtn(
            icon: Icons.keyboard_double_arrow_left,
            label: 'Insert L',
            color: Colors.teal,
            onTap: onInsertLeft,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.keyboard_double_arrow_right,
            label: 'Insert R',
            color: Colors.indigo,
            onTap: onInsertRight,
          ),
          _Divider(),
          _ActionBtn(
            icon: Icons.copy_outlined,
            label: 'Duplicate',
            color: Colors.green.shade700,
            onTap: onDuplicate,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (color ?? Colors.black87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color ?? Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
