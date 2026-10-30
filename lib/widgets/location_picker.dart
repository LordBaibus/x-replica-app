import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../services/location_service.dart';

/// "Tag location" sheet. Asks the phone for permission (the OS shows its
/// own prompt), lists places near the user and lets them search for others.
///
/// Resolves to the chosen place, an empty string when "Remove" was tapped,
/// or null when nothing changed.
Future<String?> showLocationPicker(BuildContext context, {String? current}) {
  final p = AppPalette.of(context);
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 16,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
      child: _LocationSheet(current: current),
    ),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({this.current});

  final String? current;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  StreamSubscription<String>? _sub;

  final List<String> _nearby = [];
  List<String> _found = [];
  bool _loadingNearby = true;
  bool _searching = false;
  bool _noGps = false;
  String _term = '';
  String? _selected;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _loadNearby();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadNearby() async {
    final pos = await LocationService.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _loadingNearby = false;
        _noGps = true;
      });
      return;
    }
    _sub = LocationService.nearby(pos).listen(
      (label) {
        if (mounted) setState(() => _nearby.add(label));
      },
      onDone: () {
        if (mounted) setState(() => _loadingNearby = false);
      },
      onError: (_) {
        if (mounted) setState(() => _loadingNearby = false);
      },
    );
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    final term = v.trim();
    setState(() {
      _term = term;
      if (term.isEmpty) {
        _found = [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (term.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final mine = ++_seq;
      final hits = await LocationService.search(term);
      if (!mounted || mine != _seq) return;
      setState(() {
        _found = hits;
        _searching = false;
      });
    });
  }

  List<String> get _rows {
    if (_term.isEmpty) return _nearby;
    // Always offer the typed text itself, so a search never dead-ends.
    return [
      if (!_found.contains(_term)) _term,
      ..._found,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final height = media.size.height - media.padding.top - 16;
    final rows = _rows;
    final hasCurrent = (widget.current ?? '').isNotEmpty;
    final busy = _term.isEmpty ? _loadingNearby : _searching;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        width: double.infinity,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hasCurrent
                          ? () => Navigator.of(context).pop('')
                          : null,
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: hasCurrent ? p.text : p.subtext,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Tag location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(_selected),
                      child: Text(
                        'Done',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: CupertinoSearchTextField(
                controller: _query,
                placeholder: 'Search locations',
                onChanged: _onQuery,
                style: TextStyle(color: p.text, fontSize: 17),
                placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
                backgroundColor: p.field,
                borderRadius: BorderRadius.circular(22),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_noGps && _term.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Location access is off, so places near you can’t be '
                  'shown. Search for a place instead, or allow location in '
                  'your phone’s settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  for (final r in rows)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 19),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (r == _selected)
                              Icon(CupertinoIcons.checkmark_alt,
                                  size: 22, color: p.accent),
                          ],
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CupertinoActivityIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
