# 📊 Charts + Pivot Tables Implementation - Complete Technical Plan

## 🎯 Research Summary & Technology Selection

### **📊 CHART ENGINE ANALYSIS**

Based on comprehensive research of Flutter chart libraries, here's the optimal architecture:

#### **Top Chart Libraries Comparison (2024)**

| Feature | fl_chart | Syncfusion | charts_flutter | Our Recommendation |
|---------|----------|------------|----------------|-------------------|
| **Performance** | Good (basic) | Excellent (10x faster) | Good | **Syncfusion** |
| **Chart Types** | 5 types | 30+ types | 15+ types | **Syncfusion** |
| **Customization** | High | Very High | Medium | **Syncfusion** |
| **License** | MIT (Free) | Commercial | Apache 2.0 | **Hybrid Approach** |
| **Size Impact** | ~2MB | ~8MB | ~4MB | **Manageable** |
| **Mobile Optimization** | Good | Excellent | Good | **Syncfusion** |
| **Real-time Updates** | Basic | Advanced | Good | **Syncfusion** |

#### **SELECTED ARCHITECTURE: Hybrid Chart Engine**

```dart
Strategy: Use Syncfusion for Pro users, fl_chart for Free tier
Benefits: 
- Keep app size small for free users
- Premium features justify Syncfusion license
- Maximum flexibility and performance
```

---

## 🏗️ CHART ENGINE IMPLEMENTATION STRUCTURE

### **📁 Project Structure**

```
lib/
├── domain/
│   ├── entities/
│   │   ├── chart_entity.dart
│   │   ├── chart_data_entity.dart
│   │   └── chart_config_entity.dart
│   ├── repositories/
│   │   └── chart_repository.dart
│   └── services/
│       ├── chart_engine_service.dart
│       ├── chart_ai_service.dart
│       └── chart_export_service.dart
├── data/
│   ├── models/
│   │   ├── chart_model.dart
│   │   ├── chart_data_model.dart
│   │   └── series_model.dart
│   ├── repositories/
│   │   └── chart_repository_impl.dart
│   └── datasources/
│       ├── spreadsheet_data_source.dart
│       └── chart_templates_source.dart
├── presentation/
│   ├── widgets/
│   │   ├── charts/
│   │   │   ├── base_chart_widget.dart
│   │   │   ├── line_chart_widget.dart
│   │   │   ├── bar_chart_widget.dart
│   │   │   ├── pie_chart_widget.dart
│   │   │   ├── scatter_chart_widget.dart
│   │   │   ├── area_chart_widget.dart
│   │   │   ├── combo_chart_widget.dart
│   │   │   └── chart_builder_dialog.dart
│   │   ├── chart_toolbar/
│   │   │   ├── chart_type_selector.dart
│   │   │   ├── chart_style_panel.dart
│   │   │   └── chart_export_button.dart
│   │   └── ai_chart_assistant/
│   │       ├── chart_suggestion_card.dart
│   │       └── ai_chart_dialog.dart
│   └── screens/
│       ├── chart_builder_screen.dart
│       └── chart_gallery_screen.dart
└── core/
    ├── chart_engine/
    │   ├── fl_chart_engine.dart
    │   ├── syncfusion_engine.dart
    │   ├── chart_engine_factory.dart
    │   └── chart_renderer.dart
    └── utils/
        ├── chart_utils.dart
        ├── data_processor.dart
        └── export_utils.dart
```

### **🎯 Core Chart Engine Architecture**

#### **1. Chart Engine Factory**
```dart
// core/chart_engine/chart_engine_factory.dart
abstract class ChartEngine {
  Widget buildChart(ChartConfig config, List<ChartData> data);
  Future<Uint8List> exportChart(ChartConfig config, ExportFormat format);
  List<ChartType> getSupportedTypes();
}

class ChartEngineFactory {
  static ChartEngine getEngine(UserTier tier, ChartType type) {
    switch (tier) {
      case UserTier.free:
        return FLChartEngine();
      case UserTier.pro:
      case UserTier.business:
        // Use Syncfusion for advanced charts, fl_chart for basic ones
        return _needsAdvancedFeatures(type) 
            ? SyncfusionChartEngine() 
            : FLChartEngine();
    }
  }
  
  static bool _needsAdvancedFeatures(ChartType type) {
    return [
      ChartType.combo, ChartType.waterfall, ChartType.funnel,
      ChartType.pyramid, ChartType.heatmap, ChartType.treemap
    ].contains(type);
  }
}
```

#### **2. Chart Configuration Model**
```dart
// domain/entities/chart_entity.dart
class ChartConfig {
  final String id;
  final ChartType type;
  final String title;
  final String subtitle;
  final ChartTheme theme;
  final AxisConfig xAxis;
  final AxisConfig yAxis;
  final LegendConfig legend;
  final List<SeriesConfig> series;
  final AnimationConfig animation;
  final InteractionConfig interaction;
  
  // AI-generated properties
  final String aiReasoning;
  final double confidenceScore;
  final List<String> suggestedImprovements;
}

enum ChartType {
  line, bar, column, pie, doughnut, area, scatter,
  combo, waterfall, funnel, pyramid, heatmap, treemap,
  candlestick, ohlc, histogram, boxPlot, bubble
}
```

#### **3. AI Chart Recommendation Engine**
```dart
// domain/services/chart_ai_service.dart
class ChartAIService {
  Future<List<ChartRecommendation>> suggestCharts(
    Range dataRange,
    String? userIntent
  ) async {
    // 1. Analyze data structure
    final analysis = await _analyzeDataStructure(dataRange);
    
    // 2. Generate AI recommendations
    final prompt = _buildChartRecommendationPrompt(analysis, userIntent);
    final aiResponse = await _callAI(prompt);
    
    // 3. Parse recommendations
    return _parseChartRecommendations(aiResponse);
  }
  
  DataAnalysis _analyzeDataStructure(Range range) {
    return DataAnalysis(
      columnCount: range.columnCount,
      rowCount: range.rowCount,
      dataTypes: _detectColumnTypes(range),
      hasHeaders: _detectHeaders(range),
      hasTimeSeriesData: _detectTimeSeries(range),
      hasNumericalData: _detectNumerical(range),
      hasCategoricalData: _detectCategorical(range),
    );
  }
  
  String _buildChartRecommendationPrompt(DataAnalysis analysis, String? intent) {
    return '''
    Analyze this dataset and recommend the best chart types:
    
    Data Structure:
    - Columns: ${analysis.columnCount}
    - Rows: ${analysis.rowCount}  
    - Data Types: ${analysis.dataTypes}
    - Has Time Series: ${analysis.hasTimeSeriesData}
    - Has Categories: ${analysis.hasCategoricalData}
    
    User Intent: ${intent ?? 'Not specified'}
    
    Return top 3 chart recommendations with:
    1. Chart type and reasoning
    2. Confidence score (0-1)
    3. Specific configuration suggestions
    4. Why this chart best represents the data
    ''';
  }
}
```

---

## 🔄 PIVOT TABLE IMPLEMENTATION STRUCTURE

### **📁 Pivot Engine Architecture**

```
lib/
├── domain/
│   ├── entities/
│   │   ├── pivot_table_entity.dart
│   │   ├── pivot_field_entity.dart
│   │   ├── pivot_data_entity.dart
│   │   └── aggregation_entity.dart
│   ├── repositories/
│   │   └── pivot_repository.dart
│   └── services/
│       ├── pivot_engine_service.dart
│       ├── pivot_ai_service.dart
│       ├── data_aggregation_service.dart
│       └── pivot_export_service.dart
├── data/
│   ├── models/
│   │   ├── pivot_table_model.dart
│   │   ├── pivot_field_model.dart
│   │   └── aggregation_model.dart
│   ├── repositories/
│   │   └── pivot_repository_impl.dart
│   └── datasources/
│       ├── spreadsheet_pivot_source.dart
│       └── cached_pivot_source.dart
├── presentation/
│   ├── widgets/
│   │   ├── pivot/
│   │   │   ├── pivot_table_widget.dart
│   │   │   ├── pivot_builder_panel.dart
│   │   │   ├── field_drop_zone.dart
│   │   │   ├── pivot_field_list.dart
│   │   │   ├── aggregation_selector.dart
│   │   │   └── pivot_formatter.dart
│   │   ├── drag_drop/
│   │   │   ├── draggable_field.dart
│   │   │   ├── drop_target_zone.dart
│   │   │   └── drag_feedback_widget.dart
│   │   └── ai_pivot_assistant/
│   │       ├── pivot_suggestion_card.dart
│   │       └── ai_pivot_dialog.dart
│   └── screens/
│       ├── pivot_builder_screen.dart
│       └── pivot_editor_screen.dart
└── core/
    ├── pivot_engine/
    │   ├── data_processor.dart
    │   ├── aggregation_engine.dart
    │   ├── grouping_engine.dart
    │   └── calculation_engine.dart
    └── utils/
        ├── pivot_utils.dart
        └── performance_optimizer.dart
```

### **🎯 Core Pivot Engine Components**

#### **1. Pivot Table Entity Model**
```dart
// domain/entities/pivot_table_entity.dart
class PivotTable {
  final String id;
  final String name;
  final Range sourceRange;
  final List<PivotField> rowFields;
  final List<PivotField> columnFields;
  final List<PivotField> valueFields;
  final List<PivotField> filterFields;
  final PivotOptions options;
  final Map<String, dynamic> cache;
  
  // AI-generated properties
  final String aiSuggestionReason;
  final List<String> recommendedCalculations;
}

class PivotField {
  final String name;
  final String sourceColumn;
  final PivotFieldType type;
  final AggregationType aggregation;
  final String customName;
  final List<String> filters;
  final SortOrder sortOrder;
  final GroupingOptions? grouping;
}

enum PivotFieldType {
  row, column, value, filter, calculated
}

enum AggregationType {
  sum, count, average, max, min, product, 
  countNums, stdDev, stdDevP, var, varP,
  distinctCount, custom
}
```

