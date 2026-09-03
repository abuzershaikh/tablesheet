import '../../domain/entities/sheet_entity.dart';
import '../models/sheet_model.dart';

/// Mapper to convert between SheetEntity and SheetModel
class SheetMapper {
  /// Convert SheetEntity to SheetModel for database storage
  static SheetModel toModel(SheetEntity entity) {
    return SheetModel(
      id: entity.sheetId,
      spreadsheetId: entity.spreadsheetId,
      name: entity.name,
      position: entity.position,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  /// Convert SheetModel to SheetEntity from database
  static SheetEntity toEntity(SheetModel model) {
    return SheetEntity(
      sheetId: model.id,
      spreadsheetId: model.spreadsheetId,
      name: model.name,
      position: model.position,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
    );
  }

  /// Convert list of SheetModels to SheetEntities
  static List<SheetEntity> toEntities(List<SheetModel> models) {
    return models.map((model) => toEntity(model)).toList();
  }

  /// Convert list of SheetEntities to SheetModels
  static List<SheetModel> toModels(List<SheetEntity> entities) {
    return entities.map((entity) => toModel(entity)).toList();
  }
}