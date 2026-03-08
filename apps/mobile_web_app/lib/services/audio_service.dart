import 'dart:io';
import 'dart:convert';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Manages microphone recording and audio playback.
class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _recorderReady = false;
  String? _currentRecordingPath;

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Recorder ─────────────────────────────────────────────────────────────

  Future<void> openRecorder() async {
    if (!_recorderReady) {
      await _recorder.openRecorder();
      _recorderReady = true;
    }
  }

  Future<void> startRecording() async {
    if (!_recorderReady) await openRecorder();

    final dir = await getTemporaryDirectory();
    _currentRecordingPath = '${dir.path}/speakup_turn.wav';

    await _recorder.startRecorder(
      toFile: _currentRecordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,   // Whisper's optimal sample rate
      numChannels: 1,      // Mono
    );
  }

  Future<String?> stopRecordingAsBase64() async {
    await _recorder.stopRecorder();
    if (_currentRecordingPath == null) return null;

    final file = File(_currentRecordingPath!);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    await file.delete(); // Clean up temp file
    return base64Encode(bytes);
  }

  // ── Player ────────────────────────────────────────────────────────────────

  Future<void> playBase64Audio(String base64Audio) async {
    final bytes = base64Decode(base64Audio);
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/ai_response.wav');
    await tempFile.writeAsBytes(bytes);
    await _player.setFilePath(tempFile.path);
    await _player.play();
    // Clean up after playback
    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await tempFile.delete();
      }
    });
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  bool get isRecording => _recorder.isRecording;
  bool get isPlaying => _player.playing;

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _player.dispose();
    _recorderReady = false;
  }
}
