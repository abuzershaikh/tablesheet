import '../../domain/entities/sheet_entity.dart';
import '../../domain/repositories/sheet_repository.dart';
import '../data_sources/local_data_source.dart';
import '../mappers/sheet_mapper.dart';

/// Implementation of SheetRepository
class SheetRepositoryImpl implements SheetRepository {
  final LocalDataSource _localDataSource;

  SheetRepositoryImpl(this._localDataSource);

  @override
  Future<List<SheetEntity>> getSheetsBySpreadsheet(String spreadsheetId) async {
    try {
      final sheetModels = await _localDataSource.getSheetsBySpreadsheet(spreadsheetId);
      return SheetMapper.toEntities(sheetModels);
    } catch (e) {
      throw Exception('Failed to get sheets: $e');
    }
  }

  @override
  Future<SheetEntity?> getSheetById(String sheetId) async {
    try {
      final sheets = await _localDataSource.getSheetsBySpreadsheet(''); // We'll need to modify this
      final sheetModel = sheets.where((s) => s.id == sheetId).firstOrNull;
      if (sheetModel == null) return null;
      
      return SheetMapper.toEntity(sheetModel);
    } catch (e) {
      throw Exception('Failed to get sheet: $e');
    }
  }

  @override
  Future<void> createSheet(SheetEntity sheet) async {
    try {
      final sheetModel = SheetMapper.toModel(sheet);
      await _localDataSource.createSheet(sheetModel);
    } catch (e) {
      throw Exception('Failed to create sheet: $e');
    }
  }

  @override
  Future<void> updateSheet(SheetEntity sheet) async {
    try {
      final sheetModel = SheetMapper.toModel(sheet);
      await _localDataSource.updateSheet(sheetModel);
    } catch (e) {
      throw Exception('Failed to update sheet: $e');
    }
  }

  @override
  Future<void> deleteSheet(String sheetId) async {
    try {
      await _localDataSource.deleteSheet(sheetId);
    } catch (e) {
      throw Exception('Failed to delete sheet: $e');
    }
  }
}