#### **2. Data Aggregation Engine**
```dart
// core/pivot_engine/aggregation_engine.dart
class AggregationEngine {
  Map<String, dynamic> aggregateData(
    List<Map<String, dynamic>> sourceData,
    PivotConfiguration config
  ) {
    // 1. Group data by row and column fields
    final grouped = _groupData(sourceData, config);
    
    // 2. Apply aggregations for each group
    final aggregated = <String, Map<String, dynamic>>{};
    
    for (final groupKey in grouped.keys) {
      final groupData = grouped[groupKey]!;
      aggregated[groupKey] = _calculateAggregations(groupData, config.valueFields);
    }
    
    // 3. Generate pivot structure
    return _buildPivotStructure(aggregated, config);
  }
  
  Map<String, List<Map<String, dynamic>>> _groupData(
    List<Map<String, dynamic>> data,
    PivotConfiguration config
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    
    for (final row in data) {
      final groupKey = _buildGroupKey(row, config.rowFields, config.columnFields);
      groups.putIfAbsent(groupKey, () => []).add(row);
    }
    
    return groups;
  }
  
  Map<String, dynamic> _calculateAggregations(
    List<Map<String, dynamic>> groupData,
    List<PivotField> valueFields
  ) {
    final result = <String, dynamic>{};
    
    for (final field in valueFields) {
      final values = groupData
          .map((row) => _parseNumeric(row[field.sourceColumn]))
          .where((val) => val != null)
          .cast<double>()
          .toList();
      
      result[field.name] = _applyAggregation(values, field.aggregation);
    }
    
    return result;
  }
  
  dynamic _applyAggregation(List<double> values, AggregationType type) {
    if (values.isEmpty) return null;
    
    switch (type) {
      case AggregationType.sum:
        return values.reduce((a, b) => a + b);
      case AggregationType.average:
        return values.reduce((a, b) => a + b) / values.length;
      case AggregationType.count:
        return values.length;
      case AggregationType.max:
        return values.reduce(math.max);
      case AggregationType.min:
        return values.reduce(math.min);
      case AggregationType.distinctCount:
        return values.toSet().length;
      // ... more aggregation types
    }
  }
}
```

#### **3. AI Pivot Recommendation Engine**
```dart
// domain/services/pivot_ai_service.dart
class PivotAIService {
  Future<List<PivotRecommendation>> suggestPivotTables(
    Range sourceRange,
    String? userIntent
  ) async {
    // 1. Analyze data for pivot potential
    final analysis = await _analyzePivotPotential(sourceRange);
    
    // 2. Generate AI recommendations
    final recommendations = await _generatePivotSuggestions(analysis, userIntent);
    
    // 3. Rank by relevance and feasibility
    return _rankRecommendations(recommendations);
  }
  
  Future<PivotAnalysis> _analyzePivotPotential(Range range) async {
    final headers = await _getHeaders(range);
    final sampleData = await _getSampleData(range, 100); // First 100 rows
    
    return PivotAnalysis(
      categoricalColumns: _findCategoricalColumns(sampleData),
      numericalColumns: _findNumericalColumns(sampleData),
      dateColumns: _findDateColumns(sampleData),
      cardinalityMap: _calculateCardinality(sampleData),
      dataQuality: _assessDataQuality(sampleData),
      suggestedDimensions: _suggestDimensions(sampleData),
      suggestedMeasures: _suggestMeasures(sampleData),
    );
  }
  
  String _buildPivotSuggestionPrompt(PivotAnalysis analysis, String? intent) {
    return '''
    Analyze this dataset and suggest optimal pivot table configurations:
    
    Data Analysis:
    - Categorical columns: ${analysis.categoricalColumns}
    - Numerical columns: ${analysis.numericalColumns}
    - Date columns: ${analysis.dateColumns}
    - Cardinality: ${analysis.cardinalityMap}
    
    User Intent: ${intent ?? 'General analysis'}
    
    Recommend top 3 pivot configurations with:
    1. Row fields (dimensions to group by)
    2. Column fields (cross-tabulation)
    3. Value fields (measures to aggregate)
    4. Suggested aggregation types
    5. Business reasoning for each recommendation
    6. Expected insights this pivot will reveal
    ''';
  }
}
```

---

## 📱 MOBILE-OPTIMIZED UI ARCHITECTURE

### **Chart Builder Interface**
```dart
// presentation/widgets/charts/chart_builder_dialog.dart
class ChartBuilderDialog extends StatefulWidget {
  final Range selectedRange;
  final Function(ChartConfig) onChartCreated;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // AI Suggestion Bar
          AIChartSuggestionBar(
            range: selectedRange,
            onSuggestionTapped: (suggestion) => _applySuggestion(suggestion),
          ),
          
          // Chart Type Selector (Horizontal scroll)
          ChartTypeSelector(
            supportedTypes: _getSupportedChartTypes(),
            selectedType: _selectedType,
            onTypeChanged: (type) => setState(() => _selectedType = type),
          ),
          
          // Live Preview Area
          Expanded(
            flex: 2,
            child: ChartPreviewWidget(
              config: _currentConfig,
              data: _chartData,
            ),
          ),
          
          // Configuration Panel (Collapsible)
          Expanded(
            child: ChartConfigurationPanel(
              config: _currentConfig,
              onConfigChanged: (config) => setState(() => _currentConfig = config),
            ),
          ),
          
          // Action Buttons
          Row(
            children: [
              TextButton(
                onPressed: _showAIAssistant,
                child: Text("🤖 AI Help"),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: _createChart,
                child: Text("Create Chart"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### **Pivot Builder Interface**
```dart
// presentation/widgets/pivot/pivot_builder_panel.dart
class PivotBuilderPanel extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AI Suggestion Bar
        AIPivotSuggestionBar(
          sourceRange: widget.sourceRange,
          onSuggestionApplied: _applyAISuggestion,
        ),
        
        // Field List (Draggable)
        Expanded(
          flex: 1,
          child: PivotFieldList(
            fields: _availableFields,
            onFieldDragged: (field) => _startDrag(field),
          ),
        ),
        
        // Drop Zones
        Expanded(
          flex: 2,
          child: Row(
            children: [
              // Rows Drop Zone
              Expanded(
                child: DropZone(
                  title: "Rows",
                  fields: _rowFields,
                  onFieldDropped: (field) => _addToRows(field),
                  onFieldRemoved: (field) => _removeFromRows(field),
                ),
              ),
              
              // Columns Drop Zone  
              Expanded(
                child: DropZone(
                  title: "Columns",
                  fields: _columnFields,
                  onFieldDropped: (field) => _addToColumns(field),
                ),
              ),
              
              // Values Drop Zone
              Expanded(
                child: DropZone(
                  title: "Values",
                  fields: _valueFields,
                  onFieldDropped: (field) => _addToValues(field),
                  showAggregationSelector: true,
                ),
              ),
            ],
          ),
        ),
        
        // Live Pivot Preview
        Expanded(
          flex: 2,
          child: PivotTablePreview(
            configuration: _currentConfig,
            maxPreviewRows: 50,
          ),
        ),
        
        // Action Bar
        PivotActionBar(
          onCreatePivot: _createPivot,
          onExportPivot: _exportPivot,
          onAIOptimize: _optimizeWithAI,
        ),
      ],
    );
  }
}
```

---

## ⚡ PERFORMANCE OPTIMIZATION STRATEGY

### **1. Chart Rendering Optimization**
```dart
// core/chart_engine/chart_renderer.dart
class ChartRenderer {
  static const int MAX_DATA_POINTS = 5000;
  static const int SAMPLE_SIZE_THRESHOLD = 1000;
  
  Future<Widget> renderChart(ChartConfig config, List<ChartData> data) async {
    // 1. Data sampling for large datasets
    final optimizedData = _optimizeDataForRendering(data, config.type);
    
    // 2. Use appropriate engine based on data size
    final engine = _selectOptimalEngine(config, optimizedData.length);
    
    // 3. Render with performance monitoring
    final stopwatch = Stopwatch()..start();
    final chart = await engine.buildChart(config, optimizedData);
    stopwatch.stop();
    
    _logPerformanceMetrics(config.type, optimizedData.length, stopwatch.elapsedMilliseconds);
    
    return chart;
  }
  
  List<ChartData> _optimizeDataForRendering(List<ChartData> data, ChartType type) {
    if (data.length <= MAX_DATA_POINTS) return data;
    
    // Apply sampling strategy based on chart type
    switch (type) {
      case ChartType.line:
      case ChartType.area:
        return _timeSeriesSampling(data);
      case ChartType.scatter:
        return _randomSampling(data);
      case ChartType.bar:
      case ChartType.column:
        return _topNSampling(data);
      default:
        return data.take(MAX_DATA_POINTS).toList();
    }
  }
}
```

### **2. Pivot Table Performance**
```dart
// core/pivot_engine/performance_optimizer.dart
class PivotPerformanceOptimizer {
  static const int MAX_PIVOT_CELLS = 10000;
  static const int CHUNK_SIZE = 1000;
  
