import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.home, label: 'Home', index: 0, isSelected: currentIndex == 0),
            _buildNavItem(icon: Icons.grid_view, label: 'Sheets', index: 1, isSelected: currentIndex == 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(icon: Icons.description_outlined, label: 'Templates', index: 2, isSelected: currentIndex == 2),
            _buildNavItem(icon: Icons.person_outline, label: 'Profile', index: 3, isSelected: currentIndex == 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    final color = isSelected ? const Color(0xFF2879FF) : Colors.grey[500];
    
    return InkWell(
      onTap: () => onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF2879FF),
                borderRadius: BorderRadius.circular(2),
              ),
            )
        ],
      ),
    );
  }
}
