import 'package:flutter/material.dart';

class SearchToolbar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<String> onReplace;
  final ValueChanged<String> onReplaceAll;
  final VoidCallback onClose;
  final int currentMatch;
  final int totalMatches;

  const SearchToolbar({
    Key? key,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onClose,
    this.currentMatch = 0,
    this.totalMatches = 0,
  }) : super(key: key);

  @override
  State<SearchToolbar> createState() => _SearchToolbarState();
}

class _SearchToolbarState extends State<SearchToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  bool _showReplace = false;

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(_showReplace ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                onPressed: () {
                  setState(() {
                    _showReplace = !_showReplace;
                  });
                },
                tooltip: 'Toggle Replace',
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Find...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: widget.onSearch,
                ),
              ),
              if (widget.totalMatches > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${widget.currentMatch} / ${widget.totalMatches}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: widget.onPrevious,
                tooltip: 'Previous Match',
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: widget.onNext,
                tooltip: 'Next Match',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                tooltip: 'Close Search',
              ),
            ],
          ),
          if (_showReplace)
            Row(
              children: [
                const SizedBox(width: 48), // Align with search field
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    decoration: const InputDecoration(
                      hintText: 'Replace with...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onReplace(_replaceController.text),
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: () => widget.onReplaceAll(_replaceController.text),
                  child: const Text('All'),
                ),
                const SizedBox(width: 8),
              ],
            ),
        ],
      ),
    );
  }
}
