import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../core/config.dart';

/// An image chosen from the gallery, ready to upload to Supabase Storage.
class PickedImage {
  const PickedImage(this.bytes, this.extension);

  final Uint8List bytes;

  /// jpg, png, webp or gif (lower-case, no dot).
  final String extension;

  String get contentType =>
      'image/${extension == 'jpg' ? 'jpeg' : extension}';
}

/// Opens the gallery and returns the chosen image (or null if cancelled).
Future<PickedImage?> pickGalleryImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  var ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
  if (ext == 'jpeg') ext = 'jpg';
  if (!const ['jpg', 'png', 'webp', 'gif'].contains(ext)) ext = 'jpg';
  return PickedImage(bytes, ext);
}

/// Opens the gallery and lets the user tick several pictures at once (up to
/// [max]). With room for just one it behaves like [pickGalleryImage].
Future<List<PickedImage>> pickGalleryImages(int max) async {
  if (max <= 0) return const [];
  if (max == 1) {
    final one = await pickGalleryImage();
    return one == null ? const [] : [one];
  }
  // image_picker needs a limit of at least 2.
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 1600,
    imageQuality: 85,
    limit: max,
  );
  final out = <PickedImage>[];
  for (final file in files.take(max)) {
    final bytes = await file.readAsBytes();
    var ext =
        file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    if (ext == 'jpeg') ext = 'jpg';
    if (!const ['jpg', 'png', 'webp', 'gif'].contains(ext)) ext = 'jpg';
    out.add(PickedImage(bytes, ext));
  }
  return out;
}

/// Opens the camera and returns the photo taken (or null if cancelled).
Future<PickedImage?> pickCameraImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedImage(await file.readAsBytes(), 'jpg');
}

/// A video chosen from the gallery. It stays a file on the phone (videos are
/// too big to hold in memory) and is uploaded when the post is sent.
class PickedVideo {
  const PickedVideo({
    required this.path,
    required this.extension,
    required this.bytes,
    required this.duration,
  });

  final String path;

  /// mp4, mov, m4v or 3gp (lower-case, no dot).
  final String extension;
  final int bytes;
  final Duration duration;

  String get contentType {
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case '3gp':
        return 'video/3gpp';
      default:
        return 'video/mp4';
    }
  }
}

/// What the "photo" button of the composer returned: photos and GIFs, or one
/// video (never both: a post holds up to 4 photos / GIFs *or* 1 video).
class PickedMedia {
  const PickedMedia({this.images = const [], this.video, this.skipped = false});

  final List<PickedImage> images;
  final PickedVideo? video;

  /// More than one video was ticked (only the first is used), or photos were
  /// ticked together with a video (only the video is used).
  final bool skipped;
}

const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'mkv', 'avi', 'webm'};
const _playableVideo = {'mp4', 'mov', 'm4v', '3gp'};

bool _isVideo(XFile f) {
  final mime = f.mimeType ?? '';
  if (mime.startsWith('video/')) return true;
  final name = f.name.toLowerCase();
  if (!name.contains('.')) return false;
  return _videoExtensions.contains(name.split('.').last);
}

/// Checks format, size and length of a chosen video; throws a readable
/// message when it can not be posted.
Future<PickedVideo> _readVideo(XFile file) async {
  final name = file.name.toLowerCase();
  var ext = name.contains('.') ? name.split('.').last : 'mp4';
  if (!_playableVideo.contains(ext)) {
    throw 'This video format ($ext) is not supported. Use an MP4 or MOV video.';
  }
  final size = await File(file.path).length();
  if (size > AppConfig.maxVideoBytes) {
    throw 'This video is larger than 50 MB. Pick a shorter or smaller one.';
  }
  final probe = VideoPlayerController.file(File(file.path));
  Duration length;
  try {
    await probe.initialize();
    length = probe.value.duration;
  } catch (_) {
    throw 'This video could not be opened.';
  } finally {
    await probe.dispose();
  }
  if (length.inSeconds > AppConfig.maxVideoSeconds) {
    throw 'Videos can be up to 2 minutes 20 seconds long.';
  }
  return PickedVideo(
    path: file.path,
    extension: ext,
    bytes: size,
    duration: length,
  );
}

/// Opens the gallery for photos *and* videos (like X's photo button). Room is
/// the number of photos / GIFs that still fit; a video needs the whole post.
Future<PickedMedia> pickGalleryMedia(int room) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (room <= 1) {
    final one = await picker.pickMedia(maxWidth: 1600, imageQuality: 85);
    files = one == null ? const [] : [one];
  } else {
    // image_picker needs a limit of at least 2.
    files = await picker.pickMultipleMedia(
      maxWidth: 1600,
      imageQuality: 85,
      limit: room,
    );
  }
  if (files.isEmpty) return const PickedMedia();

  final videos = files.where(_isVideo).toList();
  if (videos.isNotEmpty) {
    final video = await _readVideo(videos.first);
    return PickedMedia(
      video: video,
      skipped: files.length > 1,
    );
  }
  final out = <PickedImage>[];
  for (final file in files.take(room)) {
    final bytes = await file.readAsBytes();
    var ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    if (ext == 'jpeg') ext = 'jpg';
    if (!const ['jpg', 'png', 'webp', 'gif'].contains(ext)) ext = 'jpg';
    out.add(PickedImage(bytes, ext));
  }
  return PickedMedia(images: out);
}

/// Opens the camera in video mode (the "React with Video" of the repost
/// popup). Returns the clip, or null when the person cancelled. Throws a
/// readable message when the clip can not be posted.
Future<PickedVideo?> recordCameraVideo() async {
  final file = await ImagePicker().pickVideo(
    source: ImageSource.camera,
    maxDuration: const Duration(seconds: AppConfig.maxVideoSeconds),
  );
  if (file == null) return null;
  return _readVideo(file);
}
