import 'package:flutter/material.dart';
import 'formula_helper_sheet.dart';
import 'formula_auto_complete_overlay.dart';

/// Formula bar widget for displaying and editing cell formulas with Auto-Complete
class FormulaBar extends StatefulWidget {
  final String? currentCellAddress;
  final String? currentValue;
  final bool isVisible;
  final ValueChanged<String>? onValueChanged;
  final VoidCallback? onSubmit;

  const FormulaBar({
    Key? key,
    this.currentCellAddress,
    this.currentValue,
    this.isVisible = true,
    this.onValueChanged,
    this.onSubmit,
  }) : super(key: key);

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showAutoComplete = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != oldWidget.currentValue && !_focusNode.hasFocus) {
      _controller.text = widget.currentValue ?? '';
      _checkAutoComplete(_controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showAutoComplete = false;
      });
    } else {
      _checkAutoComplete(_controller.text);
    }
  }

  void _checkAutoComplete(String text) {
    if (text.startsWith('=')) {
      final String afterEquals = text.substring(1);

      // Hide suggestions once a function parenthesis is opened (e.g. =SUM() or after formula selection
      if (afterEquals.contains('(')) {
        setState(() {
          _showAutoComplete = false;
        });
        return;
      }

      final RegExp funcRegex = RegExp(r'([A-Za-z]+)$');
      final match = funcRegex.firstMatch(afterEquals);

      if (match != null && match.group(1) != null) {
        setState(() {
          _currentQuery = match.group(1)!;
          _showAutoComplete = true;
        });
      } else if (text == '=') {
        setState(() {
          _currentQuery = '';
          _showAutoComplete = true;
        });
      } else {
        setState(() {
          _showAutoComplete = false;
        });
      }
    } else {
      setState(() {
        _showAutoComplete = false;
      });
    }
  }

  void _insertSymbol(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    String newText;
    int newOffset;

    if (selection.isValid && selection.start >= 0) {
      final start = selection.start;
      final end = selection.end;
      newText = text.replaceRange(start, end, symbol);
      newOffset = start + symbol.length;
    } else {
      newText = text + symbol;
      newOffset = newText.length;
    }

    setState(() {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: newOffset));
    });

    _checkAutoComplete(newText);
    widget.onValueChanged?.call(newText);
  }

  void _applySuggestion(FormulaSuggestion suggestion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.isValid ? selection.start : text.length;

    final textBefore = text.substring(0, cursorPos);
    final textAfter = text.substring(cursorPos);

    final RegExp funcRegex = RegExp(r'([A-Za-z]+)$');
    final match = funcRegex.firstMatch(textBefore);

    String newPrefix;
    if (match != null && match.group(1) != null) {
      newPrefix = textBefore.substring(0, textBefore.length - match.group(1)!.length) + '${suggestion.name}(';
    } else if (textBefore.endsWith('=')) {
      newPrefix = '${textBefore}${suggestion.name}(';
    } else if (!textBefore.startsWith('=')) {
      newPrefix = '=${suggestion.name}(';
    } else {
      newPrefix = '${textBefore}${suggestion.name}(';
    }

    final newText = newPrefix + textAfter;
    final newOffset = newPrefix.length;

    setState(() {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newOffset),
      );
      _showAutoComplete = false;
    });

    FormulaMemoryService.recordUsage(suggestion.name, newText);
    widget.onValueChanged?.call(newText);
  }

  void _showFormulaHelper(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FormulaHelperSheet(
        onFormulaSelected: (formula) {
          setState(() {
            _controller.text = formula;
          });
          widget.onValueChanged?.call(formula);
          widget.onSubmit?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    final isFormulaMode = _controller.text.startsWith('=');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Auto-Complete Suggestion Box (Above Formula Bar)
        if (_showAutoComplete && _focusNode.hasFocus)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: FormulaAutoCompleteOverlay(
              query: _currentQuery,
              onSelected: _applySuggestion,
            ),
          ),

        // Quick Symbol & Equals Shortcut Bar (Shown when focused)
        if (_focusNode.hasFocus && !_showAutoComplete)
          Container(
            height: 32,
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _SymbolChip(
                  label: '=',
                  isPrimary: true,
                  onTap: () => _insertSymbol('='),
                ),
                _SymbolChip(label: '+', onTap: () => _insertSymbol('+')),
                _SymbolChip(label: '-', onTap: () => _insertSymbol('-')),
                _SymbolChip(label: '*', onTap: () => _insertSymbol('*')),
                _SymbolChip(label: '/', onTap: () => _insertSymbol('/')),
                _SymbolChip(label: '(', onTap: () => _insertSymbol('(')),
                _SymbolChip(label: ')', onTap: () => _insertSymbol(')')),
                _SymbolChip(label: ':', onTap: () => _insertSymbol(':')),
                _SymbolChip(label: ',', onTap: () => _insertSymbol(',')),
                _SymbolChip(label: 'SUM', onTap: () => _insertSymbol('=SUM(')),
                _SymbolChip(label: 'AVERAGE', onTap: () => _insertSymbol('=AVERAGE(')),
              ],
            ),
          ),

        // Main Formula Bar
        Container(
          height: 42, // Sleek, compact height
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              // Cell address badge
              Container(
                width: 55,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  widget.currentCellAddress ?? 'A1',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Compact font size
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              // fx Helper Button
              InkWell(
                onTap: () => _showFormulaHelper(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'fx',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Compact font size
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey[300],
              ),

              // Formula input TextField (Compact 12px Font Size)
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontSize: 12.0, // Reduced font size for formula input
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    hintText: 'Enter value or formula (e.g. =SUM(A1:A10))',
                    hintStyle: TextStyle(fontSize: 11.0, color: Colors.grey),
                  ),
                  onChanged: (val) {
                    _checkAutoComplete(val);
                    widget.onValueChanged?.call(val);
                  },
                  onSubmitted: (_) {
                    setState(() {
                      _showAutoComplete = false;
                    });
                    widget.onSubmit?.call();
                    _focusNode.unfocus();
                  },
                ),
              ),

              // Quick = Button inside textfield if empty
              if (!isFormulaMode)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _insertSymbol('='),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '=',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // Submit button
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _showAutoComplete = false;
                  });
                  widget.onSubmit?.call();
                  _focusNode.unfocus();
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _SymbolChip extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SymbolChip({
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 3, bottom: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPrimary ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }
}