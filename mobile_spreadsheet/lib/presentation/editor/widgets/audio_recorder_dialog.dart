import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderDialog extends StatefulWidget {
  final String? existingAudioPath;

  const AudioRecorderDialog({Key? key, this.existingAudioPath}) : super(key: key);

  @override
  State<AudioRecorderDialog> createState() => _AudioRecorderDialogState();
}

class _AudioRecorderDialogState extends State<AudioRecorderDialog> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _audioPath = widget.existingAudioPath;
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }

    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted == false) {
        // Continue anyway, Android 11+ might allow writing to Documents without this if we use MediaStore, 
        // but for dart:io we usually need it or we rely on Scoped Storage.
      }
      if (await Permission.manageExternalStorage.request().isGranted == false) {
         // ignore
      }
    }

    try {
      Directory publicDir;
      if (Platform.isAndroid) {
        publicDir = Directory('/storage/emulated/0/Documents/TableNotes/Audio');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        publicDir = Directory('${dir.path}/TableNotes/Audio');
      }
      
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${publicDir.path}/$fileName';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _audioPath = null;
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _audioPath = path;
    });
  }

  Future<void> _togglePlay() async {
    if (_audioPath == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
    }
  }
  
  Future<void> _deleteAudio() async {
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
         debugPrint("Error deleting file: $e");
      }
    }
    setState(() {
      _audioPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Audio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_audioPath != null) ...[
            const Icon(Icons.audio_file, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 48,
                  color: Colors.green,
                  onPressed: _togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  iconSize: 32,
                  color: Colors.red,
                  onPressed: _deleteAudio,
                ),
              ],
            ),
          ] else ...[
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 64,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(_isRecording ? 'Recording...' : 'Tap mic to start'),
            const SizedBox(height: 16),
            IconButton(
              icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
              iconSize: 64,
              color: _isRecording ? Colors.red : Colors.blue,
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _audioPath),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
