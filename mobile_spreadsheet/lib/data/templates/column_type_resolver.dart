import '../../domain/entities/column_types/base/column_type.dart';
import '../../domain/entities/column_types/text/text_column_type.dart';
import '../../domain/entities/column_types/number/number_column_type.dart';
import '../../domain/entities/column_types/number/amount_column_type.dart';
import '../../domain/entities/column_types/date/date_column_type.dart';
import '../../domain/entities/column_types/date/time_column_type.dart';
import '../../domain/entities/column_types/selection/checkbox_column_type.dart';
import '../../domain/entities/column_types/selection/selectable_column_type.dart';
import '../../domain/entities/column_types/media/image_column_type.dart';
import '../../domain/entities/column_types/media/audio_column_type.dart';
import '../../domain/entities/column_types/media/pdf_column_type.dart';
import '../../domain/entities/column_types/contact/phone_column_type.dart';
import '../../domain/entities/column_types/contact/link_column_type.dart';
import '../../domain/entities/column_types/location/address_column_type.dart';
import '../../domain/entities/column_types/location/location_column_type.dart';

/// Maps a template typeId string to the corresponding ColumnType instance
class ColumnTypeResolver {
  ColumnTypeResolver._();

  static ColumnType resolve(String typeId) {
    switch (typeId) {
      case 'text':
        return const TextColumnType();
      case 'number':
        return const NumberColumnType();
      case 'amount':
        return const AmountColumnType();
      case 'date':
        return const DateColumnType();
      case 'time':
        return const TimeColumnType();
      case 'checkbox':
        return const CheckboxColumnType();
      case 'selectable':
        return const SelectableColumnType(options: ['Option 1', 'Option 2', 'Option 3']);
      case 'image':
        return const ImageColumnType();
      case 'audio':
        return const AudioColumnType();
      case 'pdf':
        return const PdfColumnType();
      case 'phone':
        return const PhoneColumnType();
      case 'link':
        return const LinkColumnType();
      case 'address':
        return const AddressColumnType();
      case 'location':
        return const LocationColumnType();
      default:
        return const TextColumnType();
    }
  }
}
