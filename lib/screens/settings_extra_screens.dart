import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../widgets/settings_kit.dart';
import 'info_screen.dart';

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/// "Storage": breakdown bar, categories and "Clear all storage". Only the
/// image cache can be measured from inside the app; the other categories
/// stay at zero.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _Category {
  const _Category(this.name, this.color, this.bytes);

  final String name;
  final Color color;
  final int bytes;
}

class _StorageScreenState extends State<StorageScreen> {
  static const _blue = Color(0xFF1D9BF0);
  static const _orange = Color(0xFFFF7A00);
  static const _green = Color(0xFF00BA7C);
  static const _purple = Color(0xFF7856FF);
  static const _yellow = Color(0xFFFFD400);
  static const _grey = Color(0xFF536471);

  int _media = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  void _measure() {
    _media = PaintingBinding.instance.imageCache.currentSizeBytes;
  }

  static String _size(int bytes) {
    if (bytes <= 0) return 'Zero KB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearAll() async {
    final ok = await confirm(
      context,
      title: 'Clear all storage?',
      message: 'This will clear all cached media, videos, offline content, '
          'and web data. You may need to re-download content to view it '
          'again.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!ok) return;
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    setState(_measure);
    showInfo(context, 'Storage cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cats = [
      _Category('Media storage', _blue, _media),
      const _Category('Network cache', _orange, 0),
      const _Category('Offline videos', _green, 0),
      const _Category('Web storage', _purple, 0),
      const _Category('Data', _yellow, 0),
      const _Category('Other', _grey, 0),
    ];
    final total = cats.fold<int>(0, (a, c) => a + c.bytes);

    String pct(int bytes) =>
        total == 0 ? '0%' : '${(bytes * 100 / total).round()}%';

    return SettingsFrame(
      title: 'Storage',
      showHandle: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SettingsIntro(
            '${AppConfig.appName} is using ${_size(total)} of storage on this '
            'device.',
          ),
          const SettingsDivider(),
          const SettingsSectionTitle('Storage breakdown'),
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 26),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 16,
                  child: total == 0
                      ? ColoredBox(color: p.border)
                      : Row(
                          children: [
                            for (final c in cats)
                              if (c.bytes > 0)
                                Expanded(
                                  flex: c.bytes,
                                  child: ColoredBox(color: c.color),
                                ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SettingsDivider(),
          const SettingsSectionTitle('Categories'),
          for (final c in cats)
            SettingsColumn(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: c.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(color: p.text, fontSize: 17),
                      ),
                    ),
                    Text(
                      '${_size(c.bytes)} (${pct(c.bytes)})',
                      style: TextStyle(color: p.subtext, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          SettingsColumn(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clearAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text(
                    'Clear all storage',
                    style: TextStyle(
                      color: p.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SettingsColumn(
            child: Text(
              'This will clear all cached media, videos, offline content, '
              'and web data. You may need to re-download content to view it '
              'again.',
              style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Additional resources
// ---------------------------------------------------------------------------

class AdditionalResourcesScreen extends StatefulWidget {
  const AdditionalResourcesScreen({super.key});

  @override
  State<AdditionalResourcesScreen> createState() =>
      _AdditionalResourcesScreenState();
}

class _AdditionalResourcesScreenState extends State<AdditionalResourcesScreen> {
  static const _crashKey = 'send_crash_reports';
  bool _crash = true;

  @override
  void initState() {
    super.initState();
    _loadCrash();
  }

  Future<void> _loadCrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _crash = prefs.getBool(_crashKey) ?? true);
    } catch (_) {}
  }

  Future<void> _setCrash(bool v) async {
    setState(() => _crash = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_crashKey, v);
    } catch (_) {}
  }

  Widget _kv(AppPalette p, String key, String value) => SettingsColumn(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(value, style: TextStyle(color: p.subtext, fontSize: 17)),
            ],
          ),
        ),
      );

  void _doc(String title) => notify(
        context,
        title: title,
        message: '${AppConfig.appName} is a university project, so it has no '
            'real $title. This row is shown so the layout matches.',
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Additional resources',
      showHandle: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 6),
          _kv(p, 'Version', AppConfig.version),
          _kv(p, 'Build', '1'),
          const SizedBox(height: 4),
          const SettingsDivider(),
          const SettingsSectionTitle('Get help'),
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send crash reports',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: _crash,
                        activeTrackColor: const Color(0xFF00BA7C),
                        onChanged: _setCrash,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatically send crash reports to the service provider '
                    'to help improve this application.',
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsRow(
            title: 'Help Center',
            onTap: () => Navigator.of(context).push(
              appRoute(
                const InfoScreen(
                  title: 'Help Center',
                  headline: 'How things work',
                  body: 'A quick tour of the app.',
                  points: [
                    'Post: tap the blue button. Add a photo and up to 280 '
                        'characters.',
                    'Follow: use Who to follow on the Search tab or open a '
                        'profile.',
                    'Chat: open the Chat tab, set a passcode and start a '
                        'new chat.',
                  ],
                ),
              ),
            ),
          ),
          const SettingsDivider(),
          const SettingsSectionTitle('Legal'),
          SettingsRow(title: 'Terms of service', onTap: () => _doc('Terms of service')),
          SettingsRow(title: 'Privacy policy', onTap: () => _doc('Privacy policy')),
          SettingsRow(title: 'Cookie use', onTap: () => _doc('Cookie policy')),
          SettingsRow(title: 'Legal notices', onTap: () => _doc('Legal notices')),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Copyright © ${DateTime.now().year} ${AppConfig.appName}.',
              style: TextStyle(color: p.subtext, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
