import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Audio column type - for audio file URLs or paths
class AudioColumnType extends ColumnType {
  const AudioColumnType() : super(
    id: 'audio',
    name: 'Audio',
    description: 'Audio files or recordings',
    icon: Icons.audiotrack,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    final str = value.toString();
    return str.isEmpty || 
           str.contains('http') || 
           str.endsWith('.mp3') || 
           str.endsWith('.wav') || 
           str.endsWith('.m4a') || 
           str.endsWith('.aac');
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    return input;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Column(
      children: [
        if (initialValue != null && initialValue.toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.audiotrack, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    initialValue.toString().split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    // TODO: Play audio
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement audio picker/recorder
            onChanged('audio_recording.mp3');
          },
          icon: const Icon(Icons.mic),
          label: const Text('Record Audio'),
        ),
      ],
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.deepPurple;
}
