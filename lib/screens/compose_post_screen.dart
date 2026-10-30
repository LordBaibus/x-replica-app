import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Paint, PaintingStyle, Rect, Size, StrokeCap;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/api.dart';
import '../services/drafts.dart';
import '../services/image_picker_service.dart';
import '../services/moderation.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/gif_picker_dialog.dart';
import '../widgets/location_picker.dart';
import '../widgets/post_video.dart';
import '../widgets/quote_card.dart';
import '../widgets/quote_picker.dart';
import '../widgets/responsive.dart';
import '../widgets/schedule_dialog.dart';
import 'drafts_screen.dart';
import 'scheduled_posts_screen.dart';

/// Who may reply: value stored in the database, short label, sentence.
class _ReplyScope {
  const _ReplyScope(this.value, this.label, this.sentence);
  final String value;
  final String label;
  final String sentence;
}

const _replyScopes = <_ReplyScope>[
  _ReplyScope('everyone', 'Everyone', 'Everyone can reply'),
  _ReplyScope('following', 'Accounts you follow', 'Accounts you follow can reply'),
  _ReplyScope('verified', 'Verified accounts', 'Verified accounts can reply'),
  _ReplyScope('mentioned', 'Only accounts you mention', 'Only accounts you mention can reply'),
];

/// Write a new post. Laid out like X's composer: Cancel / Post on top, avatar
/// beside a borderless "What's happening?" field, then a toolbar with photo,
/// camera, AI helper, GIF, schedule, quote, poll, location and content
/// disclosures, and a "+" that adds another post to a thread. Everything is
/// built from Cupertino widgets so it behaves the same on iOS and Android.
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({
    super.key,
    this.initialText = '',
    this.replyTo,
    this.replyingTo,
    this.parentId,
    this.communityId,
    this.communityName,
    this.quoting,
    this.editing,
    this.initialVideo,
  });

  /// Text the field starts with (e.g. "@sam " when replying).
  final String initialText;

  /// Post being replied to: shown above the field with a thread line.
  final Post? replyTo;

  /// Username shown as "Replying to @name" above the field.
  final String? replyingTo;

  /// Id of the post being replied to (the new post is saved as its reply).
  final String? parentId;

  /// Community the post is written in (shown as "Posting in …").
  final String? communityId;
  final String? communityName;

  /// Post to quote right from the start (the "Quote" option of a repost).
  final Post? quoting;

  /// A video that is attached from the start (a "React with Video": the clip
  /// just recorded, quoting the post it reacts to).
  final PickedVideo? initialVideo;

  /// Post whose text is being changed ("Edit post"). The composer then shows
  /// only the text field and pops with the updated [Post].
  final Post? editing;

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  late final TextEditingController _text;

  // Audience, like X's "Everyone" chip: my followers, or one of my communities.
  late String? _communityId = widget.communityId;
  late String? _communityName = widget.communityName;
  final UndoHistoryController _undo = UndoHistoryController();
  Profile? _me;
  bool _busy = false;
  bool _aiBusy = false;

  // Attachments of the first post.
  List<PickedImage> _images = [];
  // GIFs picked from the GIF search (links). Photos and GIFs share the limit
  // of 4 media per post, like on X.
  List<String> _gifUrls = [];

  // One video instead of photos / GIFs (a post has one or the other).
  PickedVideo? _video;
  QuotedPost? _quote;

  // Poll builder.
  List<TextEditingController> _pollFields = [];
  final List<TextEditingController> _retired = [];
  int _pollDays = 1;
  int _pollHours = 0;
  int _pollMins = 0;
  bool _lengthOpen = false;
  List<FixedExtentScrollController> _pollWheels = [];
  final List<FixedExtentScrollController> _retiredWheels = [];

  // Settings.
  String _replyScope = 'everyone';
  String? _location;
  bool _paid = false;
  bool _ai = false;
  DateTime? _scheduledAt;

  // Earlier posts of the thread (text only), in order.
  final List<String> _thread = [];

  // Draft this composer was opened from (saved again under the same id).
  String? _draftId;

  // "@name" suggestions.
  List<Profile> _mentions = const [];
  String? _mentionKey;
  Timer? _mentionTimer;

  bool get _editing => widget.editing != null;

  bool get _hasPoll => _pollFields.isNotEmpty;
  static const _maxMedia = 4;

  int get _mediaCount => _images.length + _gifUrls.length;
  bool get _hasMedia => _mediaCount > 0 || _video != null;

  String? get _replyUser => widget.replyTo?.username ?? widget.replyingTo;
  String? get _parentId => widget.replyTo?.id ?? widget.parentId;

  /// I am protected and the person I reply to does not follow me.
  bool get _protectedReply {
    final to = widget.replyTo;
    if (to == null || to.userId == Api.uid) return false;
    return (_me?.protectedPosts ?? false) &&
        !Moderation.instance.followers.contains(to.userId);
  }

  bool get _hasContent => _editing
      ? _text.text.trim() != widget.editing!.content.trim()
      : _hasAnyContent;

  bool get _hasAnyContent =>
      _text.text.trim().isNotEmpty ||
      _hasMedia ||
      _quote != null ||
      _thread.isNotEmpty;

  /// Text, photo, GIF or quote is needed; a poll also needs a question.
  bool get _canPost {
    if (_busy || _aiBusy) return false;
    if (_editing) {
      final t = _text.text.trim();
      final hasPicture = widget.editing!.imageUrl != null;
      return (t.isNotEmpty || hasPicture) &&
          t != widget.editing!.content.trim() &&
          t.length <= AppConfig.maxPostLength;
    }
    if (AppConfig.maxPostLength - _text.text.length < 0) return false;
    if (!_hasContent) return false;
    if (_hasPoll && _text.text.trim().isEmpty) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: widget.editing?.content ?? widget.initialText,
    );
    _text.addListener(_onTextChanged);
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    final q = widget.quoting;
    if (q != null) _quote = _quoteOf(q);
    _video = widget.initialVideo;
    _loadMe();
    Moderation.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mentionTimer?.cancel();
    _protectedTap.dispose();
    _text.dispose();
    _undo.dispose();
    for (final c in [..._pollFields, ..._retired]) {
      c.dispose();
    }
    for (final w in [..._pollWheels, ..._retiredWheels]) {
      w.dispose();
    }
    super.dispose();
  }

  QuotedPost _quoteOf(Post p) => QuotedPost(
        id: p.id,
        content: p.content,
        username: p.username,
        displayName: p.displayName,
        avatarUrl: p.avatarUrl,
        imageUrl: p.imageUrl,
        verified: p.authorVerified,
        createdAt: p.createdAt,
      );

  Future<void> _loadMe() async {
    try {
      final me = await Api.getProfile(Api.uid);
      if (mounted) setState(() => _me = me);
    } catch (_) {
      // The avatar is cosmetic; posting works without it.
    }
  }

  // ----------------------------------------------------------------- media

  static const _noMix =
      'A post can have up to 4 photos or GIFs, or 1 video — not both.';

  Future<void> _pickImage({bool camera = false}) async {
    if (_video != null) {
      showInfo(context, 'Remove the video first to add photos or GIFs.');
      return;
    }
    final room = _maxMedia - _mediaCount;
    if (room <= 0) {
      showInfo(context, 'You can add up to 4 photos or GIFs.');
      return;
    }
    try {
      final List<PickedImage> picked;
      if (camera) {
        final one = await pickCameraImage();
        picked = one == null ? const [] : [one];
      } else {
        // Photos and videos from the gallery; tick as many pictures as fit
        // (up to 4 in total) in one go, or one video.
        final media = await pickGalleryMedia(room);
        if (!mounted) return;
        final video = media.video;
        if (video != null) {
          if (_mediaCount > 0) {
            showInfo(context, _noMix);
            return;
          }
          setState(() => _video = video);
          if (media.skipped) {
            showInfo(context, 'Only one video can be added to a post.');
          }
          return;
        }
        picked = media.images;
      }
      if (picked.isNotEmpty && mounted) {
        setState(() {
          _images = [..._images, ...picked].take(room + _images.length).toList();
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _chooseGif() async {
    if (_video != null) {
      showInfo(context, 'Remove the video first to add a GIF.');
      return;
    }
    if (_mediaCount >= _maxMedia) {
      showInfo(context, 'You can add up to 4 photos or GIFs.');
      return;
    }
    final url = await showGifPicker(context);
    if (url != null && mounted) {
      // Added next to the photos already chosen, not instead of them.
      setState(() {
        if (_mediaCount < _maxMedia) _gifUrls = [..._gifUrls, url];
      });
    }
  }

  // -------------------------------------------------------------------- AI

  Future<void> _openAi() async {
    final action =
        await showAiMenu(context, hasText: _text.text.trim().isNotEmpty);
    if (action == null || !mounted) return;
    if (action == AiAction.generateImage) {
      if (_video != null) {
        showInfo(context, 'Remove the video first to add a picture.');
        return;
      }
      if (_mediaCount >= _maxMedia) {
        showInfo(context, 'You can add up to 4 photos or GIFs.');
        return;
      }
      final img = await showGenerateImageDialog(context);
      if (img != null && mounted) {
        setState(() {
          // Keep the media already chosen (4 at most); the new one is added.
          if (_mediaCount < _maxMedia) _images = [..._images, img];
          _ai = true; // the picture is machine-made: say so
        });
      }
    } else {
      await _enhance();
    }
  }

  Future<void> _enhance() async {
    setState(() => _aiBusy = true);
    try {
      final out = await AiAssist.enhance(_text.text.trim());
      if (!mounted) return;
      _text.value = TextEditingValue(
        text: out,
        selection: TextSelection.collapsed(offset: out.length),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // -------------------------------------------------------------- schedule

  Future<void> _openSchedule() async {
    final r = await showScheduleDialog(context, initial: _scheduledAt);
    if (!mounted || r == null) return;
    if (r is DateTime) {
      setState(() => _scheduledAt = r);
    } else if (r == scheduleClear) {
      setState(() => _scheduledAt = null);
    } else if (r == scheduleView) {
      Navigator.of(context).push(appRoute(const ScheduledPostsScreen()));
    }
  }

  // ----------------------------------------------------------------- quote

  Future<void> _chooseQuote() async {
    final picked = await showQuotePicker(context);
    if (picked != null && mounted) setState(() => _quote = _quoteOf(picked));
  }

  // ------------------------------------------------------------------ poll

  void _togglePoll() {
    if (_hasPoll) {
      _removePoll();
      return;
    }
    setState(() {
      _pollFields = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
      _pollDays = 1;
      _pollHours = 0;
      _pollMins = 0;
      _lengthOpen = false;
    });
  }

  void _removePoll() {
    _retired.addAll(_pollFields);
    _retiredWheels.addAll(_pollWheels);
    _pollWheels = [];
    setState(() {
      _pollFields = [];
      _lengthOpen = false;
    });
  }

  void _addPollOption() {
    if (_pollFields.length >= 4) return;
    setState(() => _pollFields = [..._pollFields, TextEditingController()]);
  }

  /// X does not allow a poll shorter than 5 minutes.
  static const _minPoll = Duration(minutes: 5);

  Duration get _pollDuration {
    final d = Duration(days: _pollDays, hours: _pollHours, minutes: _pollMins);
    return d < _minPoll ? _minPoll : d;
  }

  String get _pollSummary {
    final d = _pollDuration;
    final parts = <String>[];
    if (d.inDays > 0) parts.add('${d.inDays} ${d.inDays == 1 ? 'day' : 'days'}');
    final h = d.inHours % 24;
    if (h > 0) parts.add('$h ${h == 1 ? 'hr' : 'hrs'}');
    final m = d.inMinutes % 60;
    if (m > 0) parts.add('$m min');
    return parts.join(' ');
  }

  /// After a wheel moved: a poll shorter than 5 minutes snaps back to 5.
  void _enforcePollMin() {
    final d = Duration(days: _pollDays, hours: _pollHours, minutes: _pollMins);
    if (d >= _minPoll) return;
    setState(() {
      _pollMins = 5;
    });
    if (_pollWheels.length == 3 && _pollWheels[2].hasClients) {
      _pollWheels[2].animateToItem(
        5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleLength() {
    if (_lengthOpen) {
      _retiredWheels.addAll(_pollWheels);
      setState(() {
        _pollWheels = [];
        _lengthOpen = false;
      });
      return;
    }
    setState(() {
      _pollWheels = [
        FixedExtentScrollController(initialItem: _pollDays),
        FixedExtentScrollController(initialItem: _pollHours),
        FixedExtentScrollController(initialItem: _pollMins),
      ];
      _lengthOpen = true;
    });
  }

  // -------------------------------------------------------------- location

  Future<void> _chooseLocation() async {
    final r = await showLocationPicker(context, current: _location);
    if (r == null || !mounted) return;
    setState(() => _location = r.isEmpty ? null : r);
  }

  // ----------------------------------------------------------- disclosures

  Future<void> _openDisclosures() async {
    final r = await showDisclosuresDialog(context, paid: _paid, ai: _ai);
    if (r == null || !mounted) return;
    setState(() {
      _paid = r.$1;
      _ai = r.$2;
    });
  }

  // ---------------------------------------------------------- reply scope

  void _chooseReplyScope() {
    final p = AppPalette.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
        ),
        child: CupertinoActionSheet(
          title: const Text('Who can reply?'),
          message: const Text(
            'Choose who can reply to this post. You can always reply to yourself.',
          ),
          actions: [
            for (final s in _replyScopes)
              CupertinoActionSheetAction(
                isDefaultAction: s.value == _replyScope,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _replyScope = s.value);
                },
                child: Text(s.label),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- thread

  void _addToThread() {
    final t = _text.text.trim();
    if (t.isEmpty) {
      showInfo(context, 'Write something before adding another post.');
      return;
    }
    if (_thread.length >= 24) {
      showInfo(context, 'A thread can have up to 25 posts.');
      return;
    }
    setState(() {
      _thread.add(t);
      _text.clear();
    });
    _undo.value = UndoHistoryValue.empty;
  }

  // -------------------------------------------------------------- audience

  Future<void> _pickAudience() async {
    List<Community> mine;
    try {
      mine = await Api.fetchCommunities(joinedOnly: true);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    // A value of '' means "Everyone" (my followers).
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Choose audience'),
        message: mine.isEmpty
            ? const Text('Join a Community to post in it.')
            : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Everyone'),
          ),
          for (final c in mine)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(c.id),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.isEmpty) {
        _communityId = null;
        _communityName = null;
      } else {
        _communityId = picked;
        _communityName = mine.firstWhere((c) => c.id == picked).name;
      }
    });
  }

  Widget _audienceChip(AppPalette p) {
    final inCommunity = _communityId != null;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickAudience,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inCommunity) ...[
                  Icon(CupertinoIcons.person_2_fill, size: 14, color: p.accent),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    inCommunity ? (_communityName ?? 'Community') : 'Everyone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_down, size: 12, color: p.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- submit

  /// A normal new post with some text can be kept as a draft. (Replies,
  /// quotes, polls and posts in a community are asked about differently.)
  bool get _canSaveDraft =>
      !_editing &&
      widget.replyTo == null &&
      _replyUser == null &&
      _communityId == null &&
      _quote == null &&
      !_hasPoll &&
      (_thread.isNotEmpty || _text.text.trim().isNotEmpty);

  Future<String?> _askDraft() {
    final p = AppPalette.of(context);
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        message: _hasMedia
            ? const Text('Photos, GIFs and videos are not kept in drafts.')
            : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: Text('Save draft', style: TextStyle(color: p.accent)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard post'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('cancel'),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _saveDraft() {
    final current = _text.text.trim();
    return Drafts.save(
      DraftPost(
        id: _draftId ?? Drafts.newId(),
        texts: [..._thread, if (current.isNotEmpty) current],
        savedAt: DateTime.now(),
        replyScope: _replyScope,
      ),
    );
  }

  Future<void> _openDrafts() async {
    final d = await Navigator.of(context)
        .push<DraftPost>(appRoute(const DraftsScreen()));
    if (d == null || !mounted || d.texts.isEmpty) return;
    setState(() {
      _thread
        ..clear()
        ..addAll(d.texts.sublist(0, d.texts.length - 1));
      _text.text = d.texts.last;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      _replyScope = d.replyScope;
      _draftId = d.id;
    });
    _undo.value = UndoHistoryValue.empty;
  }

  Future<void> _cancel() async {
    if (_busy) return;
    if (!_hasContent) {
      Navigator.of(context).pop();
      return;
    }
    if (_canSaveDraft) {
      final choice = await _askDraft();
      if (!mounted || choice == null || choice == 'cancel') return;
      if (choice == 'save') {
        try {
          await _saveDraft();
        } catch (e) {
          if (mounted) showError(context, e);
          return;
        }
        if (!mounted) return;
        showInfo(context, 'Draft saved');
      } else if (_draftId != null) {
        await Drafts.remove(_draftId!);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirm(
      context,
      title: _editing ? 'Discard changes?' : 'Discard post?',
      message: _editing
          ? "Your edit won't be saved."
          : "You'll lose what you've written.",
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------- mentions

  /// The letters after an "@" right before the cursor, or null.
  String? _mentionAt() {
    final sel = _text.selection;
    final text = _text.text;
    if (!sel.isValid || !sel.isCollapsed || sel.baseOffset > text.length) {
      return null;
    }
    final before = text.substring(0, sel.baseOffset);
    final m = RegExp(r'(?:^|\s)@(\w{0,15})$').firstMatch(before);
    return m?.group(1);
  }

  void _onTextChanged() {
    final q = _mentionAt();
    if (q == null) {
      _mentionTimer?.cancel();
      if (_mentionKey != null || _mentions.isNotEmpty) {
        setState(() {
          _mentionKey = null;
          _mentions = const [];
        });
      }
      return;
    }
    if (q == _mentionKey) return;
    _mentionKey = q;
    _mentionTimer?.cancel();
    _mentionTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final found = await Api.searchProfiles(q);
        if (!mounted || _mentionKey != q) return;
        final lower = q.toLowerCase();
        int rank(Profile x) =>
            x.username.toLowerCase().startsWith(lower) ? 0 : 1;
        found.sort((a, b) => rank(a).compareTo(rank(b)));
        setState(() => _mentions = found.take(4).toList());
      } catch (_) {
        // Suggestions are optional: stay quiet when the search fails.
      }
    });
  }

  void _pickMention(Profile who) {
    final text = _text.text;
    final end = _text.selection.baseOffset.clamp(0, text.length);
    final at = text.substring(0, end).lastIndexOf('@');
    if (at < 0) return;
    final insert = '@${who.username} ';
    _text.value = TextEditingValue(
      text: text.replaceRange(at, end, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    setState(() {
      _mentionKey = null;
      _mentions = const [];
    });
  }

  Widget _mentionList(AppPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Column(
        children: [
          for (final who in _mentions)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pickMention(who),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Avatar(
                      url: who.avatarUrl,
                      name: who.name,
                      size: 36,
                      square: Avatar.isSquare(who.verified),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NameWithBadge(
                            name: who.name,
                            verified: who.verified,
                            badgeSize: 15,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '@${who.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.subtext, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_editing) {
      FocusScope.of(context).unfocus();
      setState(() => _busy = true);
      try {
        final updated =
            await Api.updatePostContent(widget.editing!.id, _text.text);
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        showError(context, e);
      }
      return;
    }
    final current = _text.text.trim();
    final texts = [..._thread, if (current.isNotEmpty) current];
    if (texts.isEmpty) texts.add('');

    if (texts.first.isEmpty && !_hasMedia && _quote == null) {
      showInfo(context, 'Write something or add a photo first.');
      return;
    }
    if (current.length > AppConfig.maxPostLength) {
      showError(context, 'Posts can be at most ${AppConfig.maxPostLength} characters.');
      return;
    }

    final options = [
      for (final c in _pollFields)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (_hasPoll) {
      if (texts.first.isEmpty) {
        showInfo(context, 'Ask a question for your poll.');
        return;
      }
      if (options.length < 2) {
        showInfo(context, 'A poll needs at least two choices.');
        return;
      }
    }
    final when = _scheduledAt;
    if (when != null && !when.isAfter(DateTime.now())) {
      showError(context, 'Pick a scheduled time in the future.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    var sent = 0;
    String? previous;
    try {
      for (var i = 0; i < texts.length; i++) {
        final first = i == 0;
        previous = await Api.createPost(
          content: texts[i],
          images: first ? _images : const [],
          extraUrls: first ? _gifUrls : const [],
          video: first ? _video : null,
          parentId: first ? _parentId : previous,
          communityId: _communityId,
          replySetting: _replyScope,
          location: first ? _location : null,
          paidPartnership: first && _paid,
          madeWithAi: first && _ai,
          scheduledAt: when,
          quoteId: first ? _quote?.id : null,
          pollOptions: first ? options : const [],
          pollDuration: _pollDuration,
        );
        sent++;
      }
      if (!mounted) return;
      if (when != null) {
        showSuccess(context, 'Scheduled for ${formatScheduled(when)}');
      }
      if (_draftId != null) await Drafts.remove(_draftId!);
      if (!mounted) return;
      Navigator.of(context).pop(when == null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (sent > 0) {
        await notify(
          context,
          title: 'Only part of your thread was posted',
          message:
              '$sent of ${texts.length} posts were published. ${friendlyError(e)}',
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        showError(context, e);
      }
    }
  }

  // ----------------------------------------------------------------- build

  Widget _tool(
    Widget Function(Color) icon,
    VoidCallback onTap, {
    bool enabled = true,
    bool active = false,
  }) {
    final p = AppPalette.of(context);
    final color = enabled ? p.accent : p.accent.withValues(alpha: 0.35);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Container(
          width: 38,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.accent.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: icon(color),
        ),
      ),
    );
  }

  Widget _iconTool(IconData icon, VoidCallback onTap,
      {bool enabled = true, bool active = false}) {
    return _tool(
      (c) => Icon(icon, size: 22, color: c),
      onTap,
      enabled: enabled,
      active: active,
    );
  }

  Widget _gifTool(VoidCallback onTap, {bool enabled = true}) {
    return _tool(
      (c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.6),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'GIF',
          style: TextStyle(
            color: c,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
      onTap,
      enabled: enabled,
    );
  }

  Widget _removeDot(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xB3000000),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.xmark,
          size: 16,
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }

  Widget _gifBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    final p = AppPalette.of(context);

    final video = _video;
    if (video != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: VideoPoster(
          file: video.path,
          onRemove: () => setState(() => _video = null),
        ),
      );
    }

    // Photos first, then GIFs; one wide picture, or a row to scroll.
    final count = _mediaCount;

    Widget thumb(int i, {required double? width, required double height}) {
      final isPhoto = i < _images.length;
      final Widget picture;
      if (isPhoto) {
        picture = Image.memory(
          _images[i].bytes,
          width: width ?? double.infinity,
          height: height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } else {
        picture = CachedNetworkImage(
          imageUrl: _gifUrls[i - _images.length],
          width: width ?? double.infinity,
          height: height,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: p.surface,
            alignment: Alignment.center,
            child: const CupertinoActivityIndicator(),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            color: p.surface,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: Text(
              'This link couldn’t be loaded as an image.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 14),
            ),
          ),
        );
      }
      return Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: picture),
          Positioned(
            top: 8,
            right: 8,
            child: _removeDot(
              () => setState(() {
                if (isPhoto) {
                  _images = [..._images]..removeAt(i);
                } else {
                  _gifUrls = [..._gifUrls]..removeAt(i - _images.length);
                }
              }),
            ),
          ),
          if (!isPhoto || _images[i].extension == 'gif')
            Positioned(left: 8, bottom: 8, child: _gifBadge()),
        ],
      );
    }

    if (count == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: thumb(0, width: null, height: 240),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: count,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) => thumb(i, width: 150, height: 200),
        ),
      ),
    );
  }

  /// The post being replied to, with the thread line down to my avatar.
  Widget _parentBlock(AppPalette p) {
    final post = widget.replyTo!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Avatar(
                  url: post.avatarUrl,
                  name: post.authorName,
                  size: 40,
                  square: Avatar.isSquare(post.authorVerified),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: p.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: NameWithBadge(
                          name: post.authorName,
                          verified: post.authorVerified,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 2,
                        child: Text(
                          '@${post.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ),
                      Text(
                        ' · ${timeago.format(post.createdAt, locale: 'en_short')}',
                        maxLines: 1,
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                    ],
                  ),
                  if (post.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        post.content,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(color: p.subtext, fontSize: 15),
                        children: [
                          const TextSpan(text: 'Replying to '),
                          TextSpan(
                            text: '@${post.username}',
                            style: TextStyle(color: p.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Learn more" of the Protected reply banner.
  late final TapGestureRecognizer _protectedTap = TapGestureRecognizer()
    ..onTap = _explainProtectedReply;

  Future<void> _explainProtectedReply() {
    final who = _replyUser;
    return notify(
      context,
      title: 'Protected reply',
      message: 'Your posts are protected, so only your followers can see '
          'them, replies included. ${who == null ? 'The person you reply to' : '@$who'} '
          'will not see this reply or get a notification unless they follow '
          'you and you have accepted them. You can change this in Settings > '
          'Privacy and safety > Audience and tagging.',
    );
  }

  /// "They can't see your Protected reply." above the toolbar.
  Widget _protectedBanner(AppPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.lock_fill, size: 15, color: p.subtext),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: p.subtext, fontSize: 14),
                children: [
                  const TextSpan(
                    text: 'They can’t see your Protected reply. ',
                  ),
                  TextSpan(
                    text: 'Learn more',
                    style: TextStyle(color: p.accent),
                    recognizer: _protectedTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceField(AppPalette p, int i) {
    return CupertinoTextField(
      controller: _pollFields[i],
      placeholder: 'Choice ${i + 1}${i >= 2 ? ' (optional)' : ''}',
      maxLength: 25,
      onChanged: (_) => setState(() {}),
      cursorColor: p.accent,
      style: TextStyle(color: p.text, fontSize: 18),
      placeholderStyle: TextStyle(color: p.subtext, fontSize: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: p.background,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    final p = AppPalette.of(context);
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 40,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: p.field.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onSelectedItemChanged: onChanged,
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                i == selected ? '$i $unit' : '$i',
                style: TextStyle(
                  color: i == selected ? p.text : p.subtext,
                  fontSize: 19,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pollBuilder() {
    final p = AppPalette.of(context);
    final n = _pollFields.length;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
            child: Column(
              children: [
                for (var i = 0; i < n; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: _choiceField(p, i)),
                        SizedBox(
                          width: 44,
                          child: i == 0
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _removePoll,
                                  child: Center(
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: p.text,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(AppIcons.close,
                                          size: 14, color: p.background),
                                    ),
                                  ),
                                )
                              : (i == n - 1 && n < 4
                                  ? GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _addPollOption,
                                      child: Center(
                                        child: Icon(CupertinoIcons.add,
                                            size: 24, color: p.accent),
                                      ),
                                    )
                                  : null),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 0.5, color: p.border),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleLength,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Text(
                    'Poll length',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _pollSummary,
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _lengthOpen
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: p.text,
                  ),
                ],
              ),
            ),
          ),
          if (_lengthOpen && _pollWheels.length == 3) ...[
            Container(height: 0.5, color: p.border),
            SizedBox(
              height: 190,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _wheel(
                      controller: _pollWheels[0],
                      count: 8,
                      selected: _pollDays,
                      unit: _pollDays == 1 ? 'day' : 'days',
                      onChanged: (v) {
                        setState(() {
                          _pollDays = v;
                          if (v == 7) {
                            _pollHours = 0;
                            _pollMins = 0;
                          }
                        });
                        if (v == 7) {
                          if (_pollWheels[1].hasClients) _pollWheels[1].jumpToItem(0);
                          if (_pollWheels[2].hasClients) _pollWheels[2].jumpToItem(0);
                        }
                        _enforcePollMin();
                      },
                    ),
                    _wheel(
                      controller: _pollWheels[1],
                      count: 24,
                      selected: _pollHours,
                      unit: _pollHours == 1 ? 'hour' : 'hours',
                      onChanged: (v) {
                        setState(() {
                          _pollHours = _pollDays == 7 ? 0 : v;
                        });
                        _enforcePollMin();
                      },
                    ),
                    _wheel(
                      controller: _pollWheels[2],
                      count: 60,
                      selected: _pollMins,
                      unit: 'min',
                      onChanged: (v) {
                        setState(() {
                          _pollMins = _pollDays == 7 ? 0 : v;
                        });
                        _enforcePollMin();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _threadSoFar() {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _thread.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 1),
                  child: Text(
                    '${i + 1}/',
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _thread[i],
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 15),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _thread.removeAt(i)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(AppIcons.close, size: 15, color: p.subtext),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Pin + place name under the text field ("Arayat, Central Luzon").
  Widget _locationRow() {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _chooseLocation,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(CupertinoIcons.location_solid, size: 20, color: p.subtext),
            const SizedBox(width: 8),
            Container(width: 2, height: 22, color: p.text),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.subtext,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The grey "Scheduled · Today at 11:45 · Edit" bar above the toolbar.
  Widget _scheduleBar() {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: p.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(CupertinoIcons.calendar, size: 24, color: p.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  friendlyScheduled(_scheduledAt!),
                  style: TextStyle(color: p.subtext, fontSize: 16),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: p.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Edit',
                style: TextStyle(
                  color: p.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final replying = _replyUser != null;
    final canPost = _canPost;
    final scope = _replyScopes.firstWhere((s) => s.value == _replyScope);
    final scheduled = _scheduledAt != null;
    final hasPoll = _hasPoll;
    final hasQuote = _quote != null;
    final hasLocation = _location != null;
    final label = _busy
        ? (_editing
            ? 'Saving…'
            : (_video != null ? 'Uploading…' : 'Posting…'))
        : _editing
            ? 'Save'
            : scheduled
            ? 'Schedule'
            : 'Post';

    final placeholder = _thread.isNotEmpty
        ? 'Add another post'
        : hasQuote
            ? 'Add a comment'
            : hasPoll
                ? 'Ask a question…'
                : replying
                    ? 'Post your reply'
                    : 'What’s happening?';

    return PopScope(
      canPop: !_hasContent || _busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AdaptiveScaffold(
        backgroundColor: p.background,
        body: DefaultTextStyle(
          style: TextStyle(
            color: p.text,
            fontSize: 15,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
          child: SafeArea(
            child: ContentWidth(
              child: Column(
                children: [
                  // Cancel ......................................... [Post]
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cancel,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: p.text, fontSize: 16),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!_editing &&
                            !replying &&
                            widget.quoting == null &&
                            !_hasContent &&
                            Drafts.all().isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openDrafts,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Text(
                                'Drafts',
                                style: TextStyle(
                                  color: p.accent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: canPost ? _submit : null,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: canPost
                                  ? p.accent
                                  : p.accent.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.replyTo != null) _parentBlock(p),
                          Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Avatar(
                            url: _me?.avatarUrl,
                            name: _me?.name ?? '',
                            size: 40,
                            square: Avatar.isSquare(_me?.verified),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (replying && widget.replyTo == null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 2, bottom: 4),
                                    child: Text.rich(
                                      TextSpan(
                                        style: TextStyle(
                                          color: p.subtext,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Replying to '),
                                          TextSpan(
                                            text: '@$_replyUser',
                                            style: TextStyle(color: p.accent),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (!_editing && !replying && widget.quoting == null)
                                  _audienceChip(p),
                                if (_thread.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  _threadSoFar(),
                                ],
                                CupertinoTextField(
                                  controller: _text,
                                  undoController: _undo,
                                  placeholder: placeholder,
                                  autofocus: true,
                                  minLines: hasPoll || hasQuote ? 1 : 3,
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  cursorColor: p.accent,
                                  decoration: null,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  style: TextStyle(color: p.text, fontSize: 20),
                                  placeholderStyle:
                                      TextStyle(color: p.subtext, fontSize: 20),
                                  onChanged: (_) => setState(() {}),
                                ),
                                if (hasLocation) _locationRow(),
                                if (_hasMedia) _mediaPreview(),
                                if (hasPoll) _pollBuilder(),
                                if (hasQuote)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: QuoteCard(
                                      quote: _quote!,
                                      onRemove: () =>
                                          setState(() => _quote = null),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
                    ),
                  ),
                  if (_mentions.isNotEmpty) _mentionList(p),
                  if (scheduled) _scheduleBar(),
                  if (_protectedReply) _protectedBanner(p),
                  // 🌐 Everyone can reply ........................ ↶  ↷
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: p.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: replying || _editing
                              ? const SizedBox(height: 44)
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _chooseReplyScope,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.globe,
                                          size: 17,
                                          color: p.accent,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            scope.sentence,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: p.accent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        ValueListenableBuilder<UndoHistoryValue>(
                          valueListenable: _undo,
                          builder: (context, v, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: v.canUndo ? _undo.undo : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    CupertinoIcons.arrow_uturn_left,
                                    size: 20,
                                    color: v.canUndo
                                        ? p.accent
                                        : p.subtext.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: v.canRedo ? _undo.redo : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    CupertinoIcons.arrow_uturn_right,
                                    size: 20,
                                    color: v.canRedo
                                        ? p.accent
                                        : p.subtext.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toolbar: media tools ........................ ◯ | ⊕
                  Container(
                    padding: const EdgeInsets.fromLTRB(7, 0, 14, 4),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: p.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _editing
                              ? const SizedBox(height: 44)
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _iconTool(
                                  CupertinoIcons.photo,
                                  _pickImage,
                                  enabled: !hasPoll,
                                ),
                                _iconTool(
                                  CupertinoIcons.camera,
                                  () => _pickImage(camera: true),
                                  enabled: !hasPoll,
                                ),
                                _tool(
                                  (c) => _aiBusy
                                      ? const CupertinoActivityIndicator(radius: 9)
                                      : AiGlyph(color: c),
                                  _openAi,
                                  enabled: !hasPoll && !_aiBusy,
                                ),
                                _gifTool(_chooseGif, enabled: !hasPoll),
                                _iconTool(
                                  CupertinoIcons.calendar,
                                  _openSchedule,
                                  enabled: !hasPoll && !hasLocation,
                                  active: scheduled,
                                ),
                                if (!hasPoll && !hasQuote && !replying)
                                  _iconTool(
                                    CupertinoIcons.quote_bubble,
                                    _chooseQuote,
                                  ),
                                _iconTool(
                                  CupertinoIcons.list_bullet,
                                  _togglePoll,
                                  enabled: hasPoll ||
                                      (!scheduled && !hasQuote && !_hasMedia),
                                  active: hasPoll,
                                ),
                                _iconTool(
                                  hasLocation
                                      ? CupertinoIcons.location_solid
                                      : CupertinoIcons.location,
                                  _chooseLocation,
                                  enabled: hasLocation || (!scheduled && !hasQuote),
                                ),
                                _iconTool(
                                  (_paid || _ai)
                                      ? CupertinoIcons.flag_fill
                                      : CupertinoIcons.flag,
                                  _openDisclosures,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CounterRing(
                          used: _text.text.length,
                          max: AppConfig.maxPostLength,
                        ),
                        if (!_editing)
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: p.border,
                        ),
                        if (!_editing)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _addToThread,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _text.text.trim().isEmpty
                                  ? p.accent.withValues(alpha: 0.35)
                                  : p.accent,
                            ),
                            child: const Icon(
                              CupertinoIcons.add,
                              size: 16,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular character counter: a ring that fills as you type; the remaining
/// number appears in the last 20 characters and turns red past the limit.
class _CounterRing extends StatelessWidget {
  const _CounterRing({required this.used, required this.max});

  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final remaining = max - used;
    final over = remaining < 0;
    final warn = remaining <= 20;
    final color = over
        ? p.danger
        : (warn ? const Color(0xFFFFD400) : p.accent);

    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _RingPainter(
          progress: (used / max).clamp(0.0, 1.0),
          color: color,
          track: p.border,
        ),
        child: warn
            ? Center(
                child: Text(
                  '$remaining',
                  style: TextStyle(
                    color: over ? p.danger : p.subtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.5;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
