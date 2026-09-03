import '../../domain/entities/cell_entity.dart';
import '../models/cell_model.dart';

/// Mapper to convert between CellEntity and CellModel
class CellMapper {
  /// Convert CellEntity to CellModel for database storage
  static CellModel toModel(CellEntity entity) {
    return CellModel(
      id: entity.cellId,
      sheetId: entity.sheetId,
      rowId: entity.rowId,
      columnId: entity.columnId,
      value: entity.value,
      formula: entity.formula,
      type: entity.dataType.name,
      formatBold: entity.format?.bold == true ? 1 : 0,
      formatItalic: entity.format?.italic == true ? 1 : 0,
      formatUnderline: entity.format?.underline == true ? 1 : 0,
      formatTextColor: entity.format?.textColor,
      formatBackgroundColor: entity.format?.backgroundColor,
      formatAlignment: entity.format?.horizontalAlignment.name,
      formatFontSize: entity.format?.fontSize,
      updatedAt: entity.modifiedAt.millisecondsSinceEpoch,
    );
  }

  /// Convert CellModel to CellEntity from database
  static CellEntity toEntity(CellModel model) {
    return CellEntity(
      cellId: model.id,
      sheetId: model.sheetId,
      rowId: model.rowId,
      columnId: model.columnId,
      value: model.value,
      formula: model.formula,
      dataType: _parseDataType(model.type),
      format: _parseFormat(model),
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
    );
  }

  /// Convert list of CellModels to CellEntities
  static List<CellEntity> toEntities(List<CellModel> models) {
    return models.map((model) => toEntity(model)).toList();
  }

  /// Convert list of CellEntities to CellModels
  static List<CellModel> toModels(List<CellEntity> entities) {
    return entities.map((entity) => toModel(entity)).toList();
  }

  /// Parse string to CellDataType
  static CellDataType _parseDataType(String type) {
    return CellDataType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => CellDataType.text,
    );
  }

  /// Parse format from model fields
  static CellFormat? _parseFormat(CellModel model) {
    // Return null if no formatting is applied
    if (model.formatBold == 0 &&
        model.formatItalic == 0 &&
        model.formatUnderline == 0 &&
        model.formatTextColor == null &&
        model.formatBackgroundColor == null &&
        model.formatAlignment == null &&
        model.formatFontSize == null) {
      return null;
    }

    return CellFormat(
      bold: model.formatBold == 1,
      italic: model.formatItalic == 1,
      underline: model.formatUnderline == 1,
      textColor: model.formatTextColor,
      backgroundColor: model.formatBackgroundColor,
      horizontalAlignment: _parseAlignment(model.formatAlignment),
      fontSize: model.formatFontSize,
    );
  }

  /// Parse string to TextAlignment
  static TextAlignment _parseAlignment(String? alignment) {
    if (alignment == null) return TextAlignment.left;
    
    return TextAlignment.values.firstWhere(
      (e) => e.name == alignment,
      orElse: () => TextAlignment.left,
    );
  }
}