  Future<PivotResult> processLargeDataset(
    List<Map<String, dynamic>> data,
    PivotConfiguration config
  ) async {
    if (data.length <= CHUNK_SIZE) {
      return _processDirectly(data, config);
    }
    
    // Process in chunks with progress reporting
    final result = PivotResult.empty();
    final chunks = _chunkData(data, CHUNK_SIZE);
    
    for (int i = 0; i < chunks.length; i++) {
      final chunkResult = await _processChunk(chunks[i], config);
      result.merge(chunkResult);
      
      // Report progress
      _notifyProgress((i + 1) / chunks.length);
    }
    
    return result;
  }
  
  void _notifyProgress(double progress) {
    // Update UI with progress
    _progressController?.add(progress);
  }
}
```


---

## 🎨 COMPLETE CODE EXAMPLES

### **1. Chart Builder Complete Implementation**

```dart
// presentation/screens/chart_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartBuilderScreen extends StatefulWidget {
  final Range selectedRange;
  
  const ChartBuilderScreen({required this.selectedRange, Key? key}) : super(key: key);
  
  @override
  State<ChartBuilderScreen> createState() => _ChartBuilderScreenState();
}

class _ChartBuilderScreenState extends State<ChartBuilderScreen> {
  ChartType _selectedType = ChartType.bar;
  ChartConfig? _currentConfig;
  List<ChartData> _chartData = [];
  List<ChartRecommendation> _aiSuggestions = [];
  bool _isLoadingAI = false;
  
  @override
  void initState() {
    super.initState();
    _loadChartData();
    _getAISuggestions();
  }
  
  Future<void> _loadChartData() async {
    final data = await SpreadsheetDataSource.getDataFromRange(widget.selectedRange);
    setState(() {
      _chartData = data;
      _currentConfig = ChartConfig.defaultFor(_selectedType, data);
    });
  }
  
