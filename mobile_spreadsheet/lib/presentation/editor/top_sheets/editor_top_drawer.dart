import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'tabs/home_tab.dart';
import 'tabs/file_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/view_tab.dart';
import 'tabs/data_tab.dart';
import 'tabs/sheet_copilot_tab.dart';
import 'tabs/automation_tab.dart';
import 'tabs/powerscript_tab.dart';
import '../modules/number_format/number_format_model.dart';

class EditorTopDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSaveToDevice;
  final VoidCallback onExportCsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportXlsx;
  final VoidCallback onExportPdf;
  final VoidCallback onRename;
  final VoidCallback onQuickShare;
  final VoidCallback onFindReplace;
  final VoidCallback onSmartTextParser;
  final VoidCallback onReceiptPdf;
  final VoidCallback onAudioRecorder;
  final VoidCallback onThemeCustomizer;
  final VoidCallback onConditionalFormatting;
  final VoidCallback onFreezePanes;
  final VoidCallback onFooterSettings;
  final VoidCallback onSortAsc;
  final VoidCallback onSortDesc;
  final VoidCallback onFormulaHelper;
  final VoidCallback onAutoFill;
  final VoidCallback onTextToColumns;
  final VoidCallback? onOpenPowerScriptStudio;
  final VoidCallback? onPivotDesigner;
  final Function(Map<String, dynamic>)? onPipelineApplied;
  // Home tab
  final String spreadsheetId;
  final Map<String, String> cellData;
  final Map<String, CellFormat> formatMap;
  final ValueChanged<Map<String, CellFormat>> onFormatMapChanged;

  const EditorTopDrawer({
    Key? key,
    required this.onClose,
    required this.onSaveToDevice,
    required this.onExportCsv,
    required this.onExportExcel,
    required this.onExportXlsx,
    required this.onExportPdf,
    required this.onRename,
    required this.onQuickShare,
    required this.onFindReplace,
    required this.onSmartTextParser,
    required this.onReceiptPdf,
    required this.onAudioRecorder,
    required this.onThemeCustomizer,
    required this.onConditionalFormatting,
    required this.onFreezePanes,
    required this.onFooterSettings,
    required this.onSortAsc,
    required this.onSortDesc,
    required this.onFormulaHelper,
    required this.onAutoFill,
    required this.onTextToColumns,
    this.onOpenPowerScriptStudio,
    this.onPivotDesigner,
    this.onPipelineApplied,
    required this.spreadsheetId,
    required this.cellData,
    required this.formatMap,
    required this.onFormatMapChanged,
  }) : super(key: key);

  @override
  State<EditorTopDrawer> createState() => _EditorTopDrawerState();
}

class _EditorTopDrawerState extends State<EditorTopDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _drawerHeight = 270.0;
  bool _showScrollHint = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _checkAndShowScrollHint();
  }

  Future<void> _checkAndShowScrollHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int hintCount = prefs.getInt('drawer_scroll_hint_count') ?? 0;
      String? lastHintDate = prefs.getString('drawer_scroll_hint_date');
      String today = DateTime.now().toIso8601String().split('T')[0];

      if (hintCount < 7 && lastHintDate != today) {
        await prefs.setInt('drawer_scroll_hint_count', hintCount + 1);
        await prefs.setString('drawer_scroll_hint_date', today);
        
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() => _showScrollHint = true);
          await Future.delayed(const Duration(seconds: 4));
          if (mounted) {
            setState(() => _showScrollHint = false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error showing scroll hint: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final maxAllowedHeight = isLandscape ? mediaQuery.size.height * 0.40 : mediaQuery.size.height * 0.45;
    final effectiveHeight = math.min(_drawerHeight, maxAllowedHeight);

    return Container(
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab navigation bar
          Container(
            height: 38,
            color: const Color(0xFF107C41), // Matching Excel green
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: 'Home'),
                Tab(text: 'File'),
                Tab(text: 'PowerScript'),
                Tab(text: 'Copilot'),
                Tab(text: 'Auto'),
                Tab(text: 'Tools'),
                Tab(text: 'View'),
                Tab(text: 'Data'),
              ],
            ),
          ),

          // Bottom drag handle and height indicatorea
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    HomeTab(
                      spreadsheetId: widget.spreadsheetId,
                      cellData: widget.cellData,
                      formatMap: widget.formatMap,
                      onFormatMapChanged: widget.onFormatMapChanged,
                    ),
                    FileTab(
                      onSaveToDevice: widget.onSaveToDevice,
                      onExportCsv: widget.onExportCsv,
                      onExportExcel: widget.onExportExcel,
                      onExportXlsx: widget.onExportXlsx,
                      onExportPdf: widget.onExportPdf,
                      onRename: widget.onRename,
                      onQuickShare: widget.onQuickShare,
                    ),
                    PowerScriptTab(
                      onOpenPowerScriptStudio: () {
                        widget.onClose();
                        widget.onOpenPowerScriptStudio?.call();
                      },
                    ),
                    SheetCopilotTab(
                      onPipelineApplied: widget.onPipelineApplied,
                    ),
                    AutomationTab(
                      onOpenPowerScriptStudio: () {
                        widget.onClose();
                        widget.onOpenPowerScriptStudio?.call();
                      },
                    ),
                    ToolsTab(
                      onFindReplace: widget.onFindReplace,
                      onSmartTextParser: widget.onSmartTextParser,
                      onReceiptPdf: widget.onReceiptPdf,
                      onAudioRecorder: widget.onAudioRecorder,
                    ),
                    ViewTab(
                      onThemeCustomizer: widget.onThemeCustomizer,
                      onConditionalFormatting: widget.onConditionalFormatting,
                      onFreezePanes: widget.onFreezePanes,
                      onFooterSettings: widget.onFooterSettings,
                    ),
                    DataTab(
                      onSortAsc: widget.onSortAsc,
                      onSortDesc: widget.onSortDesc,
                      onFormulaHelper: widget.onFormulaHelper,
                      onAutoFill: widget.onAutoFill,
                      onTextToColumns: widget.onTextToColumns,
                      onPivotDesigner: widget.onPivotDesigner,
                    ),
                  ],
                ),
                if (_showScrollHint)
                  const Positioned(
                    bottom: 20,
                    right: 40,
                    child: _ScrollHintAnimation(),
                  ),
              ],
            ),
          ),

          // Downward / Upward Pull Handle
          GestureDetector(
            onTap: widget.onClose,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                widget.onClose();
              }
            },
            child: Container(
              width: double.infinity,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Close Tool Drawer',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollHintAnimation extends StatefulWidget {
  const _ScrollHintAnimation({Key? key}) : super(key: key);

  @override
  State<_ScrollHintAnimation> createState() => _ScrollHintAnimationState();
}

class _ScrollHintAnimationState extends State<_ScrollHintAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _slideAnimation = Tween<double>(begin: 0, end: -40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: 0.8,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swipe_vertical_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}
