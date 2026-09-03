import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/data_sources/database/database_helper.dart';
import 'data/data_sources/local_data_source.dart';
import 'data/repositories/spreadsheet_repository_impl.dart';
import 'data/cache/cell_cache.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/home/home_controller.dart';

import 'domain/analytics/models/chart_config.dart';
import 'domain/analytics/registry/chart_renderer_registry.dart';
import 'presentation/analytics/renderers/bar_renderer.dart';
import 'presentation/analytics/renderers/pie_renderer.dart';
import 'presentation/analytics/renderers/pivot_table_renderer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register BI Chart Plugins
  ChartRendererRegistry.registerPlugin(BarRenderer());
  ChartRendererRegistry.registerPlugin(PieRenderer());
  ChartRendererRegistry.registerPlugin(PivotTableRenderer());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize dependencies
    final databaseHelper = DatabaseHelper();
    final localDataSource = LocalDataSource(databaseHelper);
    final spreadsheetRepository = SpreadsheetRepositoryImpl(localDataSource);
    final cellCache = CellCache();

    return MaterialApp(
      title: 'Mobile Spreadsheet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (context) => HomeController(spreadsheetRepository),
        child: const HomeScreen(),
      ),
    );
  }
}