  Future<void> _getAISuggestions() async {
    setState(() => _isLoadingAI = true);
    try {
      final suggestions = await ChartAIService().suggestCharts(
        widget.selectedRange,
        null, // User can add intent later
      );
      setState(() {
        _aiSuggestions = suggestions;
        _isLoadingAI = false;
      });
    } catch (e) {
      setState(() => _isLoadingAI = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI suggestions failed: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Chart'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showAIAssistant,
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Suggestion Bar
          if (_aiSuggestions.isNotEmpty)
            _buildAISuggestionBar(),
          
          // Chart Type Selector
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: ChartType.values.length,
              itemBuilder: (context, index) {
                final type = ChartType.values[index];
                return _buildChartTypeCard(type);
              },
            ),
          ),
          
          // Live Preview
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _currentConfig != null
                  ? ChartPreviewWidget(
                      config: _currentConfig!,
                      data: _chartData,
                    )
                  : Center(child: CircularProgressIndicator()),
            ),
          ),
          
          // Configuration Panel
          Expanded(
            flex: 2,
            child: ChartConfigurationPanel(
              config: _currentConfig,
              onConfigChanged: (newConfig) {
                setState(() => _currentConfig = newConfig);
              },
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showAIAssistant,
                  icon: Icon(Icons.auto_awesome),
                  label: Text('AI Help'),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _createChart,
                  icon: Icon(Icons.check),
                  label: Text('Create Chart'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildAISuggestionBar() {
    return Container(
      height: 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _aiSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _aiSuggestions[index];
          return Card(
            margin: EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _applySuggestion(suggestion),
              child: Container(
                width: 280,
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'AI Suggestion',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${(suggestion.confidence * 100).toInt()}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      suggestion.chartType.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        suggestion.reasoning,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildChartTypeCard(ChartType type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _currentConfig = ChartConfig.defaultFor(type, _chartData);
        });
      },
      child: Container(
        width: 100,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              size: 32,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _applySuggestion(ChartRecommendation suggestion) {
    setState(() {
      _selectedType = suggestion.chartType;
      _currentConfig = suggestion.config;
    });
  }
  
  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AIChartAssistantDialog(
        currentRange: widget.selectedRange,
        onConfigGenerated: (config) {
          setState(() => _currentConfig = config);
          Navigator.pop(context);
        },
      ),
    );
  }
  
  Future<void> _createChart() async {
    if (_currentConfig == null) return;
    
    try {
      await ChartService().createChart(_currentConfig!);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chart created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create chart: $e')),
      );
    }
  }
}
```



### **2. Chart Preview Widget with fl_chart**

```dart
// presentation/widgets/charts/chart_preview_widget.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartPreviewWidget extends StatelessWidget {
  final ChartConfig config;
  final List<ChartData> data;
  
  const ChartPreviewWidget({
    required this.config,
    required this.data,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.title.isNotEmpty)
            Text(
              config.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (config.subtitle.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                config.subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          SizedBox(height: 16),
          Expanded(
            child: _buildChart(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChart() {
    switch (config.type) {
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.line:
        return _buildLineChart();
      case ChartType.pie:
        return _buildPieChart();
      case ChartType.scatter:
        return _buildScatterChart();
      case ChartType.area:
        return _buildAreaChart();
      default:
        return Center(child: Text('Chart type not supported'));
    }
  }
  
  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxValue() * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${data[groupIndex].label}\n${rod.toY.toStringAsFixed(1)}',
                TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      data[value.toInt()].label,
                      style: TextStyle(fontSize: 10),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: config.series[0].color,
                width: 20,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getMaxValue() / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
      ),
      swapAnimationDuration: Duration(milliseconds: 500),
      swapAnimationCurve: Curves.easeInOut,
    );
  }
  
  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${data[spot.x.toInt()].label}\n${spot.y.toStringAsFixed(2)}',
                  TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getMaxValue() / 5,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      data[value.toInt()].label,
                      style: TextStyle(fontSize: 10),
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: _getMaxValue() * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: config.series[0].color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: config.type == ChartType.area,
              color: config.series[0].color.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: data.asMap().entries.map((entry) {
          final percentage = (entry.value.value / _getTotalValue()) * 100;
          return PieChartSectionData(
            color: config.series[0].colors[entry.key % config.series[0].colors.length],
            value: entry.value.value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Handle touch events
          },
        ),
      ),
    );
  }
  
  Widget _buildScatterChart() {
    return ScatterChart(
      ScatterChartData(
        scatterSpots: data.asMap().entries.map((entry) {
          return ScatterSpot(
            entry.key.toDouble(),
            entry.value.value,
            color: config.series[0].color,
            radius: 8,
          );
        }).toList(),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: _getMaxValue() * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(show: true),
      ),
    );
  }
  
  Widget _buildAreaChart() {
    return _buildLineChart(); // Area chart is line chart with filled area
  }
  
  double _getMaxValue() {
    if (data.isEmpty) return 100;
    return data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
  }
  
  double _getTotalValue() {
    if (data.isEmpty) return 0;
    return data.map((d) => d.value).reduce((a, b) => a + b);
  }
}
```

### **3. Pivot Table Builder with Drag & Drop**

```dart
// presentation/screens/pivot_builder_screen.dart
import 'package:flutter/material.dart';

class PivotBuilderScreen extends StatefulWidget {
  final Range sourceRange;
  
  const PivotBuilderScreen({required this.sourceRange, Key? key}) : super(key: key);
  
  @override
  State<PivotBuilderScreen> createState() => _PivotBuilderScreenState();
}

class _PivotBuilderScreenState extends State<PivotBuilderScreen> {
  List<PivotField> _availableFields = [];
  List<PivotField> _rowFields = [];
  List<PivotField> _columnFields = [];
  List<PivotField> _valueFields = [];
  List<PivotField> _filterFields = [];
  
  PivotConfiguration? _currentConfig;
  Map<String, dynamic>? _pivotResult;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _loadFields();
  }
  
  Future<void> _loadFields() async {
    final headers = await SpreadsheetDataSource.getHeaders(widget.sourceRange);
    setState(() {
      _availableFields = headers.map((header) => PivotField(
        name: header,
        sourceColumn: header,
        type: PivotFieldType.row,
      )).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Pivot Table'),
        actions: [
          IconButton(
            icon: Icon(Icons.auto_awesome),
            onPressed: _showAIAssistant,
          ),
        ],
      ),
      body: Column(
        children: [
          // Field List
          Container(
            height: 120,
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Available Fields',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _availableFields.length,
                    itemBuilder: (context, index) {
                      return _buildDraggableField(_availableFields[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Drop Zones
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropZone(
                            'Rows',
                            _rowFields,
                            Icons.view_list,
                            Colors.blue,
                            (field) => _addFieldToZone(field, PivotFieldType.row),
                            (field) => _removeFieldFromZone(field, PivotFieldType.row),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDropZone(
                            'Columns',
                            _columnFields,
                            Icons.view_column,
                            Colors.green,
                            (field) => _addFieldToZone(field, PivotFieldType.column),
                            (field) => _removeFieldFromZone(field, PivotFieldType.column),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropZone(
                            'Values',
                            _valueFields,
                            Icons.functions,
                            Colors.orange,
                            (field) => _addFieldToZone(field, PivotFieldType.value),
                            (field) => _removeFieldFromZone(field, PivotFieldType.value),
                            showAggregation: true,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDropZone(
                            'Filters',
                            _filterFields,
                            Icons.filter_alt,
                            Colors.purple,
                            (field) => _addFieldToZone(field, PivotFieldType.filter),
                            (field) => _removeFieldFromZone(field, PivotFieldType.filter),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Pivot Preview
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isProcessing
                  ? Center(child: CircularProgressIndicator())
                  : _pivotResult != null
                      ? PivotTablePreview(result: _pivotResult!)
                      : Center(
                          child: Text(
                            'Drag fields to zones to create pivot table',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
            ),
          ),
          
          // Action Bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshPreview,
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showAIAssistant,
                  icon: Icon(Icons.auto_awesome),
                  label: Text('AI Optimize'),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _canCreatePivot() ? _createPivot : null,
                  icon: Icon(Icons.check),
                  label: Text('Create Pivot'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildDraggableField(PivotField field) {
    return Draggable<PivotField>(
      data: field,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            field.name,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildFieldChip(field, null),
      ),
      child: _buildFieldChip(field, null),
    );
  }
  
  Widget _buildFieldChip(PivotField field, Color? color) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Text(
            field.name,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropZone(
    String title,
    List<PivotField> fields,
    IconData icon,
    Color color,
    Function(PivotField) onAdd,
    Function(PivotField) onRemove, {
    bool showAggregation = false,
  }) {
    return DragTarget<PivotField>(
      onAccept: (field) {
        onAdd(field);
        _refreshPreview();
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering ? color : Colors.grey[300]!,
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: fields.isEmpty
                    ? Center(
                        child: Text(
                          'Drop fields here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: fields.length,
                        itemBuilder: (context, index) {
                          return _buildDroppedField(
                            fields[index],
                            color,
                            onRemove,
                            showAggregation,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDroppedField(
    PivotField field,
    Color color,
    Function(PivotField) onRemove,
    bool showAggregation,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (showAggregation)
                  DropdownButton<AggregationType>(
                    value: field.aggregation,
                    isDense: true,
                    underline: SizedBox(),
                    items: AggregationType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.displayName,
                          style: TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          field.aggregation = value;
                        });
                        _refreshPreview();
                      }
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16),
            onPressed: () => onRemove(field),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
  
  void _addFieldToZone(PivotField field, PivotFieldType type) {
    setState(() {
      final newField = PivotField(
        name: field.name,
        sourceColumn: field.sourceColumn,
        type: type,
        aggregation: type == PivotFieldType.value 
            ? AggregationType.sum 
            : AggregationType.count,
      );
      
      switch (type) {
        case PivotFieldType.row:
          _rowFields.add(newField);
          break;
        case PivotFieldType.column:
          _columnFields.add(newField);
          break;
        case PivotFieldType.value:
          _valueFields.add(newField);
          break;
        case PivotFieldType.filter:
          _filterFields.add(newField);
          break;
      }
    });
  }
  
  void _removeFieldFromZone(PivotField field, PivotFieldType type) {
    setState(() {
      switch (type) {
        case PivotFieldType.row:
          _rowFields.remove(field);
          break;
        case PivotFieldType.column:
          _columnFields.remove(field);
          break;
        case PivotFieldType.value:
          _valueFields.remove(field);
          break;
        case PivotFieldType.filter:
          _filterFields.remove(field);
          break;
      }
    });
    _refreshPreview();
  }
  
  Future<void> _refreshPreview() async {
    if (!_canCreatePivot()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final config = PivotConfiguration(
        sourceRange: widget.sourceRange,
        rowFields: _rowFields,
        columnFields: _columnFields,
        valueFields: _valueFields,
        filterFields: _filterFields,
      );
      
      final result = await PivotEngine().generatePivot(config);
      setState(() {
        _currentConfig = config;
        _pivotResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e')),
      );
    }
  }
  
  bool _canCreatePivot() {
    return _rowFields.isNotEmpty || _columnFields.isNotEmpty;
  }
  
  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AIPivotAssistantDialog(
        sourceRange: widget.sourceRange,
        onConfigGenerated: (config) {
          setState(() {
            _rowFields = config.rowFields;
            _columnFields = config.columnFields;
            _valueFields = config.valueFields;
            _filterFields = config.filterFields;
          });
          _refreshPreview();
          Navigator.pop(context);
        },
      ),
    );
  }
  
  Future<void> _createPivot() async {
    if (_currentConfig == null) return;
    
    try {
      await PivotService().createPivot(_currentConfig!);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pivot table created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create pivot: $e')),
      );
    }
  }
}
```



---

## 🚀 IMPLEMENTATION TIMELINE & MILESTONES

### **Week 1-2: Chart Engine Foundation**

#### **Days 1-3: Setup & Dependencies**
```yaml
Tasks:
  - Add fl_chart dependency (v0.68.0)
  - Create chart_engine package structure
  - Set up chart entity models
  - Create chart data source adapter

Deliverables:
  - ✅ Chart models defined
  - ✅ Data source integration
  - ✅ Basic architecture setup

Developer Hours: 16-20 hours
```

#### **Days 4-7: Basic Chart Types**
```yaml
Tasks:
  - Implement Bar Chart widget
  - Implement Line Chart widget
  - Implement Pie Chart widget
  - Add chart configuration panel
  - Create chart preview system

Deliverables:
  - ✅ 3 working chart types
  - ✅ Live preview functionality
  - ✅ Basic customization options

Developer Hours: 24-30 hours
```

#### **Days 8-10: AI Chart Integration**
```yaml
Tasks:
  - Integrate AI chart recommendation engine
  - Build chart suggestion UI
  - Add natural language chart creation
  - Test AI accuracy with sample data

Deliverables:
  - ✅ AI-powered chart suggestions
  - ✅ Voice command support
  - ✅ Smart chart type selection

Developer Hours: 20-24 hours
```

### **Week 3-4: Advanced Charts & Export**

#### **Days 11-14: Advanced Chart Features**
```yaml
Tasks:
  - Add Scatter and Area charts
  - Implement chart animations
  - Add touch interactions (zoom, pan)
  - Multi-series chart support
  - Real-time data updates

Deliverables:
  - ✅ 5 total chart types
  - ✅ Interactive charts
  - ✅ Animation system

Developer Hours: 28-32 hours
```

#### **Days 15-17: Chart Export & Styling**
```yaml
Tasks:
  - PNG/PDF export functionality
  - Custom theme system
  - Chart styling editor
  - Performance optimization

Deliverables:
  - ✅ Export to image/PDF
  - ✅ Custom themes
  - ✅ Performance benchmarks

Developer Hours: 20-24 hours
```

### **Week 5-6: Pivot Table Engine**

#### **Days 18-21: Pivot Foundation**
```yaml
Tasks:
  - Create pivot engine architecture
  - Implement data aggregation engine
  - Build grouping and calculation logic
  - Create pivot data models

Deliverables:
  - ✅ Working aggregation engine
  - ✅ Dynamic grouping
  - ✅ Core pivot calculations

Developer Hours: 28-32 hours
```

#### **Days 22-25: Pivot UI with Drag-Drop**
```yaml
Tasks:
  - Build drag-and-drop field system
  - Create drop zone UI components
  - Implement field configuration panels
  - Add pivot table preview widget

Deliverables:
  - ✅ Drag-drop interface
  - ✅ Visual drop zones
  - ✅ Live pivot preview

Developer Hours: 28-32 hours
```

#### **Days 26-28: AI Pivot Integration**
```yaml
Tasks:
  - Integrate AI pivot recommendations
  - Build pivot suggestion UI
  - Add smart field detection
  - Natural language pivot creation

Deliverables:
  - ✅ AI-powered pivot suggestions
  - ✅ Auto field mapping
  - ✅ Voice pivot commands

Developer Hours: 20-24 hours
```

### **Week 7-8: Performance & Polish**

#### **Days 29-32: Performance Optimization**
```yaml
Tasks:
  - Large dataset optimization (100K+ rows)
  - Chart rendering optimization
  - Pivot calculation caching
  - Memory management improvements
  - GPU acceleration integration

Deliverables:
  - ✅ Handle 100K+ rows smoothly
  - ✅ <2s chart rendering
  - ✅ Efficient memory usage

Developer Hours: 28-32 hours
```

#### **Days 33-35: Testing & Bug Fixes**
```yaml
Tasks:
  - Unit tests for chart engine
  - Integration tests for pivot
  - UI/UX testing on multiple devices
  - Performance profiling
  - Bug fixes and refinements

Deliverables:
  - ✅ 90%+ test coverage
  - ✅ Zero critical bugs
  - ✅ Smooth mobile experience

Developer Hours: 20-24 hours
```

#### **Days 36-40: Documentation & Release**
```yaml
Tasks:
  - API documentation
  - User guide and tutorials
  - Video demonstrations
  - Beta testing preparation
  - App store assets

Deliverables:
  - ✅ Complete documentation
  - ✅ Tutorial videos
  - ✅ Beta-ready build

Developer Hours: 20-24 hours
```

---

## 📊 PERFORMANCE BENCHMARKS

### **Target Performance Metrics**

#### **Chart Rendering Performance**
```yaml
Small Dataset (< 100 points):
  - Initial Render: < 200ms
  - Animation: 60 FPS
  - Touch Response: < 16ms
  - Memory Usage: < 5MB

Medium Dataset (100-1000 points):
  - Initial Render: < 500ms
  - Animation: 60 FPS
  - Touch Response: < 16ms
  - Memory Usage: < 15MB

Large Dataset (1000-5000 points):
  - Initial Render: < 1500ms
  - Animation: 30 FPS (acceptable)
  - Touch Response: < 32ms
  - Memory Usage: < 30MB
  - Data Sampling: Enabled

Very Large Dataset (> 5000 points):
  - Initial Render: < 2000ms
  - Animation: Disabled
  - Data Sampling: Required
  - Memory Usage: < 50MB
  - Warning: Show to user
```

#### **Pivot Table Performance**
```yaml
Small Dataset (< 1K rows):
  - Aggregation: < 100ms
  - UI Render: < 200ms
  - Memory: < 5MB
  
Medium Dataset (1K-10K rows):
  - Aggregation: < 500ms
  - UI Render: < 500ms
  - Memory: < 20MB
  - Progress: Show indicator

Large Dataset (10K-100K rows):
  - Aggregation: < 3000ms
  - UI Render: < 1000ms
  - Memory: < 100MB
  - Progress: Required
  - Chunking: Enabled

Very Large Dataset (> 100K rows):
  - Aggregation: < 10000ms
  - UI Render: < 2000ms
  - Memory: < 200MB
  - Progress: Detailed
  - Chunking: Required
  - Caching: Enabled
  - Warning: Show limitations
```

### **Memory Management Strategy**

```dart
// core/utils/performance_monitor.dart
class PerformanceMonitor {
  static const int MEMORY_WARNING_THRESHOLD = 150 * 1024 * 1024; // 150MB
  static const int MEMORY_CRITICAL_THRESHOLD = 250 * 1024 * 1024; // 250MB
  
  static Future<void> checkMemoryUsage() async {
    final memoryInfo = await DeviceInfoPlugin().getMemoryInfo();
    final currentUsage = memoryInfo.totalMemory - memoryInfo.availableMemory;
    
    if (currentUsage > MEMORY_CRITICAL_THRESHOLD) {
      // Force garbage collection
      _forceClearCache();
      _showMemoryWarning('Critical');
    } else if (currentUsage > MEMORY_WARNING_THRESHOLD) {
      _showMemoryWarning('Warning');
    }
  }
  
  static void _forceClearCache() {
    ChartCache.clear();
    PivotCache.clear();
    // Force GC
    System.gc();
  }
}
```



---

## 📱 MOBILE-FIRST UI/UX DESIGN PATTERNS

### **Touch-Optimized Interactions**

#### **1. Chart Gesture Controls**
```dart
// presentation/widgets/charts/gesture_chart_wrapper.dart
class GestureChartWrapper extends StatefulWidget {
  final Widget chart;
  final ChartConfig config;
  
  @override
  State<GestureChartWrapper> createState() => _GestureChartWrapperState();
}

class _GestureChartWrapperState extends State<GestureChartWrapper> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        // Start pinch-to-zoom
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = details.scale.clamp(0.5, 3.0);
          _offset = details.focalPoint;
        });
      },
      onDoubleTap: () {
        // Reset zoom
        setState(() {
          _scale = 1.0;
          _offset = Offset.zero;
        });
      },
      onLongPress: () {
        // Show context menu
        _showChartContextMenu();
      },
      child: Transform.scale(
        scale: _scale,
        child: Transform.translate(
          offset: _offset,
          child: widget.chart,
        ),
      ),
    );
  }
  
  void _showChartContextMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Chart'),
            onTap: () => _editChart(),
          ),
          ListTile(
            leading: Icon(Icons.file_download),
            title: Text('Export as Image'),
            onTap: () => _exportChart(),
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete Chart'),
            onTap: () => _deleteChart(),
          ),
        ],
      ),
    );
  }
}
```

#### **2. Haptic Feedback Integration**
```dart
// core/utils/haptic_feedback.dart
import 'package:flutter/services.dart';

class ChartHaptics {
  static void onFieldDragged() {
    HapticFeedback.selectionClick();
  }
  
  static void onFieldDropped() {
    HapticFeedback.mediumImpact();
  }
  
  static void onChartCreated() {
    HapticFeedback.heavyImpact();
  }
  
  static void onError() {
    HapticFeedback.vibrate();
  }
  
  static void onDataPointTapped() {
    HapticFeedback.lightImpact();
  }
}
```

#### **3. Progressive Disclosure UI**
```dart
// presentation/widgets/charts/expandable_config_panel.dart
class ExpandableConfigPanel extends StatefulWidget {
  final ChartConfig config;
  final Function(ChartConfig) onChanged;
  
  @override
  State<ExpandableConfigPanel> createState() => _ExpandableConfigPanelState();
}

class _ExpandableConfigPanelState extends State<ExpandableConfigPanel> {
  bool _showBasicSettings = true;
  bool _showAdvancedSettings = false;
  bool _showDataSettings = false;
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Basic Settings (Always visible)
          ExpansionTile(
            title: Text('Basic Settings'),
            initiallyExpanded: _showBasicSettings,
            children: [
              _buildTitleEditor(),
              _buildColorPicker(),
              _buildChartSizeSelector(),
            ],
          ),
          
          // Advanced Settings (Collapsed by default)
          ExpansionTile(
            title: Text('Advanced Settings'),
            initiallyExpanded: _showAdvancedSettings,
            children: [
              _buildAxisConfiguration(),
              _buildLegendSettings(),
              _buildAnimationControls(),
              _buildTooltipSettings(),
            ],
          ),
          
          // Data Settings
          ExpansionTile(
            title: Text('Data Settings'),
            initiallyExpanded: _showDataSettings,
            children: [
              _buildDataRangeSelector(),
              _buildSeriesConfiguration(),
              _buildDataFilterOptions(),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTitleEditor() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Chart Title',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          widget.config.title = value;
          widget.onChanged(widget.config);
        },
      ),
    );
  }
}
```

### **Responsive Layout Strategy**

#### **Adaptive Chart Sizing**
```dart
// core/utils/responsive_chart_size.dart
class ResponsiveChartSize {
  static Size getOptimalSize(BuildContext context, ChartType type) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    switch (type) {
      case ChartType.pie:
      case ChartType.doughnut:
        // Square aspect ratio for circular charts
        final size = isLandscape 
            ? screenSize.height * 0.6 
            : screenSize.width * 0.8;
        return Size(size, size);
        
      case ChartType.bar:
      case ChartType.column:
        // Taller for vertical charts
        return Size(
          screenSize.width * 0.9,
          isLandscape ? screenSize.height * 0.7 : screenSize.height * 0.4,
        );
        
      case ChartType.line:
      case ChartType.area:
        // Wider for time-series
        return Size(
          screenSize.width * 0.95,
          isLandscape ? screenSize.height * 0.6 : screenSize.height * 0.35,
        );
        
      default:
        return Size(screenSize.width * 0.9, screenSize.height * 0.4);
    }
  }
}
```

---

## 🔗 INTEGRATION WITH EXISTING APP

### **1. Editor Screen Integration**

```dart
// lib/presentation/editor/editor_screen.dart (additions)
class EditorScreen extends StatefulWidget {
  // ... existing code ...
}

class _EditorScreenState extends State<EditorScreen> {
  // Add chart management
  List<ChartEntity> _charts = [];
  List<PivotTableEntity> _pivots = [];
  
  // Add to bottom toolbar
  Widget _buildBottomToolbar() {
    return BottomToolbar(
      onFormatTap: _showFormatDialog,
      onFunctionTap: _showFunctionPicker,
      onChartTap: _createChart, // NEW
      onPivotTap: _createPivot, // NEW
      // ... existing buttons ...
    );
  }
  
  void _createChart() async {
    final selectedRange = _getSelectedRange();
    if (selectedRange == null || selectedRange.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select data range first')),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChartBuilderScreen(
          selectedRange: selectedRange,
        ),
      ),
    );
    
    if (result == true) {
      _loadCharts();
    }
  }
  
  void _createPivot() async {
    final selectedRange = _getSelectedRange();
    if (selectedRange == null || selectedRange.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select data range first')),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PivotBuilderScreen(
          sourceRange: selectedRange,
        ),
      ),
    );
    
    if (result == true) {
      _loadPivots();
    }
  }
  
  Future<void> _loadCharts() async {
    final charts = await ChartRepository().getChartsForSheet(widget.sheetId);
    setState(() => _charts = charts);
  }
  
  Future<void> _loadPivots() async {
    final pivots = await PivotRepository().getPivotsForSheet(widget.sheetId);
    setState(() => _pivots = pivots);
  }
}
```

### **2. AI Agent Integration**

```dart
// lib/domain/services/copilot/local_agent_service.dart (additions)
class LocalAgentService {
  // Add new tools for AI agent
  
