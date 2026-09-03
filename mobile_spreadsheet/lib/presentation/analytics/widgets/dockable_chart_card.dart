import 'package:flutter/material.dart';
import '../../../domain/analytics/models/chart_config.dart';
import '../../../domain/analytics/registry/chart_renderer_registry.dart';

class DockableChartCard extends StatefulWidget {
  final ChartConfig config;
  final VoidCallback onClose;
  final VoidCallback onBringToFront;

  const DockableChartCard({
    Key? key,
    required this.config,
    required this.onClose,
    required this.onBringToFront,
  }) : super(key: key);

  @override
  State<DockableChartCard> createState() => _DockableChartCardState();
}

class _DockableChartCardState extends State<DockableChartCard> with SingleTickerProviderStateMixin {
  double _xPos = 20.0;
  double _yPos = 100.0;
  double _width = 300.0;
  double _height = 250.0;
  bool _isMinimized = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _xPos,
      top: _yPos,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
        onTapDown: (_) => widget.onBringToFront(),
        onPanUpdate: (details) {
          setState(() {
            _xPos += details.delta.dx;
            _yPos += details.delta.dy;
          });
          widget.onBringToFront();
        },
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _width,
            height: _isMinimized ? 45.0 : _height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              children: [
                // Header Bar (Draggable)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.vertical(top: const Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.config.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Controls
                      InkWell(
                        onTap: () => setState(() => _isMinimized = !_isMinimized),
                        child: Icon(_isMinimized ? Icons.expand_more : Icons.minimize, size: 18, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onClose,
                        child: Icon(Icons.close, size: 18, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                // Chart Area
                if (!_isMinimized)
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ChartRendererRegistry.buildChart(widget.config),
                        ),
                        // Resize Handle
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _width = (_width + details.delta.dx).clamp(200.0, 600.0);
                                _height = (_height + details.delta.dy).clamp(150.0, 500.0);
                              });
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              color: Colors.transparent,
                              child: const Icon(Icons.drag_indicator, size: 14, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
