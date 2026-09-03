import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../domain/entities/excel_image_entity.dart';

class ExcelImageOverlay extends StatefulWidget {
  final List<ExcelImageEntity> images;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double Function(int) getColumnWidth;
  final double Function(int) getRowHeight;
  final void Function(ExcelImageEntity)? onImageUpdated;

  const ExcelImageOverlay({
    Key? key,
    required this.images,
    required this.horizontalController,
    required this.verticalController,
    required this.getColumnWidth,
    required this.getRowHeight,
    this.onImageUpdated,
  }) : super(key: key);

  @override
  State<ExcelImageOverlay> createState() => _ExcelImageOverlayState();
}

class _ExcelImageOverlayState extends State<ExcelImageOverlay> {
  String? _selectedImageId;
  bool _sliderVisible = false;
  double _imageScale = 1.0;

  // Temporary drag state
  String? _draggingImageId;
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  double _dragWidth = 0;
  double _dragHeight = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Deselect if tapping empty space
        if (_selectedImageId != null) {
          _finalizeScale();
          setState(() {
            _selectedImageId = null;
            _sliderVisible = false;
          });
        }
      },
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([widget.horizontalController, widget.verticalController]),
            builder: (context, child) {
              final scrollX = widget.horizontalController.hasClients ? widget.horizontalController.offset : 0.0;
              final scrollY = widget.verticalController.hasClients ? widget.verticalController.offset : 0.0;

              return Stack(
                clipBehavior: Clip.none,
                children: widget.images.map((image) {
              // Calculate original base bounds
              double fromX = 0;
              for (int c = 0; c < image.fromCol; c++) fromX += widget.getColumnWidth(c);
              fromX += image.fromColOff;
              
              double fromY = 0;
              for (int r = 0; r < image.fromRow; r++) fromY += widget.getRowHeight(r);
              fromY += image.fromRowOff;

              double toX = 0;
              for (int c = 0; c < image.toCol; c++) toX += widget.getColumnWidth(c);
              toX += image.toColOff;

              double toY = 0;
              for (int r = 0; r < image.toRow; r++) toY += widget.getRowHeight(r);
              toY += image.toRowOff;

              double width = toX - fromX;
              double height = toY - fromY;

              if (width <= 0) width = widget.getColumnWidth(image.fromCol);
              if (height <= 0) height = widget.getRowHeight(image.fromRow);

              final isSelected = _selectedImageId == image.id;
              final isDraggingThis = _draggingImageId == image.id;

              // Apply slider scale if selected and NOT currently dragging a handle
              if (isSelected && !isDraggingThis) {
                width *= _imageScale;
                height *= _imageScale;
              }

              final currentX = isDraggingThis ? fromX + _dragOffsetX : fromX;
              final currentY = isDraggingThis ? fromY + _dragOffsetY : fromY;
              final currentWidth = isDraggingThis ? _dragWidth : width;
              final currentHeight = isDraggingThis ? _dragHeight : height;

              return Positioned(
                left: currentX - scrollX,
                top: currentY - scrollY,
                width: currentWidth,
                height: currentHeight,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageId = image.id;
                      // Just select, don't show slider on single tap
                    });
                  },
                  onDoubleTap: () {
                    setState(() {
                      _selectedImageId = image.id;
                      _sliderVisible = true;
                    });
                  },
                  onScaleStart: (details) {
                    setState(() {
                      _selectedImageId = image.id;
                      _sliderVisible = false; // Hide slider when dragging
                      _draggingImageId = image.id;
                      _dragOffsetX = 0;
                      _dragOffsetY = 0;
                      _dragWidth = width;
                      _dragHeight = height;
                    });
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      if (details.pointerCount >= 2) {
                        _dragWidth = width * details.scale;
                        _dragHeight = height * details.scale;
                      } else {
                        _dragOffsetX += details.focalPointDelta.dx;
                        _dragOffsetY += details.focalPointDelta.dy;
                      }
                    });
                  },
                  onScaleEnd: (details) {
                    if (_draggingImageId == image.id) {
                      _finalizeDrag(image, currentX, currentY, currentWidth, currentHeight);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5) : null,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(image.imagePath),
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      if (_sliderVisible && _selectedImageId != null)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 60), // Above the bottom toolbar
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            width: 200, // Small and minimal
            height: 40, // Thin
            child: Row(
              children: [
                const Icon(Icons.image, size: 16, color: Colors.blue),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                    ),
                    child: Slider(
                      value: _imageScale,
                      min: 0.1,
                      max: 5.0,
                      onChanged: (value) {
                        setState(() {
                          _imageScale = value;
                        });
                      },
                      onChangeEnd: (value) {
                        _finalizeScale();
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _finalizeScale();
                    setState(() {
                      _sliderVisible = false;
                    });
                  },
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  void _finalizeScale() {
    if (_selectedImageId == null || _imageScale == 1.0) return;

    final image = widget.images.firstWhere((img) => img.id == _selectedImageId, orElse: () => widget.images.first);
    if (image.id != _selectedImageId) return;

    double fromX = 0;
    for (int c = 0; c < image.fromCol; c++) fromX += widget.getColumnWidth(c);
    fromX += image.fromColOff;
    
    double fromY = 0;
    for (int r = 0; r < image.fromRow; r++) fromY += widget.getRowHeight(r);
    fromY += image.fromRowOff;

    double toX = 0;
    for (int c = 0; c < image.toCol; c++) toX += widget.getColumnWidth(c);
    toX += image.toColOff;

    double toY = 0;
    for (int r = 0; r < image.toRow; r++) toY += widget.getRowHeight(r);
    toY += image.toRowOff;

    double width = toX - fromX;
    double height = toY - fromY;

    if (width <= 0) width = widget.getColumnWidth(image.fromCol);
    if (height <= 0) height = widget.getRowHeight(image.fromRow);

    double newWidth = width * _imageScale;
    double newHeight = height * _imageScale;

    _imageScale = 1.0;
    _finalizeDrag(image, fromX, fromY, newWidth, newHeight);
  }

  void _finalizeDrag(ExcelImageEntity image, double newX, double newY, double newWidth, double newHeight) {
    setState(() {
      _draggingImageId = null;
    });

    // Clamp coordinates to prevent negative offsets and inverted sizes
    if (newX < 0) {
      newWidth += newX;
      newX = 0;
    }
    if (newY < 0) {
      newHeight += newY;
      newY = 0;
    }
    if (newWidth < 10) newWidth = 10;
    if (newHeight < 10) newHeight = 10;

    if (widget.onImageUpdated != null) {
      // Find new columns and rows based on absolute pixel coordinates
      int newFromCol = 0;
      double accumX = 0;
      while (true) {
        double cw = widget.getColumnWidth(newFromCol);
        if (accumX + cw > newX) break;
        accumX += cw;
        newFromCol++;
      }
      double newFromColOff = newX - accumX;

      int newFromRow = 0;
      double accumY = 0;
      while (true) {
        double rh = widget.getRowHeight(newFromRow);
        if (accumY + rh > newY) break;
        accumY += rh;
        newFromRow++;
      }
      double newFromRowOff = newY - accumY;

      double newToX = newX + newWidth;
      int newToCol = 0;
      accumX = 0;
      while (true) {
        double cw = widget.getColumnWidth(newToCol);
        if (accumX + cw > newToX) break;
        accumX += cw;
        newToCol++;
      }
      double newToColOff = newToX - accumX;

      double newToY = newY + newHeight;
      int newToRow = 0;
      accumY = 0;
      while (true) {
        double rh = widget.getRowHeight(newToRow);
        if (accumY + rh > newToY) break;
        accumY += rh;
        newToRow++;
      }
      double newToRowOff = newToY - accumY;

      final updatedImage = image.copyWith(
        fromCol: newFromCol,
        fromRow: newFromRow,
        toCol: newToCol,
        toRow: newToRow,
        fromColOff: newFromColOff,
        fromRowOff: newFromRowOff,
        toColOff: newToColOff,
        toRowOff: newToRowOff,
      );

      widget.onImageUpdated!(updatedImage);
    }
  }

}
