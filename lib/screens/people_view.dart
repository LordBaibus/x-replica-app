import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/person_tile.dart';
import '../widgets/search_pill.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/top_bar.dart';
import 'profile_view.dart';

/// Search for people and follow / unfollow them.
/// With [onPick] set it becomes a picker (used for "New message").
class PeopleView extends StatefulWidget {
  const PeopleView({super.key, this.onPick, this.me, this.onOpenDrawer});

  final void Function(Profile profile)? onPick;

  /// Signed-in user and drawer opener, for the X-style header (tab mode only).
  final Profile? me;
  final VoidCallback? onOpenDrawer;

  @override
  State<PeopleView> createState() => _PeopleViewState();
}

class _PeopleViewState extends State<PeopleView> {
  final _query = TextEditingController();
  Timer? _debounce;

  List<Profile> _results = const [];
  bool _loading = true;
  Object? _error;

  bool get _picking => widget.onPick != null;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String q) async {
    try {
      final found = await Api.searchProfiles(q);
      // Ignore answers to an older query.
      if (!mounted || q.trim() != _query.text.trim()) return;
      setState(() {
        _results = found;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _toggleFollow(Profile profile) async {
    final i = _results.indexWhere((x) => x.id == profile.id);
    if (i < 0) return;
    final updated = profile.afterFollowTap();
    setState(() => _results = [..._results]..[i] = updated);
    try {
      await Api.setFollow(
        profile.id,
        follow: updated.followedByMe || updated.requestedByMe,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _results = [..._results]..[i] = profile);
      showError(context, e);
    }
  }

  void _open(Profile profile) {
    final pick = widget.onPick;
    if (pick != null) {
      pick(profile);
      return;
    }
    Navigator.of(context).push(appRoute(ProfileScreen(userId: profile.id)));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget results() {
      if (_loading) return const LoadingView();
      if (_error != null) {
        return ErrorView(
          error: _error!,
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _search(_query.text);
          },
        );
      }
      if (_results.isEmpty) {
        return EmptyState(
          icon: AppIcons.people,
          title: 'No people found',
          subtitle: 'Try a different name or username.',
        );
      }
      final showHeader = !_picking && _query.text.trim().isEmpty;
      final offset = showHeader ? 1 : 0;
      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: _results.length + offset,
        itemBuilder: (context, i) {
          if (showHeader && i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Who to follow',
                style: TextStyle(
                  color: p.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }
          final profile = _results[i - offset];
          return PersonTile(
            key: ValueKey(profile.id),
            profile: profile,
            onTap: () => _open(profile),
            onToggleFollow: _picking ? null : () => _toggleFollow(profile),
          );
        },
      );
    }

    final pill = SearchPill(
      controller: _query,
      placeholder: 'Search people',
      onChanged: _onChanged,
    );

    final content = ContentWidth(
      child: Column(
        children: [
          if (_picking)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: pill,
            )
          else
            TopBar(
              me: widget.me,
              onAvatar: widget.onOpenDrawer ?? () {},
              middle: pill,
            ),
          const HairlineDivider(),
          Expanded(child: results()),
        ],
      ),
    );

    // The tab has no app bar of its own, so keep clear of the status bar.
    return _picking ? content : SafeArea(bottom: false, child: content);
  }
}

/// Full-screen picker that returns the chosen [Profile].
class PeoplePickScreen extends StatelessWidget {
  const PeoplePickScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: const AdaptiveAppBar(title: 'New message'),
      body: PeopleView(
        onPick: (profile) => Navigator.of(context).pop(profile),
      ),
    );
  }
}
