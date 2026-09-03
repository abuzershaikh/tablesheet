import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class ExcelImageStorage {
  static Future<String> saveImage(String imageId, List<int> bytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/excel_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final file = File('${imagesDir.path}/$imageId.bin');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print('Error saving excel image: $e');
      return '';
    }
  }

  static Future<void> deleteImage(String imagePath) async {
    try {
      if (imagePath.isEmpty) return;
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting excel image: $e');
    }
  }
}
