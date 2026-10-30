import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/avatar.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';

/// "Create your List": step 1 is the banner, name, description and Private
/// switch; step 2 adds people. Pops with the new list's id.
class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  PickedImage? _banner;
  bool _private = false;
  bool _busy = false;
  String? _listId; // set once step 1 is saved

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    try {
      final img = await pickGalleryImage();
      if (img != null && mounted) setState(() => _banner = img);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await Api.createList(
        name: _name.text,
        description: _desc.text,
        isPrivate: _private,
        banner: _banner,
      );
      if (mounted) {
        setState(() {
          _listId = id;
          _busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Widget _topBar(AppPalette p, {required bool step2}) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step2 ? 'Add to your List' : 'Create your List',
                style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                step2 ? 'Step 2 of 2' : 'Step 1 of 2',
                style: TextStyle(color: p.subtext, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              if (!step2)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Cancel', style: TextStyle(color: p.text, fontSize: 17)),
                  ),
                ),
              const Spacer(),
              if (step2)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(_listId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(AppPalette p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          t,
          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      );

  Widget _input(AppPalette p, TextEditingController c, String hint,
      {int maxLength = 25, int lines = 1}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: CupertinoTextField(
        controller: c,
        placeholder: hint,
        maxLength: maxLength,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 4,
        onChanged: (_) => setState(() {}),
        cursorColor: p.accent,
        padding: EdgeInsets.zero,
        decoration: const BoxDecoration(),
        style: TextStyle(color: p.text, fontSize: 19),
        placeholderStyle: TextStyle(color: p.subtext, fontSize: 19),
      ),
    );
  }

  Widget _step1(AppPalette p) {
    final banner = _banner;
    final canCreate = _name.text.trim().isNotEmpty && !_busy;
    return Column(
      children: [
        _topBar(p, step2: false),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickBanner,
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: banner != null
                      ? Image.memory(banner.bytes, fit: BoxFit.cover)
                      : ColoredBox(
                          color: const Color(0xFFB2B2B2),
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCFD9DE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.add,
                                size: 28,
                                color: Color(0xFF536471),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              _label(p, 'Name'),
              _input(p, _name, 'Enter a name'),
              _label(p, 'Description'),
              _input(p, _desc, 'Enter a brief description',
                  maxLength: 100, lines: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private',
                            style: TextStyle(
                              color: p.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'When you make a List private, only you can see it.',
                            style: TextStyle(color: p.subtext, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: _private,
                      activeTrackColor: p.accent,
                      onChanged: (v) => setState(() => _private = v),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: p.border),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Align(
            alignment: Alignment.centerRight,
            child: _busy
                ? const CupertinoActivityIndicator()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canCreate ? _create : null,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: canCreate ? p.text : const Color(0xFF8E9296),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        'Create',
                        style: TextStyle(
                          color: canCreate ? p.background : const Color(0xFFD0D3D6),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final id = _listId;
    return PopScope(
      canPop: id == null,
      child: PlainScaffold(
        child: SafeArea(
          child: ContentWidth(
            child: id == null
                ? _step1(p)
                : Column(
                    children: [
                      _topBar(p, step2: true),
                      Expanded(child: ListMembersEditor(listId: id)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Search people and add / remove them from one of my lists.
class ListMembersEditor extends StatefulWidget {
  const ListMembersEditor({super.key, required this.listId});

  final String listId;

  @override
  State<ListMembersEditor> createState() => _ListMembersEditorState();
}

class _ListMembersEditorState extends State<ListMembersEditor> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Profile> _people = const [];
  Set<String> _members = {};
  bool _loading = true;
  Object? _error;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final current = await Api.fetchListMembers(widget.listId);
      _members = current.map((x) => x.id).toSet();
      await _search();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    final token = ++_token;
    try {
      final List<Profile> found;
      if (q.isEmpty) {
        final s = await Api.suggestedProfiles(limit: 30);
        found = s.map((x) => x.profile).toList();
      } else {
        found = await Api.searchProfiles(q.startsWith('@') ? q.substring(1) : q);
      }
      if (!mounted || token != _token) return;
      setState(() {
        _people = found;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _toggle(Profile profile) async {
    final add = !_members.contains(profile.id);
    setState(() {
      if (add) {
        _members = {..._members, profile.id};
      } else {
        _members = _members.where((x) => x != profile.id).toSet();
      }
    });
    try {
      await Api.setListMember(widget.listId, profile.id, add: add);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (add) {
          _members = _members.where((x) => x != profile.id).toSet();
        } else {
          _members = {..._members, profile.id};
        }
      });
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: CupertinoTextField(
            controller: _query,
            placeholder: 'Search people',
            autocorrect: false,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _search);
            },
            cursorColor: p.accent,
            clearButtonMode: OverlayVisibilityMode.editing,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(CupertinoIcons.search, size: 18, color: p.subtext),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(22),
            ),
            style: TextStyle(color: p.text, fontSize: 17),
            placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(error: _error!, onRetry: _init)
                  : _people.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No people found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.subtext, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _people.length,
                          itemBuilder: (context, i) {
                            final person = _people[i];
                            final added = _members.contains(person.id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Avatar(
                                    url: person.avatarUrl,
                                    name: person.name,
                                    size: 46,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: p.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '@${person.username}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: p.subtext, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PillButton(
                                    label: added ? 'Added' : 'Add',
                                    style: added ? PillStyle.outline : PillStyle.inverse,
                                    height: 34,
                                    onPressed: () => _toggle(person),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
