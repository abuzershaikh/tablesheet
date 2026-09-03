import 'package:equatable/equatable.dart';

class ExcelImageEntity extends Equatable {
  final String id;
  final String imagePath; // Local path to the cached image file
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;
  final double fromColOff; // Offset in pixels or EMUs
  final double fromRowOff;
  final double toColOff;
  final double toRowOff;

  const ExcelImageEntity({
    required this.id,
    required this.imagePath,
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    this.fromColOff = 0.0,
    this.fromRowOff = 0.0,
    this.toColOff = 0.0,
    this.toRowOff = 0.0,
  });

  ExcelImageEntity copyWith({
    String? id,
    String? imagePath,
    int? fromCol,
    int? fromRow,
    int? toCol,
    int? toRow,
    double? fromColOff,
    double? fromRowOff,
    double? toColOff,
    double? toRowOff,
  }) {
    return ExcelImageEntity(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      fromCol: fromCol ?? this.fromCol,
      fromRow: fromRow ?? this.fromRow,
      toCol: toCol ?? this.toCol,
      toRow: toRow ?? this.toRow,
      fromColOff: fromColOff ?? this.fromColOff,
      fromRowOff: fromRowOff ?? this.fromRowOff,
      toColOff: toColOff ?? this.toColOff,
      toRowOff: toRowOff ?? this.toRowOff,
    );
  }

  @override
  List<Object?> get props => [
        id,
        imagePath,
        fromCol,
        fromRow,
        toCol,
        toRow,
        fromColOff,
        fromRowOff,
        toColOff,
        toRowOff,
      ];

  factory ExcelImageEntity.fromJson(Map<String, dynamic> json) {
    return ExcelImageEntity(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      fromCol: json['fromCol'] as int,
      fromRow: json['fromRow'] as int,
      toCol: json['toCol'] as int,
      toRow: json['toRow'] as int,
      fromColOff: (json['fromColOff'] as num?)?.toDouble() ?? 0.0,
      fromRowOff: (json['fromRowOff'] as num?)?.toDouble() ?? 0.0,
      toColOff: (json['toColOff'] as num?)?.toDouble() ?? 0.0,
      toRowOff: (json['toRowOff'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'fromCol': fromCol,
      'fromRow': fromRow,
      'toCol': toCol,
      'toRow': toRow,
      'fromColOff': fromColOff,
      'fromRowOff': fromRowOff,
      'toColOff': toColOff,
      'toRowOff': toRowOff,
    };
  }
}
