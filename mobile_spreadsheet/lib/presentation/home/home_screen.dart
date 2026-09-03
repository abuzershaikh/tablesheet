import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/spreadsheet_entity.dart';
import '../../domain/services/storage/sheet_data_storage.dart';
import '../editor/editor_screen.dart';
import '../editor/editor_controller.dart';
import 'home_controller.dart';
import 'widgets/home_header.dart';
import 'widgets/quick_actions_panel.dart';
import 'widgets/tools_section.dart';
import 'widgets/custom_bottom_nav.dart';
import 'widgets/sheets_tab_view.dart';
import '../../domain/entities/template_entity.dart';
import '../../data/templates/column_type_resolver.dart';
import 'package:flutter/services.dart';
import '../templates/templates_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/contact_us_screen.dart';
import '../legal/terms_conditions_screen.dart';
import '../legal/about_us_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  static const _intentChannel = MethodChannel('com.tablenotes.spreadsheet/intent');

  @override
  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFileOpened') {
        final filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty && mounted) {
          await _handleIncomingFile(filePath);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().loadSpreadsheets();
      _checkInitialIntent();
    });
  }

  Future<void> _checkInitialIntent() async {
    try {
      final String? filePath = await _intentChannel.invokeMethod('getInitialFilePath');
      if (filePath != null && filePath.isNotEmpty && mounted) {
        await _handleIncomingFile(filePath);
      }
    } catch (e) {
      print('Error checking initial intent: $e');
    }
  }

  Future<void> _handleIncomingFile(String filePath) async {
    try {
      final controller = context.read<HomeController>();
      final spreadsheet = await controller.importAnyFile(filePath);

      if (spreadsheet != null && mounted) {
        _openSpreadsheet(context, spreadsheet);
      }
    } catch (e) {
      print('Error handling incoming file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: _buildDrawer(context),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFabMenu(context),
        backgroundColor: const Color(0xFF2848D3),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F32B9), Color(0xFF8633F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(Icons.table_chart, size: 100, color: Colors.white.withOpacity(0.2)),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spreadsheet Pro',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Data everywhere',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildDrawerItem(
                    icon: Icons.add_box_outlined,
                    color: const Color(0xFF2848D3),
                    title: 'Create Blank Sheet',
                    onTap: () {
                      Navigator.pop(context);
                      _createBlankSheet(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.amber.shade300, width: 1),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium, color: Colors.orange),
                      title: const Text('Go Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      subtitle: const Text('Unlock pro features', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
                      onTap: () {
                        Navigator.pop(context);
                        _showComingSoon('Premium Features');
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: const Icon(Icons.gavel_rounded, color: Color(0xFF5E27D8)),
                        title: const Text('Legal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          _buildLegalItem(context, Icons.privacy_tip_outlined, 'Privacy Policy', const PrivacyPolicyScreen()),
                          _buildLegalItem(context, Icons.contact_mail_outlined, 'Contact Us', const ContactUsScreen()),
                          _buildLegalItem(context, Icons.description_outlined, 'Terms & Conditions', const TermsConditionsScreen()),
                          _buildLegalItem(context, Icons.info_outline, 'About Us', const AboutUsScreen()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLegalItem(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: Icon(icon, size: 22, color: Colors.black54),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }

  Widget _buildBody() {
    if (_currentNavIndex == 1) {
      // Sheets Tab: Show all created spreadsheets
      return SheetsTabView(
        onOpenSpreadsheet: (sheet) => _openSpreadsheet(context, sheet),
        onShowSheetMenu: (sheet) => _showSheetMenu(context, sheet),
        onCreateNewSheet: () => _createBlankSheet(context),
      );
    }

    if (_currentNavIndex == 2) {
      // Templates Tab
      return TemplatesScreen(
        onUseTemplate: (template) => _createFromTemplate(context, template),
      );
    }

    if (_currentNavIndex != 0) {
      return Center(
        child: Text(
          'Tab $_currentNavIndex coming soon',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // Home Tab (Index 0)
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. Header Background (Curve & Slider)
          const HomeHeader(),
          
          const SizedBox(height: 16),
          
          // 2. Quick Actions Panel
          QuickActionsPanel(
            onNewSheet: () => _createBlankSheet(context),
            onImportFile: () => _showImportOptions(context),
            onCloudSheets: () => _showComingSoon('Cloud Sheets'),
          ),
          
          // Gap between cards
          const SizedBox(height: 24),
          
          // Tools & More Section
          const ToolsSection(),
          
          // Bottom padding for FAB
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Coming soon')),
    );
  }

  /// Open a spreadsheet in the EditorScreen directly
  void _openSpreadsheet(BuildContext context, SpreadsheetEntity spreadsheet) async {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black26,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
    overlay.insert(overlayEntry);

    try {
      final cellData = await SheetDataStorage.loadCellData(spreadsheet.activeSheet?.sheetId ?? spreadsheet.spreadsheetId, fallbackSpreadsheetId: spreadsheet.spreadsheetId);
      if (cellData != null) {
        spreadsheet = spreadsheet.copyWith(transientCellData: cellData);
      }
    } finally {
      overlayEntry.remove();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => EditorController(),
          child: EditorScreen(
            spreadsheet: spreadsheet,
            onRename: (newName) {
              this.context.read<HomeController>().renameSpreadsheet(spreadsheet.spreadsheetId, newName);
            },
          ),
        ),
      ),
    );
  }

  /// Create new blank spreadsheet & immediately open in EditorScreen
  void _createBlankSheet(BuildContext context) async {
    final spreadsheet = await context.read<HomeController>().createBlankSpreadsheet();
    if (spreadsheet != null && mounted) {
      _openSpreadsheet(context, spreadsheet);
    }
  }

  /// Create spreadsheet from a template with pre-configured columns
  void _createFromTemplate(BuildContext context, SheetTemplate template) async {
    final spreadsheet = await context.read<HomeController>().createBlankSpreadsheet();
    if (spreadsheet == null || !mounted) return;

    // Navigate to EditorScreen with template configuration
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) {
            final controller = EditorController();
            // Apply template config after loading
            Future.microtask(() async {
              await controller.loadSpreadsheet(spreadsheet);
              // Set column names, types, and widths from template
              for (int i = 0; i < template.columns.length; i++) {
                final col = template.columns[i];
                final colType = ColumnTypeResolver.resolve(col.typeId);
                controller.updateColumnProperties(i, col.name, colType, col.width);
              }
              // Apply freeze config
              if (template.frozenRows > 0) {
                controller.toggleFreezeTopRow();
              }
              if (template.frozenColumns > 0) {
                controller.toggleFreezeFirstColumn();
              }
            });
            return controller;
          },
          child: EditorScreen(
            spreadsheet: spreadsheet.copyWith(name: template.name),
            onRename: (newName) {
              this.context.read<HomeController>().renameSpreadsheet(spreadsheet.spreadsheetId, newName);
            },
          ),
        ),
      ),
    );
  }

  /// Import CSV & immediately open in EditorScreen
  void _importCsv(BuildContext context) async {
    final spreadsheet = await context.read<HomeController>().importCsv();
    if (spreadsheet != null && mounted) {
      _openSpreadsheet(context, spreadsheet);
    }
  }

  /// Import Excel & immediately open in EditorScreen
  void _importExcel(BuildContext context) async {
    final spreadsheet = await context.read<HomeController>().importExcel();
    if (spreadsheet != null && mounted) {
      _openSpreadsheet(context, spreadsheet);
    }
  }

  /// Show spreadsheet options (Open, Rename, Duplicate, Delete)
  void _showSheetMenu(BuildContext context, SpreadsheetEntity spreadsheet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF28C76F).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart, color: Color(0xFF28C76F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      spreadsheet.name.isEmpty ? 'Untitled Spreadsheet' : spreadsheet.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Color(0xFF2848D3)),
              title: const Text('Open Sheet'),
              onTap: () {
                Navigator.pop(ctx);
                _openSpreadsheet(context, spreadsheet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, spreadsheet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: Colors.amber),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<HomeController>().duplicateSpreadsheet(spreadsheet.spreadsheetId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(context, spreadsheet);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, SpreadsheetEntity spreadsheet) {
    final controller = TextEditingController(text: spreadsheet.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Spreadsheet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<HomeController>().renameSpreadsheet(spreadsheet.spreadsheetId, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, SpreadsheetEntity spreadsheet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Spreadsheet'),
        content: Text('Are you sure you want to delete "${spreadsheet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<HomeController>().deleteSpreadsheet(spreadsheet.spreadsheetId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Show Import Options Modal Sheet (CSV vs Excel)
  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Import File',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description, color: Colors.purple),
              ),
              title: const Text('Import CSV File', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select a .csv file from storage'),
              onTap: () {
                Navigator.pop(ctx);
                _importCsv(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: const Text('Import Excel File', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select a .xlsx or .xls file'),
              onTap: () {
                Navigator.pop(ctx);
                _importExcel(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show FAB Menu (New Sheet, Import CSV, Import Excel, Cloud)
  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Create or Import',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF28C76F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_box_outlined, color: Color(0xFF28C76F)),
              ),
              title: const Text('New Blank Sheet', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a new empty spreadsheet'),
              onTap: () {
                Navigator.pop(ctx);
                _createBlankSheet(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7367F0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.file_present_outlined, color: Color(0xFF7367F0)),
              ),
              title: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Import data from CSV file'),
              onTap: () {
                Navigator.pop(ctx);
                _importCsv(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_view_outlined, color: Colors.green),
              ),
              title: const Text('Import Excel', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Import data from Excel (.xlsx/.xls)'),
              onTap: () {
                Navigator.pop(ctx);
                _importExcel(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00CFE8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_outlined, color: Color(0xFF00CFE8)),
              ),
              title: const Text('Cloud Sheets', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Connect to Google Drive / Cloud'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon('Cloud Sheets');
              },
            ),
          ],
        ),
      ),
    );
  }
}