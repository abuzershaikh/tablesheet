import '../../domain/entities/spreadsheet_entity.dart';
import '../../domain/repositories/spreadsheet_repository.dart';
import '../data_sources/local_data_source.dart';
import '../mappers/spreadsheet_mapper.dart';
import '../mappers/sheet_mapper.dart';

/// Implementation of SpreadsheetRepository
class SpreadsheetRepositoryImpl implements SpreadsheetRepository {
  final LocalDataSource _localDataSource;

  SpreadsheetRepositoryImpl(this._localDataSource);

  @override
  Future<List<SpreadsheetEntity>> getAllSpreadsheets() async {
    try {
      final spreadsheetModels = await _localDataSource.getAllSpreadsheets();
      final entities = <SpreadsheetEntity>[];
      
      // Load sheets for each spreadsheet
      for (final model in spreadsheetModels) {
        final sheetModels = await _localDataSource.getSheetsBySpreadsheet(model.id);
        final sheets = SheetMapper.toEntities(sheetModels);
        
        final entity = SpreadsheetMapper.toEntity(model).copyWith(sheets: sheets);
        entities.add(entity);
      }
      
      return entities;
    } catch (e) {
      throw Exception('Failed to get spreadsheets: $e');
    }
  }

  @override
  Future<SpreadsheetEntity?> getSpreadsheetById(String id) async {
    try {
      final spreadsheetModel = await _localDataSource.getSpreadsheetById(id);
      if (spreadsheetModel == null) return null;
      
      // Load sheets for this spreadsheet
      final sheetModels = await _localDataSource.getSheetsBySpreadsheet(id);
      final sheets = SheetMapper.toEntities(sheetModels);
      
      final entity = SpreadsheetMapper.toEntity(spreadsheetModel).copyWith(sheets: sheets);
      return entity;
    } catch (e) {
      throw Exception('Failed to get spreadsheet: $e');
    }
  }

  @override
  Future<void> createSpreadsheet(SpreadsheetEntity spreadsheet) async {
    try {
      final spreadsheetModel = SpreadsheetMapper.toModel(spreadsheet);
      await _localDataSource.createSpreadsheet(spreadsheetModel);
      
      // Create sheets if any
      for (final sheet in spreadsheet.sheets) {
        final sheetModel = SheetMapper.toModel(sheet);
        await _localDataSource.createSheet(sheetModel);
      }
    } catch (e) {
      throw Exception('Failed to create spreadsheet: $e');
    }
  }

  @override
  Future<void> updateSpreadsheet(SpreadsheetEntity spreadsheet) async {
    try {
      final spreadsheetModel = SpreadsheetMapper.toModel(spreadsheet);
      await _localDataSource.updateSpreadsheet(spreadsheetModel);
    } catch (e) {
      throw Exception('Failed to update spreadsheet: $e');
    }
  }

  @override
  Future<void> deleteSpreadsheet(String id) async {
    try {
      await _localDataSource.deleteSpreadsheet(id);
    } catch (e) {
      throw Exception('Failed to delete spreadsheet: $e');
    }
  }
}