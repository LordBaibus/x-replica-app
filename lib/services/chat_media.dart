import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'image_picker_service.dart';

/// What kind of file a chat message carries.
enum ChatMediaKind { image, video, voice }

extension ChatMediaKindX on ChatMediaKind {
  /// Stored in `messages.media_kind`.
  String get value => name;

  /// The text saved in `messages.content` for such a message, so the inbox
  /// list and previews show something readable.
  String get label {
    switch (this) {
      case ChatMediaKind.image:
        return '📷 Photo';
      case ChatMediaKind.video:
        return '🎥 Video';
      case ChatMediaKind.voice:
        return '🎤 Voice message';
    }
  }

  static ChatMediaKind? parse(String? value) {
    for (final k in ChatMediaKind.values) {
      if (k.name == value) return k;
    }
    return null;
  }
}

/// A photo, video or voice message that is ready to be uploaded and sent.
/// Small things (photos) are kept as [bytes]; videos and voice recordings stay
/// a file on the phone ([path]).
class ChatDraft {
  const ChatDraft({
    required this.kind,
    required this.extension,
    required this.contentType,
    this.bytes,
    this.path,
    this.durationMs,
  }) : assert(bytes != null || path != null);

  final ChatMediaKind kind;
  final Uint8List? bytes;
  final String? path;

  /// Lower-case, no dot (jpg, mp4, m4a ...).
  final String extension;
  final String contentType;
  final int? durationMs;

  factory ChatDraft.image(PickedImage image) => ChatDraft(
        kind: ChatMediaKind.image,
        bytes: image.bytes,
        extension: image.extension,
        contentType: image.contentType,
      );

  factory ChatDraft.video(PickedVideo video) => ChatDraft(
        kind: ChatMediaKind.video,
        path: video.path,
        extension: video.extension,
        contentType: video.contentType,
        durationMs: video.duration.inMilliseconds,
      );
}

/// Longest voice message (the recorder stops and sends by itself).
const int maxVoiceSeconds = 5 * 60;

/// Records a voice message to an AAC (.m4a) file in the temporary folder.
/// Needs the microphone permission (asked on the first recording).
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  final Stopwatch _clock = Stopwatch();
  String? _path;
  bool _active = false;

  bool get isRecording => _active;

  /// Time recorded so far.
  Duration get elapsed => _clock.elapsed;

  /// Starts recording. False when the microphone is not allowed.
  Future<bool> start() async {
    if (_active) return true;
    if (!await _rec.hasPermission()) return false;
    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _active = true;
    _clock
      ..reset()
      ..start();
    return true;
  }

  /// Loudness from 0 (silence) to 1, for the little level bars.
  Future<double> level() async {
    try {
      final a = await _rec.getAmplitude();
      // dBFS: about -45 (quiet room) .. 0 (very loud)
      return ((a.current + 45) / 45).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  /// Stops and returns the recording (null when nothing usable was made).
  Future<ChatDraft?> stop() async {
    if (!_active) return null;
    _active = false;
    _clock.stop();
    final ms = _clock.elapsed.inMilliseconds;
    String? out;
    try {
      out = await _rec.stop();
    } catch (_) {
      out = null;
    }
    out ??= _path;
    _path = null;
    if (out == null || !File(out).existsSync()) return null;
    return ChatDraft(
      kind: ChatMediaKind.voice,
      path: out,
      extension: 'm4a',
      contentType: 'audio/mp4',
      durationMs: ms,
    );
  }

  /// Throws the recording away.
  Future<void> cancel() async {
    if (!_active) return;
    _active = false;
    _clock.stop();
    try {
      await _rec.cancel();
    } catch (_) {}
    final p = _path;
    _path = null;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await cancel();
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
