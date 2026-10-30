import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/responsive.dart';
import 'onboarding_kit.dart' show BlackButton, OutlineChip;

/// Topics a community can belong to (also the chips on Communities → Explore).
const List<String> communityCategories = [
  'Sports',
  'Technology',
  'Art',
  'Entertainment',
  'Gaming',
  'Politics',
  'Business',
  'Music',
  'Food',
  'Travel',
  'General',
];

class _RuleDraft {
  _RuleDraft([String title = '', String description = ''])
      : title = TextEditingController(text: title),
        description = TextEditingController(text: description);

  final TextEditingController title;
  final TextEditingController description;

  void dispose() {
    title.dispose();
    description.dispose();
  }
}

/// Start a new community (cover, name, description, topic, who can join and
/// 1-10 rules), or edit one when [existing] is given (admin only). Pops with
/// the community's id.
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key, this.existing});

  final Community? existing;

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.category ?? 'General';
  late String _policy = widget.existing?.joinPolicy ?? 'open';
  final List<_RuleDraft> _rules = [];
  PickedImage? _cover;
  bool _busy = false;
  bool _loadingRules = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loadingRules = true;
      _loadRules();
    } else {
      _rules.add(_RuleDraft());
    }
  }

  Future<void> _loadRules() async {
    try {
      final rules = await Api.fetchCommunityRules(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        for (final r in rules) {
          _rules.add(_RuleDraft(r.title, r.description));
        }
        if (_rules.isEmpty) _rules.add(_RuleDraft());
        _loadingRules = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rules.add(_RuleDraft());
        _loadingRules = false;
      });
      showError(context, e);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    for (final r in _rules) {
      r.dispose();
    }
    super.dispose();
  }

  List<CommunityRule> get _filledRules => [
        for (final r in _rules)
          if (r.title.text.trim().isNotEmpty)
            CommunityRule(
              title: r.title.text.trim(),
              description: r.description.text.trim(),
            ),
      ];

  bool get _valid =>
      _name.text.trim().isNotEmpty && _filledRules.isNotEmpty && !_loadingRules;

  Future<void> _pickCover() async {
    try {
      final img = await pickGalleryImage();
      if (img != null && mounted) setState(() => _cover = img);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    try {
      final String id;
      final existing = widget.existing;
      if (existing == null) {
        id = await Api.createCommunity(
          name: _name.text,
          description: _desc.text,
          category: _category,
          joinPolicy: _policy,
          cover: _cover,
          rules: _filledRules,
        );
      } else {
        await Api.updateCommunity(
          existing.id,
          name: _name.text,
          description: _desc.text,
          category: _category,
          joinPolicy: _policy,
          newCover: _cover,
          rules: _filledRules,
        );
        id = existing.id;
      }
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  // ------------------------------------------------------------------ UI

  Widget _label(AppPalette p, String text, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: p.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(hint, style: TextStyle(color: p.subtext, fontSize: 14)),
              ),
          ],
        ),
      );

  Widget _field(
    AppPalette p,
    TextEditingController c,
    String hint, {
    int maxLength = 50,
    int lines = 1,
    double size = 18,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: CupertinoTextField(
        controller: c,
        placeholder: hint,
        maxLength: maxLength,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 5,
        onChanged: (_) => setState(() {}),
        cursorColor: p.accent,
        padding: EdgeInsets.zero,
        decoration: const BoxDecoration(),
        style: TextStyle(color: p.text, fontSize: size),
        placeholderStyle: TextStyle(color: p.subtext, fontSize: size),
      ),
    );
  }

  Widget _coverPicker(AppPalette p) {
    final cover = _cover;
    final url = widget.existing?.banner;
    Widget image;
    if (cover != null) {
      image = Image.memory(cover.bytes, fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      image = CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
    } else {
      image = ColoredBox(color: p.field);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickCover,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 150,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.camera,
                          size: 18, color: Color(0xFFFFFFFF)),
                      const SizedBox(width: 8),
                      Text(
                        cover != null || (url != null && url.isNotEmpty)
                            ? 'Change cover photo'
                            : 'Add cover photo',
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _policyOption(
    AppPalette p, {
    required String value,
    required String title,
    required String subtitle,
  }) {
    final on = _policy == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _policy = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: p.subtext, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? p.accent : p.subtext,
                  width: on ? 7 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleEditor(AppPalette p, int i) {
    final r = _rules[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Rule ${i + 1}',
                style: TextStyle(
                  color: p.subtext,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_rules.length > 1)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _rules.removeAt(i).dispose()),
                  child: Icon(CupertinoIcons.trash, size: 18, color: p.subtext),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _field(p, r.title, 'Rule title (e.g. Be respectful)',
              maxLength: 100, size: 16),
          const SizedBox(height: 10),
          _field(p, r.description, 'Explain the rule (optional)',
              maxLength: 500, lines: 2, size: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: AdaptiveAppBar(
        title: _editing ? 'Edit Community' : 'Create a Community',
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _coverPicker(p),
              const SizedBox(height: 22),
              _label(p, 'Name'),
              _field(p, _name, 'Name your Community'),
              const SizedBox(height: 22),
              _label(p, 'Description'),
              _field(p, _desc, 'What is it about?', maxLength: 200, lines: 3),
              const SizedBox(height: 24),
              _label(p, 'Topic'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in communityCategories)
                    OutlineChip(
                      label: c,
                      compact: true,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              _label(p, 'Who can join'),
              _policyOption(
                p,
                value: 'open',
                title: 'Open',
                subtitle: 'Anyone can join after agreeing to the rules.',
              ),
              _policyOption(
                p,
                value: 'request',
                title: 'Ask to join',
                subtitle: 'People send a request and moderators approve it.',
              ),
              const SizedBox(height: 22),
              _label(
                p,
                'Rules',
                hint: 'A Community needs at least 1 rule, up to 10. Members '
                    'agree to them before they join.',
              ),
              const SizedBox(height: 6),
              if (_loadingRules)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else ...[
                for (var i = 0; i < _rules.length; i++) _ruleEditor(p, i),
                if (_rules.length < 10)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _rules.add(_RuleDraft())),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.add_circled,
                              size: 22, color: p.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Add a rule',
                            style: TextStyle(
                              color: p.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              BlackButton(
                label: _editing ? 'Save' : 'Create',
                busy: _busy,
                onPressed: _valid ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
