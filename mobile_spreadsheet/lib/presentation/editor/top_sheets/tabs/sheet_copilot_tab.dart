import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/presentation/copilot/copilot_mini_view.dart';

class SheetCopilotTab extends StatelessWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;
  final VoidCallback? onOpenCopilot;

  const SheetCopilotTab({
    Key? key,
    this.sheetId = 'Sheet1',
    this.onPipelineApplied,
    this.onOpenCopilot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CopilotMiniView(
      sheetId: sheetId,
      onPipelineApplied: onPipelineApplied,
    );
  }
}
