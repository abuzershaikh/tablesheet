import 'package:flutter/material.dart';
import '../../../domain/analytics/models/chart_config.dart';
import '../../../domain/analytics/models/pivot_result.dart';
import '../../../domain/analytics/models/pivot_theme.dart';
import '../../../domain/analytics/models/slicer_config.dart';
import '../../../domain/analytics/models/aggregation_type.dart';
import '../../../domain/analytics/engines/pivot_engine.dart';
import '../../../domain/analytics/registry/chart_renderer_registry.dart';
import '../pivot_designer/pivot_designer_drawer.dart';

class PivotTableRenderer implements ChartPlugin {
  @override
  String get pluginId => 'native_pivot_table_plugin';

  @override
  List<ChartType> get supportedTypes => [ChartType.pivotTable];

  @override
  bool get supportsAnimation => false;

  @override
  bool get supports3D => false;

  @override
  Widget render(ChartConfig config) {
    if (config.data.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    return PivotTableInteractiveWidget(config: config);
  }
}

class PivotTableInteractiveWidget extends StatefulWidget {
  final ChartConfig config;

  const PivotTableInteractiveWidget({super.key, required this.config});

  @override
  State<PivotTableInteractiveWidget> createState() => _PivotTableInteractiveWidgetState();
}

class _PivotTableInteractiveWidgetState extends State<PivotTableInteractiveWidget> {
  final PivotEngine _pivotEngine = PivotEngine();
  late List<String> _rowFields;
  late List<String> _colFields;
  late List<String> _dataFields;
  late List<String> _slicerFields;
  late AggregationType _aggType;
  late PivotThemeMode _themeMode;
  final Map<String, List<String>> _activeSlicerFilters = {};

  PivotResult? _pivotResult;
  bool _isLoading = false;
  int _pivotRequestId = 0;

  @override
  void initState() {
    super.initState();
    _dataFields = widget.config.series.isNotEmpty ? List<String>.from(widget.config.series) : ['Values'];
    _rowFields = [widget.config.axis];
    _colFields = [];
    
    // Auto-detect slicer fields from data keys excluding row and data field
    final availableCols = _getAvailableColumns();
    _slicerFields = availableCols.where((c) => !_rowFields.contains(c) && !_dataFields.contains(c) && !_colFields.contains(c)).take(2).toList();

    _aggType = AggregationType.sum;
    _themeMode = PivotThemeMode.professionalBlue;
    _computePivot();
  }

  List<String> _getAvailableColumns() {
    if (widget.config.data.isEmpty) return [];
    return widget.config.data.first.keys.map((e) => e.toString()).toList();
  }

  Future<void> _computePivot() async {
    _pivotRequestId++;
    final curId = _pivotRequestId;
    setState(() => _isLoading = true);

    final res = await _pivotEngine.pivot(
      sheetId: 'Sheet1',
      rowFields: _rowFields,
      colFields: _colFields,
      dataFields: _dataFields,
      aggType: _aggType,
      themeMode: _themeMode,
      slicerFields: _slicerFields,
      activeSlicerFilters: _activeSlicerFilters,
      rawData: widget.config.data,
    );

    if (curId != _pivotRequestId) return;

    setState(() {
      _pivotResult = res;
      _isLoading = false;
    });
  }

  void _openDesigner() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: PivotDesignerDrawer(
            availableColumns: _getAvailableColumns(),
            selectedRowFields: _rowFields,
            selectedColFields: _colFields,
            selectedDataFields: _dataFields,
            selectedSlicerFields: _slicerFields,
            aggType: _aggType,
            themeMode: _themeMode,
            onApply: (rowFields, colFields, dataFields, slicerFields, aggType, themeMode) {
              setState(() {
                _rowFields = List<String>.from(rowFields);
                _colFields = List<String>.from(colFields);
                _dataFields = List<String>.from(dataFields);
                _slicerFields = List<String>.from(slicerFields);
                _aggType = aggType;
                _themeMode = themeMode;
              });
              Navigator.pop(ctx);
              _computePivot();
            },
            onClose: () => Navigator.pop(ctx),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pivotResult == null) {
      return const Center(child: Text('No pivot data calculated'));
    }

    final theme = _pivotResult!.theme;
    final slicers = _pivotResult!.slicers;

