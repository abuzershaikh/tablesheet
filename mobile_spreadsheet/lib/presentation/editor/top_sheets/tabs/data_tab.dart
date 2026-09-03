import 'package:flutter/material.dart';
import '../components/drawer_action_card.dart';

class DataTab extends StatelessWidget {
  final VoidCallback onSortAsc;
  final VoidCallback onSortDesc;
  final VoidCallback onFormulaHelper;
  final VoidCallback onAutoFill;
  final VoidCallback onTextToColumns;

  final VoidCallback? onPivotDesigner;

  const DataTab({
    Key? key,
    required this.onSortAsc,
    required this.onSortDesc,
    required this.onFormulaHelper,
    required this.onAutoFill,
    required this.onTextToColumns,
    this.onPivotDesigner,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DATA & FORMULAS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.sort_by_alpha_rounded,
                  color: const Color(0xFF107C41),
                  title: 'Sort A to Z',
                  subtitle: 'Ascending order',
                  onTap: onSortAsc,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.sort_by_alpha_outlined,
                  color: const Color(0xFFD83B01),
                  title: 'Sort Z to A',
                  subtitle: 'Descending order',
                  onTap: onSortDesc,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.functions_outlined,
                  color: const Color(0xFF0078D4),
                  title: 'Formula Library',
                  subtitle: 'Search math, text, financial & stat functions',
                  onTap: onFormulaHelper,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.auto_mode_rounded,
                  color: const Color(0xFF008080),
                  title: 'Smart AutoFill',
                  subtitle: 'Extend patterns down column',
                  onTap: onAutoFill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.splitscreen,
                  color: const Color(0xFF6B69D6),
                  title: 'Text to Columns',
                  subtitle: 'Split text into multiple columns',
                  onTap: onTextToColumns,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DrawerActionCard(
                  icon: Icons.table_chart,
                  color: const Color(0xFF107C41),
                  title: 'Pivot Table & Slicers',
                  subtitle: 'Create & design pivot tables',
                  onTap: onPivotDesigner ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}