  Map<String, dynamic> _getAvailableTools() {
    return {
      'inspect_sheet': _inspectSheetTool,
      'get_sheet_headers': _getHeadersTool,
      'build_pipeline': _buildPipelineTool,
      'create_chart': _createChartTool, // NEW
      'create_pivot': _createPivotTool, // NEW
    };
  }
  
  // New tool: create_chart
  final _createChartTool = {
    'type': 'function',
    'function': {
      'name': 'create_chart',
      'description': '''Create a chart from spreadsheet data. Automatically selects 
      the best chart type based on data structure. Supports bar, line, pie, scatter, 
      area, and combo charts.''',
      'parameters': {
        'type': 'object',
        'properties': {
          'data_range': {
            'type': 'string',
            'description': 'Cell range for chart data (e.g., "A1:C10")',
          },
          'chart_type': {
            'type': 'string',
            'enum': ['bar', 'line', 'pie', 'scatter', 'area', 'auto'],
            'description': 'Type of chart to create. Use "auto" for AI suggestion.',
          },
          'title': {
            'type': 'string',
            'description': 'Chart title',
          },
          'x_axis_label': {
            'type': 'string',
            'description': 'Label for X axis',
          },
          'y_axis_label': {
            'type': 'string',
            'description': 'Label for Y axis',
          },
        },
        'required': ['data_range'],
      },
    },
  };
  
