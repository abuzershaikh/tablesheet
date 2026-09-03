import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import '../../entities/excel_image_entity.dart';
import '../storage/excel_image_storage.dart';

class ExcelImageExtractor {
  final _uuid = const Uuid();

  /// Extracts images and their coordinates from an Excel (.xlsx) file.
  /// Returns a map of Sheet Name -> List of ExcelImageEntity.
  Future<Map<String, List<ExcelImageEntity>>> extractImages(List<int> zipBytes) async {
    final Map<String, List<ExcelImageEntity>> sheetImages = {};
    
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      // 1. Parse workbook.xml to get sheet names and their rIds
      final workbookEntry = archive.findFile('xl/workbook.xml');
      if (workbookEntry == null) return sheetImages;
      
      final workbookXml = XmlDocument.parse(utf8.decode(workbookEntry.content as List<int>));
      final sheetElements = workbookXml.findAllElements('sheet');
      
      // Map of rId -> Sheet Name
      final Map<String, String> rIdToSheetName = {};
      for (var sheet in sheetElements) {
        final name = sheet.getAttribute('name');
        final rId = sheet.getAttribute('r:id');
        if (name != null && rId != null) {
          rIdToSheetName[rId] = name;
        }
      }

      // 2. Parse workbook.xml.rels to map rId to worksheet path
      final workbookRelsEntry = archive.findFile('xl/_rels/workbook.xml.rels');
      if (workbookRelsEntry == null) return sheetImages;
      
      final workbookRelsXml = XmlDocument.parse(utf8.decode(workbookRelsEntry.content as List<int>));
      final Map<String, String> sheetNameToPath = {};
      
      for (var rel in workbookRelsXml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null && rIdToSheetName.containsKey(id)) {
          // target is like "worksheets/sheet1.xml"
          sheetNameToPath[rIdToSheetName[id]!] = 'xl/$target';
        }
      }

