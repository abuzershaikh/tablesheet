import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../copilot_chat_screen.dart';

class SheetproAiFloatingBot extends StatefulWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;
  final VoidCallback? onDismiss;

  const SheetproAiFloatingBot({
    Key? key,
    required this.sheetId,
    this.onPipelineApplied,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<SheetproAiFloatingBot> createState() => _SheetproAiFloatingBotState();
}

class _SheetproAiFloatingBotState extends State<SheetproAiFloatingBot> with SingleTickerProviderStateMixin {
  // Coordinates for dragging
  Offset? _position;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _openCopilot() {
    CopilotFullScreenChatScreen.open(
      context,
      sheetId: widget.sheetId,
      onPipelineApplied: widget.onPipelineApplied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Default position: bottom-right above formula / bottom bar
    final defaultX = screenSize.width - 110.0;
    final defaultY = screenSize.height - 185.0;

    final currentX = _position?.dx ?? defaultX;
    final currentY = _position?.dy ?? defaultY;

    // Clamp inside screen bounds
    final clampedX = currentX.clamp(10.0, screenSize.width - 115.0);
    final clampedY = currentY.clamp(60.0, screenSize.height - 140.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Bot Card (Lottie + Sheetpro AI Pill)
              InkWell(
                onTap: _openCopilot,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 95,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF06B6D4).withOpacity(0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withOpacity(0.45),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: 1.5,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lottie Animated Bot
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: Lottie.asset(
                              'assets/animations/aibot.json',
                              fit: BoxFit.contain,
                              repeat: true,
                              animate: true,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.smart_toy_rounded,
                                  color: Colors.cyanAccent,
                                  size: 40,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 2),

                          // "Sheetpro AI" Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0891B2), Color(0xFF0284C7)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 9),
                                SizedBox(width: 3),
                                Text(
                                  'Sheetpro AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Close (X) Dismiss Button on Top-Right Corner
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () {
                    widget.onDismiss?.call();
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
