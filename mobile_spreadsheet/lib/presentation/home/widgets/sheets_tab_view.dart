import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/spreadsheet_entity.dart';
import '../home_controller.dart';

class SheetsTabView extends StatefulWidget {
  final Function(SpreadsheetEntity) onOpenSpreadsheet;
  final Function(SpreadsheetEntity) onShowSheetMenu;
  final VoidCallback onCreateNewSheet;

  const SheetsTabView({
    super.key,
    required this.onOpenSpreadsheet,
    required this.onShowSheetMenu,
    required this.onCreateNewSheet,
  });

  @override
  State<SheetsTabView> createState() => _SheetsTabViewState();
}

class _SheetsTabViewState extends State<SheetsTabView> {
  bool _isGridView = true; // Default: Grid View
  final TextEditingController _searchController = TextEditingController();

  static const String _viewModeKey = 'sheets_view_mode_grid';

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool(_viewModeKey) ?? true; // Default grid
    });
  }

  Future<void> _saveViewMode(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewModeKey, isGrid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar / Title & Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Sheets',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
                          color: const Color(0xFF64748B),
                          onPressed: () {
                            setState(() {
                              _isGridView = !_isGridView;
                            });
                            _saveViewMode(_isGridView);
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.sort_rounded, color: Color(0xFF64748B)),
                          onSelected: (value) => controller.sortSpreadsheets(value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
                            const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => controller.searchSpreadsheets(value),
                  decoration: InputDecoration(
                    hintText: 'Search spreadsheets...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              controller.searchSpreadsheets('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2848D3), width: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Content Area
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.spreadsheets.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => controller.loadSpreadsheets(),
                            child: _isGridView
                                ? _buildGridView(controller.spreadsheets)
                                : _buildListView(controller.spreadsheets),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF28C76F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_chart_outlined,
                size: 64,
                color: Color(0xFF28C76F),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Spreadsheets Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new sheet or import CSV / Excel files to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onCreateNewSheet,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Sheet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2848D3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<SpreadsheetEntity> spreadsheets) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: spreadsheets.length,
      itemBuilder: (context, index) {
        final sheet = spreadsheets[index];
        final dateStr = '${sheet.updatedAt.day} ${_getMonth(sheet.updatedAt.month)} ${sheet.updatedAt.year}';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onTap: () => widget.onOpenSpreadsheet(sheet),
            leading: _buildSheetIcon(size: 32),
            title: Text(
              sheet.name.isEmpty ? 'Untitled Spreadsheet' : sheet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Modified: $dateStr • ${sheet.sheets.length} Sheet(s)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 18),
              onPressed: () => widget.onShowSheetMenu(sheet),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<SpreadsheetEntity> spreadsheets) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: spreadsheets.length,
      itemBuilder: (context, index) {
        final sheet = spreadsheets[index];
        final dateStr = '${sheet.updatedAt.day} ${_getMonth(sheet.updatedAt.month)}';

        return GestureDetector(
          onTap: () => widget.onOpenSpreadsheet(sheet),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSheetIcon(size: 30),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => widget.onShowSheetMenu(sheet),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.name.isEmpty ? 'Untitled' : sheet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetIcon({double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF10B981), // Rich Emerald Green
            Color(0xFF047857), // Deep Emerald
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2.5),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.table_chart_rounded,
          color: Colors.white,
          size: size * 0.54,
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
