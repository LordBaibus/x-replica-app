import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/pill_button.dart';
import '../widgets/responsive.dart';
import 'onboarding_flow.dart' show InterestChips;

/// Change the topics that show up as extra tabs on Home.
/// Pops with `true` once saved.
class InterestsEditScreen extends StatefulWidget {
  const InterestsEditScreen({super.key, required this.me});

  final Profile? me;

  @override
  State<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends State<InterestsEditScreen> {
  late final Set<String> _selected = {...?widget.me?.interests};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.updateMyProfile({'interests': _selected.toList()});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Your topics'),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Pick what you want on your Home tabs',
                style: TextStyle(
                  color: p.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The first three you pick get their own tab.',
                style: TextStyle(color: p.subtext, fontSize: 15),
              ),
              const SizedBox(height: 20),
              InterestChips(
                selected: _selected,
                onToggle: (id) => setState(() {
                  if (!_selected.remove(id)) _selected.add(id);
                }),
              ),
              const SizedBox(height: 28),
              PillButton(
                label: _saving ? 'Saving…' : 'Save',
                style: PillStyle.inverse,
                height: 44,
                fontSize: 16,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
