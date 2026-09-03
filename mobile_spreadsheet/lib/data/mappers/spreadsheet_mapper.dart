import '../../domain/entities/spreadsheet_entity.dart';
import '../models/spreadsheet_model.dart';

/// Mapper to convert between SpreadsheetEntity and SpreadsheetModel
class SpreadsheetMapper {
  /// Convert SpreadsheetEntity to SpreadsheetModel for database storage
  static SpreadsheetModel toModel(SpreadsheetEntity entity) {
    return SpreadsheetModel(
      id: entity.spreadsheetId,
      name: entity.name,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
      thumbnail: entity.thumbnailPath,
    );
  }

  /// Convert SpreadsheetModel to SpreadsheetEntity from database
  static SpreadsheetEntity toEntity(SpreadsheetModel model) {
    return SpreadsheetEntity(
      spreadsheetId: model.id,
      name: model.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
      thumbnailPath: model.thumbnail,
      sheets: const [], // Sheets will be loaded separately
    );
  }

  /// Convert list of SpreadsheetModels to SpreadsheetEntities
  static List<SpreadsheetEntity> toEntities(List<SpreadsheetModel> models) {
    return models.map((model) => toEntity(model)).toList();
  }

  /// Convert list of SpreadsheetEntities to SpreadsheetModels
  static List<SpreadsheetModel> toModels(List<SpreadsheetEntity> entities) {
    return entities.map((entity) => toModel(entity)).toList();
  }
}