      // 3. Process each sheet
      for (var entry in sheetNameToPath.entries) {
        final sheetName = entry.key;
        final sheetPath = entry.value;
        
        final sheetImagesList = await _processSheetForImages(archive, sheetPath);
        if (sheetImagesList.isNotEmpty) {
          sheetImages[sheetName] = sheetImagesList;
        }
      }
      
    } catch (e, stack) {
      print('DEBUG [ExcelImageExtractor]: Error extracting images: $e\n$stack');
    }
    
    return sheetImages;
  }

  Future<List<ExcelImageEntity>> _processSheetForImages(Archive archive, String sheetPath) async {
    final List<ExcelImageEntity> images = [];
    
    try {
      final sheetEntry = archive.findFile(sheetPath);
      if (sheetEntry == null) return images;
      
      final sheetXml = XmlDocument.parse(utf8.decode(sheetEntry.content as List<int>));
      final drawingElement = sheetXml.findAllElements('drawing').firstOrNull;
      if (drawingElement == null) return images;
      
      final drawingRId = drawingElement.getAttribute('r:id');
      if (drawingRId == null) return images;
      
      // Look up drawing path in sheet rels
      // sheetPath is like "xl/worksheets/sheet1.xml"
      // relsPath is like "xl/worksheets/_rels/sheet1.xml.rels"
      final lastSlash = sheetPath.lastIndexOf('/');
      final sheetDir = sheetPath.substring(0, lastSlash);
      final sheetFileName = sheetPath.substring(lastSlash + 1);
      final relsPath = '$sheetDir/_rels/$sheetFileName.rels';
      
      final relsEntry = archive.findFile(relsPath);
      if (relsEntry == null) return images;
      
      final relsXml = XmlDocument.parse(utf8.decode(relsEntry.content as List<int>));
      String? drawingTarget;
      for (var rel in relsXml.findAllElements('Relationship')) {
        if (rel.getAttribute('Id') == drawingRId) {
          drawingTarget = rel.getAttribute('Target');
          break;
        }
      }
      
      if (drawingTarget == null) return images;
      
      // drawingTarget is like "../drawings/drawing1.xml"
      // Resolve path
      String drawingPath;
      if (drawingTarget.startsWith('../')) {
        final parentDir = sheetDir.substring(0, sheetDir.lastIndexOf('/'));
        drawingPath = '$parentDir/${drawingTarget.substring(3)}';
      } else {
        drawingPath = '$sheetDir/$drawingTarget';
      }
      
      // Parse drawing.xml
      final drawingEntry = archive.findFile(drawingPath);
      if (drawingEntry == null) return images;
      
      final drawingXml = XmlDocument.parse(utf8.decode(drawingEntry.content as List<int>));
      
      // Parse drawing rels to map image rIds to media paths
      final drawingLastSlash = drawingPath.lastIndexOf('/');
      final drawingDir = drawingPath.substring(0, drawingLastSlash);
      final drawingFileName = drawingPath.substring(drawingLastSlash + 1);
      final drawingRelsPath = '$drawingDir/_rels/$drawingFileName.rels';
      
      final drawingRelsEntry = archive.findFile(drawingRelsPath);
      final Map<String, String> imageRIdToMediaPath = {};
      
      if (drawingRelsEntry != null) {
        final drawingRelsXml = XmlDocument.parse(utf8.decode(drawingRelsEntry.content as List<int>));
        for (var rel in drawingRelsXml.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target'); // like "../media/image1.jpeg"
          if (id != null && target != null) {
             if (target.startsWith('../')) {
                final parentDir = drawingDir.substring(0, drawingDir.lastIndexOf('/'));
                imageRIdToMediaPath[id] = '$parentDir/${target.substring(3)}';
             } else {
                imageRIdToMediaPath[id] = '$drawingDir/$target';
             }
          }
        }
      }
      
      // Extract anchors
      final anchors = [
        ...drawingXml.findAllElements('xdr:twoCellAnchor'),
        ...drawingXml.findAllElements('xdr:oneCellAnchor')
      ];
      
      for (var anchor in anchors) {
        final fromEl = anchor.findElements('xdr:from').firstOrNull;
        if (fromEl == null) continue;
        
        final fromCol = int.tryParse(fromEl.findElements('xdr:col').firstOrNull?.innerText ?? '') ?? 0;
        final fromRow = int.tryParse(fromEl.findElements('xdr:row').firstOrNull?.innerText ?? '') ?? 0;
        
        // Offsets in EMUs
        final fromColOffEmu = double.tryParse(fromEl.findElements('xdr:colOff').firstOrNull?.innerText ?? '') ?? 0.0;
        final fromRowOffEmu = double.tryParse(fromEl.findElements('xdr:rowOff').firstOrNull?.innerText ?? '') ?? 0.0;
        
        final fromColOffPx = fromColOffEmu / 9525.0;
        final fromRowOffPx = fromRowOffEmu / 9525.0;

        int toCol = fromCol;
        int toRow = fromRow;
        double toColOffPx = fromColOffPx;
        double toRowOffPx = fromRowOffPx;

        final toEl = anchor.findElements('xdr:to').firstOrNull;
        if (toEl != null) {
          toCol = int.tryParse(toEl.findElements('xdr:col').firstOrNull?.innerText ?? '') ?? fromCol;
          toRow = int.tryParse(toEl.findElements('xdr:row').firstOrNull?.innerText ?? '') ?? fromRow;
          
          final toColOffEmu = double.tryParse(toEl.findElements('xdr:colOff').firstOrNull?.innerText ?? '') ?? 0.0;
          final toRowOffEmu = double.tryParse(toEl.findElements('xdr:rowOff').firstOrNull?.innerText ?? '') ?? 0.0;
          
          toColOffPx = toColOffEmu / 9525.0;
          toRowOffPx = toRowOffEmu / 9525.0;
        } else {
          // It's a oneCellAnchor, check ext for width/height in EMUs
          final extEl = anchor.findElements('xdr:ext').firstOrNull;
          if (extEl != null) {
            final cxEmu = double.tryParse(extEl.getAttribute('cx') ?? '') ?? 0.0;
            final cyEmu = double.tryParse(extEl.getAttribute('cy') ?? '') ?? 0.0;
            final widthPx = cxEmu / 9525.0;
            final heightPx = cyEmu / 9525.0;
            
            // For oneCellAnchor, toCol and toRow are just the same as from, but with offsets added
            toColOffPx = fromColOffPx + widthPx;
            toRowOffPx = fromRowOffPx + heightPx;
          }
        }
        
        final picEl = anchor.findAllElements('xdr:pic').firstOrNull;
        if (picEl == null) continue;
        
        final blipEl = picEl.findAllElements('a:blip').firstOrNull;
        final embedId = blipEl?.getAttribute('r:embed');
        if (embedId == null) continue;
        
        final mediaPath = imageRIdToMediaPath[embedId];
        if (mediaPath == null) continue;
        
        final mediaEntry = archive.findFile(mediaPath);
        if (mediaEntry == null) continue;
        
        // Save image to disk
        final imageId = _uuid.v4();
        final imageBytes = mediaEntry.content as List<int>;
        final savedPath = await ExcelImageStorage.saveImage(imageId, imageBytes);
        
        if (savedPath.isNotEmpty) {
          images.add(ExcelImageEntity(
            id: imageId,
            imagePath: savedPath,
            fromCol: fromCol,
            fromRow: fromRow,
            toCol: toCol,
            toRow: toRow,
            fromColOff: fromColOffPx,
            fromRowOff: fromRowOffPx,
            toColOff: toColOffPx,
            toRowOff: toRowOffPx,
          ));
        }
      }
      
    } catch (e, stack) {
      print('DEBUG [ExcelImageExtractor]: Error processing sheet $sheetPath: $e\n$stack');
    }
    
    return images;
  }
}
