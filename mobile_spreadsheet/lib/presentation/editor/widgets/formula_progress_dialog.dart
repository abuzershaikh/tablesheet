import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/services/super_engine/ffi_bridge.dart';

class FormulaProgressDialog extends StatefulWidget {
  final String? message;
  final VoidCallback? onCancel;

  const FormulaProgressDialog({
    Key? key,
    this.message,
    this.onCancel,
  }) : super(key: key);

  @override
  State<FormulaProgressDialog> createState() => _FormulaProgressDialogState();
}

class _FormulaProgressDialogState extends State<FormulaProgressDialog> {
  Timer? _timer;
  double? _progress;
  String? _progressText;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _syncProgress();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _syncProgress());
  }

  void _syncProgress() {
    final active = NativeEngine.isFormulaProgressActive;
    final total = NativeEngine.formulaProgressTotal;
    final current = NativeEngine.formulaProgressCurrent;

    if (!mounted) return;

    setState(() {
      _isActive = active;
      if (active && total > 0) {
        final fraction = (current / total).clamp(0.0, 1.0);
        _progress = fraction;
        _progressText = '$current / $total';
      } else {
        _progress = null;
        _progressText = active ? 'Processing...' : null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Processing Formula',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              if (_progress == null)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress! * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    if (_progressText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _progressText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                widget.message ?? 'Creating large array...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showFormulaProgress<T>({
  required BuildContext context,
  required Future<T> Function() computation,
  String? message,
  bool showPercentage = false,
}) async {
  bool isCompleted = false;
  bool isDialogShown = false;
  BuildContext? dialogContext;

  final timer = Timer(const Duration(milliseconds: 250), () {
    if (!isCompleted && context.mounted) {
      isDialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext ctx) {
          dialogContext = ctx;
          return FormulaProgressDialog(
            message: message,
          );
        },
      );
    }
  });

  try {
    final result = await computation();
    isCompleted = true;
    timer.cancel();
    
    if (isDialogShown) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    }
    return result;
  } catch (e) {
    isCompleted = true;
    timer.cancel();
    if (isDialogShown) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    }
    rethrow;
  }
}
