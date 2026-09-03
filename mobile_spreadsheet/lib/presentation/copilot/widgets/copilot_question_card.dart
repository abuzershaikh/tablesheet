import 'package:flutter/material.dart';
import '../../../domain/services/copilot/copilot_service.dart';

/// A premium, interactive Question Chip Card for Copilot
/// Allows the user to select one of the AI-proposed options or type a custom answer.
class CopilotQuestionCard extends StatefulWidget {
  final CopilotQuestionPayload questionPayload;
  final String? currentAnswer;
  final ValueChanged<String> onAnswerSubmitted;
  final bool isDarkMode;

  const CopilotQuestionCard({
    Key? key,
    required this.questionPayload,
    this.currentAnswer,
    required this.onAnswerSubmitted,
    this.isDarkMode = false,
  }) : super(key: key);

  @override
  State<CopilotQuestionCard> createState() => _CopilotQuestionCardState();
}

class _CopilotQuestionCardState extends State<CopilotQuestionCard> {
  final TextEditingController _customInputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customInputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitAnswer(String answer) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;
    _focusNode.unfocus();
    widget.onAnswerSubmitted(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final payload = widget.questionPayload;
    final hasAnswered = widget.currentAnswer != null && widget.currentAnswer!.isNotEmpty;

    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.cyanAccent.withOpacity(0.4) : const Color(0xFF93C5FD);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.cyanAccent.withOpacity(0.08) : const Color(0xFF2563EB).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: AI Question Badge & Status ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF06B6D4), const Color(0xFF3B82F6)]
                        : [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'AI Question',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!hasAnswered) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amberAccent : Colors.amber.shade700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isDark ? Colors.amberAccent : Colors.amber.shade700).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 10,
                        color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Waiting for you',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.4), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 10, color: Colors.green),
                      SizedBox(width: 3),
                      Text(
                        'Answered',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // ── Question Text ──
          Text(
            payload.question,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 10),

          // ── Options Chips ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...payload.options.map((opt) {
                final isDefault = opt == payload.defaultOption;
                final isSelected = widget.currentAnswer == opt;

                Color chipBg;
                Color chipBorder;
                Color chipTextColor;

                if (isSelected) {
                  chipBg = isDark ? Colors.cyan.shade900 : const Color(0xFFDBEAFE);
                  chipBorder = isDark ? Colors.cyanAccent : const Color(0xFF2563EB);
                  chipTextColor = isDark ? Colors.cyanAccent : const Color(0xFF1D4ED8);
                } else if (isDefault) {
                  chipBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF);
                  chipBorder = isDark ? Colors.cyanAccent.withOpacity(0.8) : const Color(0xFF3B82F6);
                  chipTextColor = isDark ? Colors.cyanAccent : const Color(0xFF1D4ED8);
                } else {
                  chipBg = isDark ? const Color(0xFF0F172A) : Colors.white;
                  chipBorder = isDark ? Colors.white24 : const Color(0xFFE2E8F0);
                  chipTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasAnswered ? null : () => _submitAnswer(opt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: chipBorder,
                          width: (isDefault || isSelected) ? 1.5 : 1,
                        ),
                        boxShadow: (isDefault || isSelected)
                            ? [
                                BoxShadow(
                                  color: (isDark ? Colors.cyanAccent : const Color(0xFF2563EB)).withOpacity(0.12),
                                  blurRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                          ] else if (isDefault) ...[
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              opt,
                              style: TextStyle(
                                color: chipTextColor,
                                fontSize: 11,
                                fontWeight: (isDefault || isSelected) ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // ── Custom Answer Toggle Chip ──
              if (!hasAnswered)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showCustomInput = !_showCustomInput;
                      });
                      if (_showCustomInput) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _focusNode.requestFocus();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showCustomInput
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                            : (isDark ? const Color(0xFF0F172A) : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showCustomInput
                              ? (isDark ? Colors.purpleAccent : const Color(0xFF8B5CF6))
                              : (isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                          width: _showCustomInput ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 13,
                            color: isDark ? Colors.purpleAccent : const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Custom Answer...',
                            style: TextStyle(
                              color: isDark ? Colors.purpleAccent : const Color(0xFF7C3AED),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Inline Custom Answer Input Bar ──
          if (_showCustomInput && !hasAnswered) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.purpleAccent.withOpacity(0.6) : const Color(0xFF8B5CF6),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customInputController,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 11.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your custom answer or instructions...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: _submitAnswer,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: isDark ? Colors.purpleAccent : const Color(0xFF8B5CF6),
                    ),
                    onPressed: () => _submitAnswer(_customInputController.text),
                    tooltip: 'Send Custom Answer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          ],

          // ── Display Selected / Custom Answer if Answered ──
          if (hasAnswered) ...[
            const SizedBox(height: 6),
            Text(
              'Your answer: "${widget.currentAnswer}"',
              style: TextStyle(
                color: subtextColor,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
