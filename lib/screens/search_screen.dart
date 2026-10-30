import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/user_prefs.dart';
import '../widgets/person_tile.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/underline_tabs.dart';
import 'profile_view.dart';
import '../core/x_icons.dart';

/// Full-screen search: a back arrow, a search box and People / Posts tabs.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery);
  Timer? _debounce;

  int _tab = 0; // 0 = People, 1 = Posts
  List<Profile> _people = const [];
  List<Post> _posts = const [];
  bool _loading = false;
  Object? _error;
  int _token = 0;

  static const String _recentKey = 'recent_searches';
  List<String> _recent = UserPrefs.instance.strings(_recentKey);

  @override
  void initState() {
    super.initState();
    // A hashtag opens on the Posts tab.
    if (widget.initialQuery.startsWith('#')) _tab = 1;
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  /// Remembers what was searched (newest first, at most 10).
  Future<void> _remember(String q) async {
    final next = [q, ..._recent.where((x) => x.toLowerCase() != q.toLowerCase())]
        .take(10)
        .toList();
    setState(() => _recent = next);
    await UserPrefs.instance.set(_recentKey, next);
  }

  Future<void> _forget(String? q) async {
    final next = q == null ? <String>[] : _recent.where((x) => x != q).toList();
    setState(() => _recent = next);
    await UserPrefs.instance.set(_recentKey, next.isEmpty ? null : next);
  }

  void _useRecent(String q) {
    _query.text = q;
    _query.selection = TextSelection.collapsed(offset: q.length);
    if (q.startsWith('#')) _tab = 1;
    _search();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    final token = ++_token;
    if (q.isEmpty) {
      setState(() {
        _people = const [];
        _posts = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait<Object>([
        Api.searchProfiles(q.startsWith('@') ? q.substring(1) : q),
        Api.searchPosts(q),
      ]);
      if (!mounted || token != _token) return;
      setState(() {
        _people = r[0] as List<Profile>;
        _posts = r[1] as List<Post>;
        _loading = false;
      });

    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _toggleFollow(Profile profile) async {
    final i = _people.indexWhere((x) => x.id == profile.id);
    if (i < 0) return;
    final updated = profile.afterFollowTap();
    setState(() => _people = [..._people]..[i] = updated);
    try {
      await Api.setFollow(
        profile.id,
        follow: updated.followedByMe || updated.requestedByMe,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _people = [..._people]..[i] = profile);
      showError(context, e);
    }
  }

  Widget _recentList(AppPalette p) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _forget(null),
                child: Text(
                  'Clear all',
                  style: TextStyle(color: p.accent, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        for (final q in _recent)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _useRecent(q),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  XIcon(XIcons.search, size: 20, color: p.subtext),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 16),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _forget(q),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(AppIcons.close, size: 18, color: p.subtext),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _results(AppPalette p) {
    if (_query.text.trim().isEmpty) {
      if (_recent.isNotEmpty) return _recentList(p);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Try searching for people, topics or hashtags',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        ),
      );
    }
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _search);

    if (_tab == 0) {
      if (_people.isEmpty) {
        return EmptyState(
          icon: AppIcons.people,
          title: 'No people found',
          subtitle: 'Try a different name or username.',
        );
      }
      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 60),
        itemCount: _people.length,
        itemBuilder: (context, i) {
          final profile = _people[i];
          return PersonTile(
            profile: profile,
            onTap: () {
              final q = _query.text.trim();
              if (q.length >= 2) _remember(q);
              Navigator.of(context)
                  .push(appRoute(ProfileScreen(userId: profile.id)));
            },
            onToggleFollow:
                profile.id == Api.uid ? null : () => _toggleFollow(profile),
          );
        },
      );
    }

    if (_posts.isEmpty) {
      return EmptyState(
        icon: CupertinoIcons.search,
        title: 'No posts found',
        subtitle: 'Try a different word or hashtag.',
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 60),
      itemCount: _posts.length,
      itemBuilder: (context, i) => PostTile(
        key: ValueKey(_posts[i].id),
        post: _posts[i],
        onDeleted: (x) => setState(
          () => _posts = _posts.where((y) => y.id != x.id).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PlainScaffold(
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(AppIcons.back, size: 22, color: p.text),
                    ),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _query,
                        autofocus: widget.initialQuery.isEmpty,
                        placeholder: 'Search',
                        autocorrect: false,
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        onSubmitted: (_) {
                          _search();
                          final q = _query.text.trim();
                          if (q.length >= 2) _remember(q);
                        },
                        cursorColor: p.accent,
                        clearButtonMode: OverlayVisibilityMode.editing,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: XIcon(XIcons.search, size: 18, color: p.subtext),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: p.field,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        style: TextStyle(color: p.text, fontSize: 16),
                        placeholderStyle:
                            TextStyle(color: p.subtext, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              UnderlineTabs(
                labels: const ['People', 'Posts'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(child: _results(p)),
            ],
          ),
        ),
      ),
    );
  }
}
