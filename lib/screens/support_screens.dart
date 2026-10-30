import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/app_text_field.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import '../widgets/state_views.dart';
import 'privacy_screens.dart';

String _day(DateTime t) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${m[t.month - 1]} ${t.day}, ${t.year}';
}

/// One request in a list: subject, message, status and the team's reply.
Widget _ticketTile(AppPalette p, SupportTicket t) {
  final color = switch (t.status) {
    'resolved' => const Color(0xFF00BA7C),
    'rejected' => p.danger,
    _ => p.subtext,
  };
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: p.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.subject.isEmpty ? 'Request' : t.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              t.statusLabel,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t.message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.text, fontSize: 14, height: 1.3),
        ),
        const SizedBox(height: 6),
        Text(
          _day(t.createdAt),
          style: TextStyle(color: p.subtext, fontSize: 12),
        ),
        if ((t.reply ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Reply: ${t.reply}',
              style: TextStyle(color: p.text, fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Contact us / Report a problem
// ---------------------------------------------------------------------------

/// A message to the team, saved in the `support_tickets` table. The person
/// sees the status and the reply under the form.
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key, this.problem = false});

  /// true = "Report a problem" (a different list of topics, kind `problem`).
  final bool problem;

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _message = TextEditingController();
  late String _topic = _topics.first;
  List<SupportTicket> _tickets = const [];
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  String get _kind => widget.problem ? 'problem' : 'contact';

  List<String> get _topics => widget.problem
      ? const ['Something is not working', 'Looks wrong', 'Slow or crashing', 'Other']
      : const [
          'General question',
          'Account or login',
          'Privacy or safety',
          'Feedback',
        ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      final list = await Api.fetchTickets(kinds: [_kind]);
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write your message first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.submitTicket(kind: _kind, subject: _topic, message: text);
      if (!mounted) return;
      _message.clear();
      setState(() => _busy = false);
      showSuccess(context, 'Sent. Thank you!');
      _loadTickets();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: widget.problem ? 'Report a problem' : 'Contact us',
      child: FormBody(
        bottom: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: PillAction(
            label: 'Send',
            kind: PillKind.blue,
            fullWidth: true,
            busy: _busy,
            onPressed: _busy ? null : _send,
          ),
        ),
        children: [
          const SizedBox(height: 14),
          Text(
            widget.problem
                ? 'Tell us what went wrong. The more detail, the easier it is '
                    'to fix.'
                : 'Questions or feedback about ${AppConfig.appName}? Write to '
                    'us and we will reply here.',
            style: TextStyle(color: p.subtext, fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 8),
          ValueRow(
            title: 'Topic',
            value: _topic,
            onTap: () async {
              final v = await pickOption<String>(
                context,
                title: 'Topic',
                selected: _topic,
                items: [for (final t in _topics) PickItem(t, t)],
              );
              if (v != null) setState(() => _topic = v);
            },
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _message,
            placeholder: 'Your message',
            minLines: 5,
            maxLines: 10,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: p.danger, fontSize: 14),
              ),
            ),
          const SizedBox(height: 22),
          Text(
            'Your requests',
            style: TextStyle(
              color: p.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_tickets.isEmpty)
            Text(
              'Nothing sent yet.',
              style: TextStyle(color: p.subtext, fontSize: 15),
            )
          else
            for (final t in _tickets) _ticketTile(p, t),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy policy / Privacy center
// ---------------------------------------------------------------------------

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'About this app',
      '${AppConfig.appName} is a school project that copies how X works. It '
          'is not X and is not connected to X Corp. or any social network.',
    ),
    (
      'What we keep',
      'Your email address, username, name, bio and pictures; the posts, '
          'replies, likes, reposts, bookmarks and follows you make; your '
          'direct and group messages; your Notes; the settings you choose; '
          'and the devices that are signed in to your account.',
    ),
    (
      'Where it is kept',
      'Everything is stored in a Supabase (PostgreSQL) project that belongs '
          'to the team. Row level security makes sure you can only read '
          'your own messages, settings and requests. Passwords are handled by '
          'Supabase Auth and are never visible to the team.',
    ),
    (
      'Location and permissions',
      'Your position is only read when you tap "Add location" in a post, and '
          'only the place name you pick is saved. Photos, camera and '
          'microphone are used only when you choose to add media or use '
          'voice in Grok.',
    ),
    (
      'Outside services',
      'GIF search is sent to GIPHY. Grok questions you type or say are sent '
          'to the AI provider the team connected, through a server function, '
          'so no key is stored in the app. There are no ads and nothing is '
          'sold.',
    ),
    (
      'Your choices',
      'Protect your posts, control who can message or tag you, mute and '
          'block accounts, and change your settings any time in Settings and '
          'privacy. You can download an archive of your data, deactivate or '
          'delete your account, and write to us with Contact us.',
    ),
    (
      'Messages you delete',
      '"Delete conversation" hides the messages for you only. The other '
          'person keeps their copy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Privacy policy',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          for (final s in _sections)
            SettingsColumn(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.$1,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.$2,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Text(
                'Last updated: October 2026',
                style: TextStyle(color: p.subtext, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key});

  void _open(BuildContext c, Widget page) =>
      Navigator.of(c).push(appRoute(page));

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Privacy center',
      items: [
        const PIntro(
          'Everything about your privacy in one place: what we keep, what you '
          'can control and how to reach us.',
        ),
        PNav(
          'Privacy policy',
          desc: 'What the app keeps and why.',
          open: (c) => _open(c, const PrivacyPolicyScreen()),
        ),
        PNav(
          'Audience and tagging',
          desc: 'Protect your posts and choose who can tag you.',
          open: (c) => _open(c, const AudienceTaggingScreen()),
        ),
        PNav(
          'Mute and block',
          desc: 'Accounts, words and notifications you don’t want to see.',
          open: (c) => _open(c, const MuteBlockScreen()),
        ),
        PNav(
          'Download an archive of your data',
          desc: 'A copy of what is stored for your account.',
          open: (c) => _open(c, const DataArchiveScreen()),
        ),
        PNav(
          'Contact us',
          desc: 'Ask a question about your privacy.',
          open: (c) => _open(c, const ContactUsScreen()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Download an archive of your data
// ---------------------------------------------------------------------------

class DataArchiveScreen extends StatefulWidget {
  const DataArchiveScreen({super.key});

  @override
  State<DataArchiveScreen> createState() => _DataArchiveScreenState();
}

class _DataArchiveScreenState extends State<DataArchiveScreen> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  Object? _error;

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await Api.exportMyData();
      if (!mounted) return;
      setState(() {
        _data = d;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  int _count(String key) {
    final v = _data?[key];
    return v is List ? v.length : 0;
  }

  Future<void> _copy() async {
    final d = _data;
    if (d == null) return;
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(d)),
    );
    if (mounted) {
      showSuccess(context, 'Archive copied. Paste it into a file to keep it.');
    }
  }

  Widget _line(AppPalette p, String label, int n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: p.text, fontSize: 16)),
          ),
          Text(
            '$n',
            style: TextStyle(
              color: p.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = _data;
    return SettingsFrame(
      title: 'Your data',
      child: FormBody(
        bottom: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: d == null
              ? PillAction(
                  label: 'Request archive',
                  kind: PillKind.blue,
                  fullWidth: true,
                  busy: _busy,
                  onPressed: _busy ? null : _request,
                )
              : PillAction(
                  label: 'Copy archive (JSON)',
                  kind: PillKind.blue,
                  fullWidth: true,
                  onPressed: _copy,
                ),
        ),
        children: [
          const SizedBox(height: 14),
          Text(
            'Get a copy of what ${AppConfig.appName} stores for your account: '
            'profile, posts, likes, bookmarks, follows, messages you sent, '
            'your settings and your requests to the team.',
            style: TextStyle(color: p.subtext, fontSize: 16, height: 1.35),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                friendlyError(_error!),
                style: TextStyle(color: p.danger, fontSize: 15),
              ),
            ),
          if (d != null) ...[
            const SizedBox(height: 20),
            Text(
              'Your archive is ready',
              style: TextStyle(
                color: p.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _line(p, 'Posts and replies', _count('posts')),
            _line(p, 'Likes', _count('likes')),
            _line(p, 'Bookmarks', _count('bookmarks')),
            _line(p, 'Reposts', _count('reposts')),
            _line(p, 'Accounts you follow', _count('following')),
            _line(p, 'Direct messages sent', _count('messages_sent')),
            _line(p, 'Group messages sent', _count('group_messages_sent')),
            _line(p, 'Requests to the team', _count('support_requests')),
            const SizedBox(height: 10),
            Text(
              'Tap the button to copy everything as JSON.',
              style: TextStyle(color: p.subtext, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ID verification
// ---------------------------------------------------------------------------

/// Asks the team to verify the account. Nothing sensitive is collected: no ID
/// number and no photo of the ID, only the name and the kind of ID the
/// person can show if the team asks.
class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  String _idType = 'School ID';
  SupportTicket? _latest;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  static const _types = [
    'School ID',
    'Government ID',
    'Passport',
    'Driver’s license',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await Api.fetchTickets(kinds: ['verification']);
      if (!mounted) return;
      setState(() {
        _latest = list.isEmpty ? null : list.first;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Enter your full name as on the ID.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      await Api.submitTicket(
        kind: 'verification',
        subject: 'ID verification',
        message: 'Name on ID: $name\nID type: $_idType'
            '${note.isEmpty ? '' : '\nNote: $note'}',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      showSuccess(context, 'Request sent. We will review it.');
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final latest = _latest;
    final waiting = latest?.isWaiting ?? false;

    return SettingsFrame(
      title: 'ID verification',
      child: _loading
          ? const LoadingView()
          : FormBody(
              bottom: waiting
                  ? null
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        8,
                        0,
                        16 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: PillAction(
                        label: 'Send request',
                        kind: PillKind.blue,
                        fullWidth: true,
                        busy: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                    ),
              children: [
                const SizedBox(height: 14),
                Text(
                  'Ask the team to confirm you are a real person. We do not '
                  'ask for your ID number or a photo of it here; the team '
                  'will contact you if more is needed.',
                  style: TextStyle(color: p.subtext, fontSize: 16, height: 1.35),
                ),
                if (latest != null) ...[
                  const SizedBox(height: 16),
                  _ticketTile(p, latest),
                ],
                if (!waiting) ...[
                  const SizedBox(height: 8),
                  UnderlineField(
                    placeholder: 'Full name (as on the ID)',
                    controller: _name,
                    maxLength: 60,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  ValueRow(
                    title: 'Kind of ID',
                    value: _idType,
                    onTap: () async {
                      final v = await pickOption<String>(
                        context,
                        title: 'Kind of ID',
                        selected: _idType,
                        items: [for (final t in _types) PickItem(t, t)],
                      );
                      if (v != null) setState(() => _idType = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _note,
                    placeholder: 'Anything we should know? (optional)',
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(color: p.danger, fontSize: 14),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
