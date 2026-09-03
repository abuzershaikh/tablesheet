import 'package:flutter/material.dart';
import '../../../../domain/analytics/models/aggregation_type.dart';
import '../../../../domain/analytics/models/pivot_theme.dart';
import 'models/pivot_designer_state.dart';
import 'tabs/fields_tab.dart';
import 'tabs/filters_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/style_tab.dart';

class PivotDesignerDrawer extends StatefulWidget {
  final List<String> availableColumns;
  final List<String> selectedRowFields;
  final List<String> selectedColFields;
  final List<String> selectedDataFields;
  final List<String> selectedSlicerFields;
  final AggregationType aggType;
  final PivotThemeMode themeMode;
  final Function(List<String>, List<String>, List<String>, List<String>, AggregationType, PivotThemeMode) onApply;
  final VoidCallback onClose;

  const PivotDesignerDrawer({
    super.key,
    required this.availableColumns,
    required this.selectedRowFields,
    required this.selectedColFields,
    required this.selectedDataFields,
    required this.selectedSlicerFields,
    required this.aggType,
    required this.themeMode,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<PivotDesignerDrawer> createState() => _PivotDesignerDrawerState();
}

class _PivotDesignerDrawerState extends State<PivotDesignerDrawer> {
  late PivotDesignerState _s;
  static const _g = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _s = PivotDesignerState(
      availableColumns: List.from(widget.availableColumns),
      rowFields: List.from(widget.selectedRowFields),
      colFields: List.from(widget.selectedColFields),
      dataFields: List.from(widget.selectedDataFields),
      slicerFields: List.from(widget.selectedSlicerFields),
      aggType: widget.aggType,
      themeMode: widget.themeMode,
    );
    _s.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.80,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(-3, 0))
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // Header - Medium Size
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _g.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(Icons.pivot_table_chart, size: 14, color: _g),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pivot Designer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F), letterSpacing: -0.2),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close, size: 15, color: Colors.grey.shade600),
                          onPressed: widget.onClose,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs - Medium Size
                Container(
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade700,
                    indicator: BoxDecoration(
                      color: _g,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(height: 28, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.list_alt, size: 11), SizedBox(width: 3), Text('Fields')])),
                      Tab(height: 28, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.filter_alt_outlined, size: 11), SizedBox(width: 3), Text('Filters')])),
                      Tab(height: 28, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tune, size: 11), SizedBox(width: 3), Text('Settings')])),
                      Tab(height: 28, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.palette_outlined, size: 11), SizedBox(width: 3), Text('Style')])),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      FieldsTab(state: _s),
                      FiltersTab(state: _s),
                      SettingsTab(state: _s),
                      StyleTab(state: _s),
                    ],
                  ),
                ),
                // Footer - Medium Size
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 13),
                                label: const Text('Apply Pivot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _g,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                ),
                                onPressed: () => widget.onApply(_s.rowFields, _s.colFields, _s.dataFields, _s.slicerFields, _s.aggType, _s.themeMode),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            width: 32,
                            child: Material(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(7),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(7),
                                onTap: () {},
                                child: const Icon(Icons.refresh, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.save_outlined, size: 15, color: Colors.grey.shade500), const SizedBox(width: 3), Text('Save Layout', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))]),
                          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.more_horiz, size: 15, color: Colors.grey.shade500), const SizedBox(width: 3), Text('More Options', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