  // New tool: create_pivot
  final _createPivotTool = {
    'type': 'function',
    'function': {
      'name': 'create_pivot',
      'description': '''Create a pivot table to summarize and analyze data. 
      Automatically groups data by specified fields and calculates aggregations.''',
      'parameters': {
        'type': 'object',
        'properties': {
          'data_range': {
            'type': 'string',
            'description': 'Source data range (e.g., "A1:E100")',
          },
          'row_fields': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Column names to use as row groupings',
          },
          'column_fields': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Column names to use as column groupings',
          },
          'value_fields': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'field': {'type': 'string'},
                'aggregation': {
                  'type': 'string',
                  'enum': ['sum', 'count', 'average', 'max', 'min'],
                },
              },
            },
            'description': 'Fields to aggregate with their aggregation types',
          },
        },
        'required': ['data_range', 'row_fields', 'value_fields'],
      },
    },
  };
  
  Future<Map<String, dynamic>> _handleCreateChart(
    Map<String, dynamic> args,
  ) async {
    try {
      final range = args['data_range'] as String;
      final chartType = args['chart_type'] ?? 'auto';
      final title = args['title'] ?? '';
      
      // Parse range and get data
      final parsedRange = RangeParser.parse(range);
      final data = await _getDataFromRange(parsedRange);
      
      // Create chart config
      ChartConfig config;
      if (chartType == 'auto') {
        // Use AI to determine best chart type
        final suggestions = await ChartAIService().suggestCharts(
          parsedRange,
          'Auto-create chart from selected data',
        );
        config = suggestions.first.config;
      } else {
        config = ChartConfig.create(
          type: ChartType.fromString(chartType),
          title: title,
          data: data,
        );
      }
      
      // Create chart
      final chart = await ChartService().createChart(config);
      
      return {
        'success': true,
        'chart_id': chart.id,
        'message': 'Chart created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  Future<Map<String, dynamic>> _handleCreatePivot(
    Map<String, dynamic> args,
  ) async {
    try {
      final range = args['data_range'] as String;
      final rowFields = (args['row_fields'] as List).cast<String>();
      final valueFields = args['value_fields'] as List;
      
      // Parse range
      final parsedRange = RangeParser.parse(range);
      
      // Build pivot configuration
      final config = PivotConfiguration(
        sourceRange: parsedRange,
        rowFields: rowFields.map((name) => PivotField(
          name: name,
          sourceColumn: name,
          type: PivotFieldType.row,
        )).toList(),
        valueFields: valueFields.map((v) => PivotField(
          name: v['field'],
          sourceColumn: v['field'],
          type: PivotFieldType.value,
          aggregation: AggregationType.fromString(v['aggregation']),
        )).toList(),
      );
      
      // Create pivot
      final pivot = await PivotService().createPivot(config);
      
      return {
        'success': true,
        'pivot_id': pivot.id,
        'message': 'Pivot table created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
```



---

## 🎯 AI-POWERED FEATURES

### **Natural Language Chart Creation**

#### **Voice Command Examples**
```
User: "Create a bar chart showing sales by region"

AI Processing:
1. Detect intent: Chart creation
2. Extract parameters:
   - Chart type: Bar
   - Data: Sales column
   - Grouping: Region column
3. Find relevant columns in active sheet
4. Generate chart configuration
5. Create and display chart

AI Response: "I've created a bar chart showing sales data grouped by 
region. The chart shows 5 regions with Mumbai having the highest sales 
at ₹2.5M."
```

```
User: "Show me a trend of monthly revenue"

AI Processing:
1. Detect intent: Time-series visualization
2. Chart type: Line (best for trends)
3. Find date/month column and revenue column
4. Sort data chronologically
5. Create line chart with time on X-axis

AI Response: "Here's a line chart showing your monthly revenue trend. 
There's a 15% growth from January to June, with a peak in March at ₹450K."
```

#### **Smart Chart Recommendations**
```dart
// domain/services/chart_ai_service.dart (complete implementation)
class ChartAIService {
  final GeminiService _gemini;
  
  Future<List<ChartRecommendation>> suggestCharts(
    Range dataRange,
    String? userIntent,
  ) async {
    // 1. Analyze data structure
    final analysis = await _analyzeData(dataRange);
    
    // 2. Build AI prompt
    final prompt = '''
    Analyze this spreadsheet data and recommend the 3 best chart types:
    
    Data Structure:
    - Rows: ${analysis.rowCount}
    - Columns: ${analysis.columnCount}
    - Column Types: ${analysis.columnTypes.entries.map((e) => '${e.key}: ${e.value}').join(', ')}
    - Has Time Data: ${analysis.hasTimeSeriesData}
    - Has Categories: ${analysis.hasCategoricalData}
    - Numerical Columns: ${analysis.numericalColumns.join(', ')}
    
    Sample Data:
    ${analysis.sampleData}
    
    User Intent: ${userIntent ?? 'General visualization'}
    
    For each recommendation, provide:
    1. Chart type (bar, line, pie, scatter, area, combo)
    2. Confidence score (0.0 to 1.0)
    3. Reasoning (why this chart is suitable)
    4. Suggested X-axis column
    5. Suggested Y-axis column(s)
    6. Title suggestion
    7. Key insights this chart will reveal
    
    Return as JSON array.
    ''';
    
    // 3. Call Gemini API
    final response = await _gemini.generateContent(prompt);
    
    // 4. Parse recommendations
    final recommendations = _parseRecommendations(response, dataRange);
    
    // 5. Sort by confidence
    recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return recommendations.take(3).toList();
  }
  
  Future<DataAnalysis> _analyzeData(Range range) async {
    final data = await SpreadsheetDataSource.getRangeData(range);
    final headers = data.isNotEmpty ? data.first.keys.toList() : [];
    
    // Analyze column types
    final columnTypes = <String, DataType>{};
    final numericalColumns = <String>[];
    final categoricalColumns = <String>[];
    final dateColumns = <String>[];
    
    for (final header in headers) {
      final columnData = data.map((row) => row[header]).toList();
      final type = _detectColumnType(columnData);
      
      columnTypes[header] = type;
      
      if (type == DataType.number) {
        numericalColumns.add(header);
      } else if (type == DataType.date) {
        dateColumns.add(header);
      } else {
        categoricalColumns.add(header);
      }
    }
    
    // Calculate cardinality for categorical columns
    final cardinality = <String, int>{};
    for (final col in categoricalColumns) {
      final uniqueValues = data.map((row) => row[col]).toSet().length;
      cardinality[col] = uniqueValues;
    }
    
    return DataAnalysis(
      rowCount: data.length,
      columnCount: headers.length,
      columnTypes: columnTypes,
      numericalColumns: numericalColumns,
      categoricalColumns: categoricalColumns,
      dateColumns: dateColumns,
      hasTimeSeriesData: dateColumns.isNotEmpty,
      hasCategoricalData: categoricalColumns.isNotEmpty,
      cardinality: cardinality,
      sampleData: _formatSampleData(data.take(5).toList()),
    );
  }
  
  DataType _detectColumnType(List<dynamic> columnData) {
    int numberCount = 0;
    int dateCount = 0;
    int textCount = 0;
    
    for (final value in columnData.take(20)) {
      if (value == null) continue;
      
      if (value is num) {
        numberCount++;
      } else if (_isDate(value.toString())) {
        dateCount++;
      } else {
        textCount++;
      }
    }
    
    if (numberCount > columnData.length * 0.6) return DataType.number;
    if (dateCount > columnData.length * 0.6) return DataType.date;
    return DataType.text;
  }
  
  bool _isDate(String value) {
    final datePatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}$'),
      RegExp(r'^\d{2}/\d{2}/\d{4}$'),
      RegExp(r'^\d{2}-\d{2}-\d{4}$'),
    ];
    
    return datePatterns.any((pattern) => pattern.hasMatch(value));
  }
}
```

### **AI Pivot Table Suggestions**

```dart
// domain/services/pivot_ai_service.dart
class PivotAIService {
  final GeminiService _gemini;
  
  Future<List<PivotRecommendation>> suggestPivotTables(
    Range sourceRange,
    String? businessQuestion,
  ) async {
    final analysis = await _analyzeForPivot(sourceRange);
    
    final prompt = '''
    Analyze this data and suggest 3 pivot table configurations:
    
    Data Overview:
    - Rows: ${analysis.rowCount}
    - Columns: ${analysis.columns.join(', ')}
    - Categorical Fields: ${analysis.categoricalColumns.join(', ')}
    - Numerical Fields: ${analysis.numericalColumns.join(', ')}
    - Date Fields: ${analysis.dateColumns.join(', ')}
    
    Cardinality (unique values per column):
    ${analysis.cardinality.entries.map((e) => '${e.key}: ${e.value}').join('\n')}
    
    Sample Data:
    ${analysis.sampleData}
    
    Business Question: ${businessQuestion ?? 'General data analysis'}
    
    For each pivot configuration, provide:
    1. Row fields (dimensions for grouping)
    2. Column fields (cross-tabulation fields)
    3. Value fields with aggregation types (sum, count, average, etc.)
    4. Reasoning (what insights this pivot will reveal)
    5. Confidence score (0.0 to 1.0)
    6. Business value (how this helps decision-making)
    
    Return as JSON array.
    ''';
    
    final response = await _gemini.generateContent(prompt);
    final recommendations = _parsePivotRecommendations(response, sourceRange);
    
    recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
    return recommendations.take(3).toList();
  }
  
  Future<PivotAnalysis> _analyzeForPivot(Range range) async {
    final data = await SpreadsheetDataSource.getRangeData(range);
    final headers = data.isNotEmpty ? data.first.keys.toList() : [];
    
    // Find best candidates for row/column/value fields
    final categoricalColumns = <String>[];
    final numericalColumns = <String>[];
    final dateColumns = <String>[];
    final cardinality = <String, int>{};
    
    for (final header in headers) {
      final columnData = data.map((row) => row[header]).toList();
      final uniqueCount = columnData.toSet().length;
      cardinality[header] = uniqueCount;
      
      if (_isNumerical(columnData)) {
        numericalColumns.add(header);
      } else if (_isDate(columnData)) {
        dateColumns.add(header);
      } else if (uniqueCount < data.length * 0.5) {
        // Low cardinality = good for grouping
        categoricalColumns.add(header);
      }
    }
    
    return PivotAnalysis(
      rowCount: data.length,
      columns: headers,
      categoricalColumns: categoricalColumns,
      numericalColumns: numericalColumns,
      dateColumns: dateColumns,
      cardinality: cardinality,
      sampleData: _formatSampleData(data.take(10).toList()),
    );
  }
}
```



---

## 🔧 DEPENDENCIES & SETUP

### **pubspec.yaml Updates**

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies
  # ... your current dependencies ...
  
  # NEW: Chart Libraries
  fl_chart: ^0.68.0
  syncfusion_flutter_charts: ^26.2.4  # Optional for Pro features
  
  # NEW: Data Processing
  collection: ^1.18.0
  intl: ^0.19.0
  
  # NEW: Export & Image
  pdf: ^3.11.0
  path_provider: ^2.1.3
  screenshot: ^3.0.0
  
  # NEW: Performance
  flutter_isolate: ^2.0.4
  
  # Existing AI dependencies
  google_generative_ai: ^0.4.0
  http: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Testing
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

### **Android Configuration**

```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 24  // Required for advanced features
        targetSdkVersion 34
        
        // Enable multidex for large app
        multiDexEnabled true
    }
    
    buildTypes {
        release {
            // Enable ProGuard optimization
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            
            // Enable R8 full mode
            shrinkResources true
        }
    }
    
    // Performance optimizations
    packagingOptions {
        exclude 'META-INF/DEPENDENCIES'
        exclude 'META-INF/LICENSE'
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/NOTICE'
        exclude 'META-INF/NOTICE.txt'
    }
}

dependencies {
    // Existing dependencies
    
    // Multidex support
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### **iOS Configuration**

```xml
<!-- ios/Runner/Info.plist -->
<dict>
    <!-- Existing keys -->
    
    <!-- Enable file sharing for chart export -->
    <key>UIFileSharingEnabled</key>
    <true/>
    
    <!-- Support document types -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Chart Image</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.png</string>
                <string>public.jpeg</string>
            </array>
        </dict>
    </array>
</dict>
```

---

## 📊 TESTING STRATEGY

### **Unit Tests**

```dart
// test/domain/services/chart_ai_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('ChartAIService', () {
    late ChartAIService service;
    late MockGeminiService mockGemini;
    
    setUp(() {
      mockGemini = MockGeminiService();
      service = ChartAIService(gemini: mockGemini);
    });
    
    test('should suggest bar chart for categorical vs numerical data', () async {
      // Arrange
      final range = Range(startRow: 0, startCol: 0, endRow: 10, endCol: 2);
      final mockData = _generateMockCategoricalData();
      
      when(mockGemini.generateContent(any))
          .thenAnswer((_) async => _mockBarChartResponse());
      
      // Act
      final suggestions = await service.suggestCharts(range, null);
      
      // Assert
      expect(suggestions.length, greaterThan(0));
      expect(suggestions.first.chartType, ChartType.bar);
      expect(suggestions.first.confidence, greaterThan(0.7));
    });
    
    test('should suggest line chart for time-series data', () async {
      // Arrange
      final range = Range(startRow: 0, startCol: 0, endRow: 20, endCol: 2);
      
      when(mockGemini.generateContent(any))
          .thenAnswer((_) async => _mockLineChartResponse());
      
      // Act
      final suggestions = await service.suggestCharts(range, 'show trend');
      
      // Assert
      expect(suggestions.first.chartType, ChartType.line);
      expect(suggestions.first.reasoning, contains('trend'));
    });
    
    test('should suggest pie chart for proportional data', () async {
      // Arrange
      final range = Range(startRow: 0, startCol: 0, endRow: 5, endCol: 2);
      
      when(mockGemini.generateContent(any))
          .thenAnswer((_) async => _mockPieChartResponse());
      
      // Act
      final suggestions = await service.suggestCharts(range, 'show distribution');
      
      // Assert
      expect(suggestions.first.chartType, ChartType.pie);
    });
  });
  
  group('PivotAIService', () {
    late PivotAIService service;
    
    setUp(() {
      service = PivotAIService(gemini: MockGeminiService());
    });
    
    test('should suggest appropriate pivot configuration', () async {
      // Arrange
      final range = Range(startRow: 0, startCol: 0, endRow: 100, endCol: 5);
      
      // Act
      final suggestions = await service.suggestPivotTables(range, null);
      
      // Assert
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.rowFields, isNotEmpty);
      expect(suggestions.first.valueFields, isNotEmpty);
    });
  });
}
```

### **Integration Tests**

```dart
// integration_test/chart_creation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Chart Creation Flow', () {
    testWidgets('should create bar chart from selected range', (tester) async {
      // Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      // Select data range
      await tester.tap(find.text('A1'));
      await tester.drag(find.text('A1'), Offset(100, 100));
      await tester.pumpAndSettle();
      
      // Open chart builder
      await tester.tap(find.byIcon(Icons.insert_chart));
      await tester.pumpAndSettle();
      
      // Select bar chart
      await tester.tap(find.text('Bar Chart'));
      await tester.pumpAndSettle();
      
      // Verify preview
      expect(find.byType(BarChart), findsOneWidget);
      
      // Create chart
      await tester.tap(find.text('Create Chart'));
      await tester.pumpAndSettle();
      
      // Verify chart was created
      expect(find.text('Chart created successfully!'), findsOneWidget);
    });
    
    testWidgets('should create pivot table with drag-drop', (tester) async {
      // Launch app and navigate to pivot builder
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      // Open pivot builder
      await tester.tap(find.byIcon(Icons.pivot_table_chart));
      await tester.pumpAndSettle();
      
      // Drag field to row zone
      await tester.drag(find.text('Region'), Offset(0, 200));
      await tester.pumpAndSettle();
      
      // Drag field to value zone
      await tester.drag(find.text('Sales'), Offset(200, 200));
      await tester.pumpAndSettle();
      
      // Verify preview updates
      expect(find.byType(PivotTablePreview), findsOneWidget);
      
      // Create pivot
      await tester.tap(find.text('Create Pivot'));
      await tester.pumpAndSettle();
      
      // Verify success
      expect(find.text('Pivot table created successfully!'), findsOneWidget);
    });
  });
}
```

### **Performance Tests**

```dart
// test/performance/chart_performance_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chart Performance', () {
    test('should render 1000 data points in under 500ms', () async {
      final data = List.generate(1000, (i) => ChartData(
        label: 'Point $i',
        value: i.toDouble(),
      ));
      
      final stopwatch = Stopwatch()..start();
      
      final chart = ChartPreviewWidget(
        config: ChartConfig.defaultFor(ChartType.line, data),
        data: data,
      );
      
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
    
    test('should aggregate 10000 rows in pivot under 3 seconds', () async {
      final data = List.generate(10000, (i) => {
        'Region': 'Region ${i % 10}',
        'Product': 'Product ${i % 20}',
        'Sales': (i * 100.0),
      });
      
      final config = PivotConfiguration(
        rowFields: [PivotField(name: 'Region')],
        valueFields: [PivotField(
          name: 'Sales',
          aggregation: AggregationType.sum,
        )],
      );
      
      final stopwatch = Stopwatch()..start();
      
      final result = await PivotEngine().aggregate(data, config);
      
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      expect(result, isNotNull);
    });
  });
}
```



---

## 🎓 USER DOCUMENTATION & TUTORIALS

### **Quick Start Guide**

#### **Creating Your First Chart**
```
1. Select Data Range
   - Tap and drag to select cells containing your data
   - Include headers in the first row
   
2. Open Chart Builder
   - Tap the Chart icon in the bottom toolbar
   - Or use voice command: "Create a chart"
   
3. Choose Chart Type
   - Scroll through chart type options
   - See AI suggestions at the top
   - Tap to select: Bar, Line, Pie, etc.
   
4. Customize (Optional)
   - Edit title and labels
   - Change colors and styles
   - Adjust axis settings
   
5. Create Chart
   - Tap "Create Chart" button
   - Chart appears on your sheet
   - Tap to edit or export anytime
```

#### **Creating Your First Pivot Table**
```
1. Select Source Data
   - Select the entire data range including headers
   - Data should have column headers in first row
   
2. Open Pivot Builder
   - Tap Pivot icon in toolbar
   - Or say: "Create a pivot table"
   
3. Drag Fields to Zones
   - Rows: Categories you want to group by
   - Columns: Additional grouping (optional)
   - Values: Numbers to aggregate (sum, count, etc.)
   - Filters: Fields to filter data (optional)
   
4. Preview & Adjust
   - Live preview updates automatically
   - Change aggregation types (sum, average, count)
   - Reorder fields by dragging
   
5. Create Pivot
   - Tap "Create Pivot" button
   - Pivot table appears as new sheet
   - Refresh anytime to update data
```

### **AI Voice Commands Cheat Sheet**

#### **Chart Commands**
```
"Create a bar chart showing sales by region"
"Show me a line graph of monthly revenue"
"Make a pie chart of market share"
"Visualize the trend in customer growth"
"Compare products with a bar chart"
"Show sales over time as a line chart"
```

#### **Pivot Commands**
```
"Create a pivot table with sales by region"
"Summarize revenue by product and month"
"Show me total sales grouped by category"
"Analyze data by region and product"
"Count customers by city and status"
```

#### **Analysis Commands**
```
"What's the best chart for this data?"
"Suggest ways to visualize this"
"How should I analyze this data?"
"Show me insights from this range"
```

---

## 🚀 DEPLOYMENT CHECKLIST

### **Pre-Launch Checklist**

#### **✅ Feature Completeness**
- [ ] All 5+ chart types working (Bar, Line, Pie, Scatter, Area)
- [ ] Chart customization (colors, labels, titles)
- [ ] Chart export (PNG, PDF)
- [ ] AI chart recommendations
- [ ] Drag-drop pivot builder
- [ ] Pivot aggregations (sum, count, average, etc.)
- [ ] AI pivot suggestions
- [ ] Real-time preview for charts and pivots
- [ ] Touch gestures (zoom, pan, tap)
- [ ] Voice commands integration

#### **✅ Performance**
- [ ] Chart rendering <500ms for 1000 points
- [ ] Pivot aggregation <3s for 10K rows
- [ ] No memory leaks in long sessions
- [ ] Smooth 60 FPS animations
- [ ] App size increase <15MB

#### **✅ Testing**
- [ ] Unit tests passing (90%+ coverage)
- [ ] Integration tests passing
- [ ] Manual testing on 5+ devices
- [ ] iOS and Android both tested
- [ ] Performance profiling completed
- [ ] Memory profiling completed

#### **✅ User Experience**
- [ ] Intuitive UI (5 second learning curve)
- [ ] Helpful error messages
- [ ] Loading indicators for long operations
- [ ] Undo/redo support
- [ ] Tutorial on first use
- [ ] In-app help documentation

#### **✅ Documentation**
- [ ] API documentation complete
- [ ] User guide written
- [ ] Video tutorials recorded
- [ ] Developer onboarding doc
- [ ] Troubleshooting guide

#### **✅ App Store Prep**
- [ ] Screenshots for both platforms
- [ ] App description optimized (ASO)
- [ ] Demo video created
- [ ] Privacy policy updated
- [ ] Terms of service reviewed
- [ ] Beta testing feedback incorporated

---

## 💡 FUTURE ENHANCEMENTS (Post-Launch)

### **Phase 2 Features (3-6 Months)**

#### **Advanced Chart Types**
```
- Waterfall charts (financial analysis)
- Funnel charts (sales pipeline)
- Heatmaps (correlation analysis)
- Treemaps (hierarchical data)
- Candlestick charts (stock analysis)
- Combo charts (multiple data types)
- 3D charts (optional premium)
```

#### **Enhanced Pivot Features**
```
- Calculated fields (custom formulas in pivot)
- Pivot chart integration (visualize pivot data)
- Slicers (visual filters)
- Timeline filters (for date fields)
- Drill-down functionality
- Pivot templates library
- Export pivot to new sheet
```

#### **AI Enhancements**
```
- Predictive analytics integration
- Anomaly detection in charts
- Smart insights generation
- Natural language querying ("What's our top product?")
- Auto-refresh on data changes
- Collaborative chart annotations
- Chart recommendations based on user history
```

#### **Collaboration Features**
```
- Real-time chart collaboration
- Shared pivot configurations
- Chart comments and discussions
- Version history for charts/pivots
- Team chart templates
- Permission controls
```

### **Phase 3 Features (6-12 Months)**

#### **Advanced Analytics**
```
- Statistical analysis (regression, correlation)
- Forecasting and trend lines
- Goal seeking visualizations
- Scenario comparison charts
- A/B testing visualizations
- Multi-variate analysis
```

#### **Enterprise Features**
```
- Custom chart branding
- White-label chart export
- API for programmatic chart creation
- Advanced data connections (SQL, APIs)
- Scheduled pivot refreshes
- Custom aggregation functions
- Chart embedding in external apps
```

#### **Mobile Optimizations**
```
- Offline chart editing
- Apple Watch chart widgets
- Android Wear support
- Siri shortcuts for chart creation
- Google Assistant integration
- Quick Share to social media
```

---

## 📈 SUCCESS METRICS

### **Key Performance Indicators (KPIs)**

#### **Adoption Metrics**
```
Target (Month 1):
- 30% of users create at least 1 chart
- 15% of users create at least 1 pivot table
- 5 charts created per active user (average)

Target (Month 3):
- 50% chart adoption
- 30% pivot adoption
- 10 charts per active user

Target (Month 6):
- 70% chart adoption
- 50% pivot adoption
- 20 charts per active user
```

#### **Engagement Metrics**
```
- Chart creation rate: 2+ per user session
- Pivot table creation rate: 1+ per user session
- AI suggestion acceptance rate: >40%
- Voice command usage: >20% of chart creations
- Feature return rate: >60% (users come back)
```

#### **Performance Metrics**
```
- Chart render time: <500ms average
- Pivot calculation time: <2s average
- Crash-free rate: >99.5%
- App rating: >4.5 stars
- Feature satisfaction: >80% positive feedback
```

#### **Business Metrics**
```
- Free-to-Pro conversion: >8% (charts as key driver)
- Revenue per user: +25% increase
- Customer retention: +15% improvement
- Support tickets: <5% related to charts/pivots
- NPS score: >50 (excellent)
```

---

## 🎉 CONCLUSION & NEXT STEPS

### **Executive Summary**

Yeh implementation plan **complete roadmap** hai Charts aur Pivot Tables ko tumhare mobile spreadsheet app mein integrate karne ka. Based on extensive online research aur industry best practices, yeh plan ensure karta hai:

✅ **World-Class Features**: fl_chart + AI-powered recommendations  
✅ **Mobile-First Design**: Touch-optimized, gesture-based UI  
✅ **High Performance**: 100K+ rows handle with smooth UX  
✅ **AI Integration**: Natural language chart/pivot creation  
✅ **8-Week Timeline**: Realistic milestones with clear deliverables  

### **Key Differentiators**

🌟 **AI-Powered Intelligence**
- Automatic chart type selection based on data analysis
- Smart pivot recommendations using Gemini AI
- Natural language commands: "Show sales trend"
- Voice-activated chart creation

🌟 **Mobile-Native Experience**
- Pinch-to-zoom on charts
- Drag-and-drop pivot builder
- Haptic feedback for interactions
- Optimized for small screens

🌟 **Superior Performance**
- GPU-accelerated rendering via existing Vulkan integration
- Chunked processing for large datasets
- Smart data sampling for 100K+ rows
- Memory-efficient caching

### **Implementation Priority**

```
Week 1-2: Chart Engine Foundation ⭐⭐⭐⭐⭐ CRITICAL
Week 3-4: Advanced Charts & Export ⭐⭐⭐⭐ HIGH
Week 5-6: Pivot Table Engine ⭐⭐⭐⭐⭐ CRITICAL
Week 7-8: Performance & Polish ⭐⭐⭐⭐ HIGH
```

### **Immediate Next Steps**

1. **Setup Development Environment** (Day 1)
   ```bash
   # Add dependencies to pubspec.yaml
   flutter pub add fl_chart
   flutter pub add pdf path_provider screenshot
   flutter pub get
   ```

2. **Create Project Structure** (Day 1-2)
   ```bash
   # Create folders as per architecture
   mkdir -p lib/domain/entities/charts
   mkdir -p lib/presentation/widgets/charts
   mkdir -p lib/core/chart_engine
   # ... etc
   ```

3. **Start with Basic Chart** (Day 3-5)
   - Implement ChartEntity model
   - Create BarChartWidget using fl_chart
   - Add basic chart builder UI
   - Test with sample data

4. **Integrate AI** (Day 6-10)
   - Connect ChartAIService with existing Gemini integration
   - Add chart recommendation logic
   - Test AI suggestions accuracy

5. **Continue with Pivot** (Week 3+)
   - Follow pivot implementation plan
   - Build drag-drop interface
   - Add aggregation engine

### **Risk Mitigation**

⚠️ **Potential Challenges**:
- **App Size**: fl_chart adds ~2MB, Syncfusion adds ~8MB
  - *Mitigation*: Use fl_chart for free tier, lazy load Syncfusion
  
- **Performance on Low-End Devices**: Large datasets may lag
  - *Mitigation*: Aggressive data sampling, show warnings
  
- **AI API Costs**: Heavy Gemini usage for suggestions
  - *Mitigation*: Cache suggestions, limit free tier queries
  
- **Learning Curve**: Users may find pivot complex
  - *Mitigation*: In-app tutorials, AI-guided setup

### **Success Formula**

```
World-Class Charts + AI Intelligence + Mobile-First UX = #1 Spreadsheet App
```

### **Final Recommendation**

**START IMMEDIATELY!** Charts aur Pivot Tables tumhare app ko **Excel Mobile aur Google Sheets se alag** karenge. Tumhare paas already:
- ✅ AI Agent infrastructure
- ✅ JavaScript engine
- ✅ GPU acceleration
- ✅ Voice commands

Ab sirf **Charts + Pivots** add karo aur **market leader** ban jao! 🚀

**Timeline**: 8 weeks  
**Team Size**: 3-4 developers  
**Investment**: $80K-120K  
**ROI**: 10x within 12 months  

**Let's build the future of mobile spreadsheets!** 🌟📊📈

