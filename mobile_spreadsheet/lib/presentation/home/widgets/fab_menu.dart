import 'package:flutter/material.dart';

/// Floating Action Button with Speed Dial menu
class FabMenu extends StatefulWidget {
  final VoidCallback onCreateBlankSheet;
  final VoidCallback onImportExcel;
  final VoidCallback onImportCSV;
  final VoidCallback onImportGoogleForms;
  final VoidCallback onConnectAPI;

  const FabMenu({
    Key? key,
    required this.onCreateBlankSheet,
    required this.onImportExcel,
    required this.onImportCSV,
    required this.onImportGoogleForms,
    required this.onConnectAPI,
  }) : super(key: key);

  @override
  State<FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<FabMenu> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial items
        if (_isExpanded) ...[
          _buildSpeedDialItem(
            icon: Icons.api,
            label: 'Connect to API',
            onTap: () {
              _toggle();
              widget.onConnectAPI();
            },
          ),
          const SizedBox(height: 12),
          _buildSpeedDialItem(
            icon: Icons.article,
            label: 'Import Google Forms',
            onTap: () {
              _toggle();
              widget.onImportGoogleForms();
            },
          ),
          const SizedBox(height: 12),
          _buildSpeedDialItem(
            icon: Icons.description,
            label: 'Import CSV',
            onTap: () {
              _toggle();
              widget.onImportCSV();
            },
          ),
          const SizedBox(height: 12),
          _buildSpeedDialItem(
            icon: Icons.table_view,
            label: 'Import Excel',
            onTap: () {
              _toggle();
              widget.onImportExcel();
            },
          ),
          const SizedBox(height: 12),
          _buildSpeedDialItem(
            icon: Icons.add,
            label: 'Create Blank',
            onTap: () {
              _toggle();
              widget.onCreateBlankSheet();
            },
          ),
          const SizedBox(height: 16),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _expandAnimation,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return FadeTransition(
      opacity: _expandAnimation,
      child: ScaleTransition(
        scale: _expandAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Icon button
            FloatingActionButton.small(
              onPressed: onTap,
              heroTag: label,
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }
}