    if (_pivotResult!.error != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              'Pivot Calculation Error',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _pivotResult!.error!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _openDesigner,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Open Designer'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.rowBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Control Bar (Designer Button & Status)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.headerBgColor,
            child: Row(
              children: [
                Icon(Icons.table_chart, color: theme.headerTextColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pivot: ${_rowFields.join(", ")} (${_aggType.name.toUpperCase()})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.headerTextColor, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text('Design & Filter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _openDesigner,
                ),
              ],
            ),
          ),

          // Slicers Bar (Cross-filtering buttons)
          if (slicers.isNotEmpty) _buildSlicersBar(slicers, theme),

          const Divider(height: 1),

          // Pivot Table Body
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildDataTable(_pivotResult!, theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlicersBar(List<SlicerConfig> slicers, PivotTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.headerBgColor.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: slicers.map((slicer) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Slicer: ${slicer.fieldName}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textColor.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: slicer.items.map((item) {
                    final isSel = item.isSelected;
                    final isDis = !item.isEnabled;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${item.value} (${item.recordCount})'),
                        selected: isSel && !isDis,
                        disabledColor: Colors.grey.shade200,
                        selectedColor: theme.accentColor.withValues(alpha: 0.25),
                        checkmarkColor: theme.accentColor,
                        labelStyle: TextStyle(
                          color: isDis
                              ? Colors.grey
                              : (isSel ? theme.accentColor : theme.textColor),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          decoration: isDis ? TextDecoration.lineThrough : null,
                        ),
                        onSelected: isDis
                            ? null
                            : (selected) {
                                final currentSelected = _activeSlicerFilters[slicer.fieldName];
                                final List<String> updatedList;
                                if (currentSelected == null) {
                                  final allVals = slicer.items.map((e) => e.value).toList();
                                  updatedList = List<String>.from(allVals);
                                  if (!selected) {
                                    updatedList.remove(item.value);
                                  }
                                } else {
                                  updatedList = List<String>.from(currentSelected);
                                  if (selected) {
                                    if (!updatedList.contains(item.value)) {
                                      updatedList.add(item.value);
                                    }
                                  } else {
                                    updatedList.remove(item.value);
                                  }
                                }
                                setState(() {
                                  _activeSlicerFilters[slicer.fieldName] = updatedList;
                                });
                                _computePivot();
                              },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataTable(PivotResult res, PivotTheme theme) {
    // 1. Column Definitions
    final List<DataColumn> columns = [];

    // Row fields columns
    for (final rf in res.rowFields) {
      columns.add(DataColumn(label: Text(rf, style: const TextStyle(fontWeight: FontWeight.bold))));
    }
    if (res.rowFields.isEmpty) {
      columns.add(const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))));
    }

    // Data measure columns (from colHeaderGrid)
    for (final colHeader in res.colHeaderGrid) {
      final label = colHeader.join(" \n ");
      columns.add(DataColumn(label: Text(label, style: const TextStyle(fontSize: 11, height: 1.2)), numeric: true));
    }

    // Row Grand Total columns (one for each data field)
    for (final df in res.dataFields) {
      columns.add(DataColumn(label: Text('Grand Total\n$df', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.2)), numeric: true));
    }

    // 2. Row Definitions
    final List<DataRow> rows = [];

    for (int r = 0; r < res.rowHeaderGrid.length; r++) {
      final List<DataCell> cells = [];

      // Row Header values
      for (final val in res.rowHeaderGrid[r]) {
        cells.add(DataCell(Text(val, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w500))));
      }

      // Matrix Data cells
      for (int c = 0; c < res.colHeaderGrid.length; c++) {
        final cellVal = r < res.dataGrid.length && c < res.dataGrid[r].length ? res.dataGrid[r][c] : 0.0;
        final valStr = cellVal is double ? cellVal.toStringAsFixed(2) : cellVal.toString();
        cells.add(DataCell(Text(valStr, style: TextStyle(color: theme.textColor))));
      }

      // Row Subtotals / Grand Totals
      final dfCount = res.dataFields.length;
      for (int i = 0; i < dfCount; i++) {
        final subtotalIdx = r * dfCount + i;
        final subtotalVal = subtotalIdx < res.rowSubtotals.length ? res.rowSubtotals[subtotalIdx] : 0.0;
        final subtotalStr = subtotalVal.toStringAsFixed(2);
        cells.add(DataCell(Text(subtotalStr, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))));
      }

      final isEven = r % 2 == 0;
      final bgColor = isEven ? theme.rowBgColor : theme.alternateRowBgColor;

      rows.add(DataRow(
        color: WidgetStateProperty.all(bgColor),
        cells: cells,
      ));
    }

    // 3. Grand Total Row (Bottom)
    final List<DataCell> gtCells = [];

    // Grand Total labels
    gtCells.add(DataCell(Text('Grand Total', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold))));
    final rowFieldsCount = res.rowFields.isEmpty ? 1 : res.rowFields.length;
    for (int i = 1; i < rowFieldsCount; i++) {
      gtCells.add(const DataCell(Text('')));
    }

    // Column subtotals
    for (int c = 0; c < res.colSubtotals.length; c++) {
      final subtotalVal = res.colSubtotals[c];
      gtCells.add(DataCell(Text(
        subtotalVal.toStringAsFixed(2),
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
      )));
    }

    // Overall grand totals (for each value field)
    final dfCount = res.dataFields.length;
    for (int i = 0; i < dfCount; i++) {
      double sumOfSubtotals = 0.0;
      for (int c = i; c < res.colSubtotals.length; c += dfCount) {
        sumOfSubtotals += res.colSubtotals[c];
      }
      final gtVal = i == 0 ? res.grandTotal : sumOfSubtotals;
      gtCells.add(DataCell(Text(
        gtVal.toStringAsFixed(2),
        style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold, fontSize: 13),
      )));
    }

    rows.add(DataRow(
      color: WidgetStateProperty.all(theme.headerBgColor.withValues(alpha: 0.15)),
      cells: gtCells,
    ));

    return DataTable(
      headingRowColor: WidgetStateProperty.all(theme.headerBgColor),
      headingTextStyle: TextStyle(color: theme.headerTextColor, fontWeight: FontWeight.bold),
      border: TableBorder.all(color: theme.borderColor, width: theme.borderWidth),
      columns: columns,
      rows: rows,
    );
  }
}
