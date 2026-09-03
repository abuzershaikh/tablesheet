import 'package:flutter/material.dart';
import 'tabs/home_tab.dart';
import 'tabs/insert_tab.dart';
import 'tabs/view_tab.dart';
import 'tabs/data_tab.dart';
import 'tabs/formula_tab.dart';

class EditorBottomSheet extends StatefulWidget {
  final VoidCallback onClose;
  final String currentSheetName;
  final VoidCallback? onFormatApplied;

  const EditorBottomSheet({
    Key? key,
    required this.onClose,
    this.currentSheetName = 'Sheet1',
    this.onFormatApplied,
  }) : super(key: key);

  @override
  State<EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<EditorBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final double _maxHeight = 400.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _maxHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle and sheet name bar
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! > 10) {
                widget.onClose();
              }
            },
            child: Container(
              color: const Color(0xFFF3F4F6),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {},
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.currentSheetName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF107C41), // Excel green
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF107C41),
              tabs: const [
                Tab(text: 'Home'),
                Tab(text: 'Insert'),
                Tab(text: 'View'),
                Tab(text: 'Data'),
                Tab(text: 'Formulas'),
              ],
            ),
          ),
          
          // Tab contents
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                HomeTab(onFormatApplied: widget.onFormatApplied),
                const InsertTab(),
                const ViewTab(),
                const DataTab(),
                const FormulaTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
