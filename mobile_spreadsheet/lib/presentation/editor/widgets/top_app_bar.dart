import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top app bar for editor screen
class EditorTopAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final Function(String) onRename;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onShare;
  final VoidCallback onMoreOptions;
  final VoidCallback? onSaveToDevice;
  final VoidCallback? onToggleTopDrawer;
  final VoidCallback? onAiSettings;
  final bool isTopDrawerOpen;
  final Widget? copyAction;
  final Widget? pasteAction;

  const EditorTopAppBar({
    Key? key,
    required this.title,
    required this.onRename,
    required this.onBack,
    required this.onSearch,
    required this.onShare,
    required this.onMoreOptions,
    this.onSaveToDevice,
    this.onToggleTopDrawer,
    this.onAiSettings,
    this.isTopDrawerOpen = false,
    this.copyAction,
    this.pasteAction,
  }) : super(key: key);

  @override
  State<EditorTopAppBar> createState() => _EditorTopAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

class _EditorTopAppBarState extends State<EditorTopAppBar> {
  bool _isEditing = false;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.title);
  }

  @override
  void didUpdateWidget(EditorTopAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.title != widget.title) {
      _textController.text = widget.title;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitName() {
    setState(() {
      _isEditing = false;
    });
    if (_textController.text.trim().isNotEmpty && _textController.text != widget.title) {
      widget.onRename(_textController.text.trim());
    } else {
      _textController.text = widget.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to green so it blends seamlessly
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF107C41),
      statusBarIconBrightness: Brightness.light,
    ));

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF107C41), // Excel green
      ),
      child: Row(
        children: [
          // Fixed Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: widget.onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          
          // Scrollable area for everything else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title / Edit Text
                  Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isEditing
                        ? TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Name...',
                              hintStyle: TextStyle(color: Colors.white70),
                            ),
                            autofocus: true,
                            onSubmitted: (_) => _submitName(),
                            onTapOutside: (_) => _submitName(),
                            cursorColor: Colors.white,
                          )
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEditing = true;
                                _textController.text = widget.title;
                              });
                              _focusNode.requestFocus();
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const Icon(Icons.edit, color: Colors.white70, size: 12),
                              ],
                            ),
                          ),
                  ),
                  
                  // Save to Device Direct Action Button
                  if (widget.onSaveToDevice != null)
                    IconButton(
                      icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      tooltip: 'Save to Device',
                      onPressed: widget.onSaveToDevice,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    ),

                  // Downward / Upward Tool Drawer Handle Button
                  if (widget.onToggleTopDrawer != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: widget.isTopDrawerOpen ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: Icon(
                          widget.isTopDrawerOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Tool Drawer',
                        onPressed: widget.onToggleTopDrawer,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      ),
                    ),

                  // Mini Actions
                  if (widget.copyAction != null) _buildMiniAction(widget.copyAction!),
                  if (widget.pasteAction != null) _buildMiniAction(widget.pasteAction!),
                  
                  if (widget.onAiSettings != null)
                    _buildMiniIconButton(Icons.smart_toy, widget.onAiSettings!),
                  _buildMiniIconButton(Icons.search, widget.onSearch),
                  _buildMiniIconButton(Icons.share, widget.onShare),
                  _buildMiniIconButton(Icons.more_vert, widget.onMoreOptions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction(Widget action) {
    return Transform.scale(
      scale: 0.8,
      child: action,
    );
  }

  Widget _buildMiniIconButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }
}
