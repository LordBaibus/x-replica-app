import 'package:flutter/widgets.dart';

import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';

/// Checks the author's "who can reply" setting before a reply is written.
/// Shows why and returns false when replying is not allowed.
Future<bool> ensureCanReply(BuildContext context, Post post) async {
  try {
    final reason = await Api.replyBlockedReason(post);
    if (reason == null) return true;
    if (context.mounted) {
      await notify(context, title: 'You can’t reply to this post', message: reason);
    }
    return false;
  } catch (_) {
    // If the check itself fails, let the server decide when the reply is sent.
    return true;
  }
}
