import 'package:flutter/cupertino.dart';

import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/compose_post_screen.dart';
import '../services/image_picker_service.dart';

/// "React with Video": records a clip with the camera and opens the composer
/// with it, quoting the post being reacted to (that is what X does: a video
/// reaction is a quote post that holds your clip). Returns true once posted.
Future<bool> reactWithVideo(BuildContext context, Post post) async {
  try {
    final clip = await recordCameraVideo();
    if (clip == null || !context.mounted) return false;
    final posted = await Navigator.of(context).push<bool>(
      appRoute(
        ComposePostScreen(quoting: post, initialVideo: clip),
        fullscreen: true,
      ),
    );
    if (posted == true && context.mounted) {
      showSuccess(context, 'Your video reaction was posted');
      return true;
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
  return false;
}
