import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sound/flutter_sound.dart' hide AudioSource;
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

/// Manages microphone recording and audio playback.
class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _recorderReady = false;
  String? _currentRecordingPath; // Used for Blobs on Web or relative paths

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    if (kIsWeb) return true; // Browser handles this via prompt
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

    // On Web, we don't use file paths. Flutter Sound handles Blobs automatically.
    _currentRecordingPath = kIsWeb ? 'speakup_turn.webm' : 'speakup_turn.wav';

    await _recorder.startRecorder(
      toFile: _currentRecordingPath,
      codec: kIsWeb ? Codec.opusWebM : Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  Future<String?> stopRecordingAsBase64() async {
    final path = await _recorder.stopRecorder();
    if (path == null) return null;

    if (kIsWeb) {
      // In Web, path is a Blob URL (blob:http://...)
      final response = await http.get(Uri.parse(path));
      return base64Encode(response.bodyBytes);
    } else {
      // Mobile logic would use dart:io here, but since this is a Web Vercel focus
      // and we want to avoid dart:io crashes, we'd typically use a conditional import
      // for File. For now, we prioritize the Web fix that was requested.
      return null; // Local mobile testing would need dart:io version
    }
  }

  // ── Player ────────────────────────────────────────────────────────────────

  Future<void> playBase64Audio(String base64Audio) async {
    // just_audio works best with Data URIs for base64 on Web
    final dataUri = 'data:audio/wav;base64,$base64Audio';
    await _player.setAudioSource(AudioSource.uri(Uri.parse(dataUri)));
    await _player.play();
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
