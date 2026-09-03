/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Mobile Spreadsheet';
  static const String packageName = 'com.tablenotes.sheets.excelsheet.spreadsheet';
  static const String appVersion = '1.0.0';
  
  // Grid Defaults
  static const int defaultRows = 1000;
  static const int defaultColumns = 26;
  static const double defaultCellWidth = 120.0;
  static const double defaultCellHeight = 52.0;
  static const double minCellWidth = 60.0;
  static const double minCellHeight = 30.0;
  static const double maxCellWidth = 400.0;
  static const double maxCellHeight = 200.0;
  
  // Performance
  static const int targetFPS = 60;
  static const int maxFPS = 120;
  static const int autoSaveIntervalSeconds = 30;
  static const int maxUndoSteps = 50;
  static const int cellCacheSize = 500;
  static const int maxCellCacheSizeMB = 50;
  
  // GPU/Vulkan
  static const int minCellsForGPUCompute = 1000;
  static const int computeWorkGroupSize = 32;
  static const int textureAtlasSize = 2048;
  static const int msaaSamples = 4;
  
  // API/Network
  static const int apiTimeoutSeconds = 30;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Google Forms
  static const int formSyncIntervalMinutes = 15;
  
  // File
  static const int maxSpreadsheetSizeMB = 100;
  static const int importPreviewRows = 10;
  
  // UI
  static const double appBarHeight = 56.0;
  static const double formulaBarHeight = 48.0;
  static const double columnHeaderHeight = 48.0;
  static const double rowHeaderWidth = 48.0;
  static const double sheetTabsHeight = 40.0;
  static const double bottomToolbarHeight = 56.0;
  static const double fabSize = 56.0;
  static const double minTouchTarget = 48.0;
  
  // Padding & Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double marginSmall = 4.0;
  static const double marginMedium = 8.0;
  static const double marginLarge = 16.0;
  
  // Animation
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Database
  static const String databaseName = 'spreadsheet.db';
  static const int databaseVersion = 1;
  
  // Zoom
  static const double minZoom = 0.5;
  static const double maxZoom = 3.0;
  static const double defaultZoom = 1.0;
  static const double zoomStep = 0.1;
}
