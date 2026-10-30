import 'dart:ui' show Canvas, Paint, PaintingStyle, Path, Size, StrokeJoin;

import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../services/ai_service.dart';
import '../services/image_picker_service.dart';
import '../core/ui_helpers.dart';
import 'dialog_card.dart';

/// A simple four-point sparkle, used as the AI button's icon so the app does
/// not need any third-party logo.
class AiGlyph extends StatelessWidget {
  const AiGlyph({super.key, this.size = 22, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SparklePainter(color)),
      );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  Path _star(double cx, double cy, double r) {
    final k = r * 0.22;
    return Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
      ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(_star(size.width * 0.42, size.height * 0.58, size.width * 0.38), stroke);
    canvas.drawPath(_star(size.width * 0.78, size.height * 0.2, size.width * 0.16), fill);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

enum AiAction { generateImage, enhance }

/// Small menu opened by the AI button: "Generate image" / "Enhance your
/// post". Enhancing needs some text first, so it is greyed out when empty.
Future<AiAction?> showAiMenu(BuildContext context, {required bool hasText}) {
  return showCardDialog<AiAction>(
    context,
    maxWidth: 420,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      Widget row(IconData icon, String label, bool enabled, AiAction action) {
        final color = enabled ? p.text : p.subtext;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => Navigator.of(ctx).pop(action) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: enabled ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(CupertinoIcons.paintbrush, 'Generate image', true,
              AiAction.generateImage),
          row(CupertinoIcons.pencil, 'Enhance your post with AI', hasText,
              AiAction.enhance),
          const SizedBox(height: 8),
          DialogPillButton(
            label: 'Cancel',
            style: DialogPillStyle.grey,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      );
    },
  );
}

/// "Generate image": describe a picture, get it back as an image to attach.
Future<PickedImage?> showGenerateImageDialog(BuildContext context) {
  return showCardDialog<PickedImage>(
    context,
    maxWidth: 480,
    builder: (ctx) => const _GenerateCard(),
  );
}

class _GenerateCard extends StatefulWidget {
  const _GenerateCard();

  @override
  State<_GenerateCard> createState() => _GenerateCardState();
}

class _GenerateCardState extends State<_GenerateCard> {
  final TextEditingController _prompt = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final text = _prompt.text.trim();
    if (text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final img = await AiAssist.generateImage(text);
      if (mounted) Navigator.of(context).pop(img);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardHeader(
          title: 'Generate image',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 14),
        CupertinoTextField(
          controller: _prompt,
          placeholder: 'Describe the image you want',
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: p.text, fontSize: 16),
          placeholderStyle: TextStyle(color: p.subtext, fontSize: 16),
          cursorColor: p.accent,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!, style: TextStyle(color: p.danger, fontSize: 14)),
          ),
        const SizedBox(height: 16),
        DialogPillButton(
          label: 'Generate',
          busy: _busy,
          onPressed: _prompt.text.trim().isEmpty ? null : _go,
        ),
      ],
    );
  }
}

/// "Content disclosures": paid partnership and made-with-AI switches.
/// Resolves to (paidPartnership, madeWithAi) or null when closed.
Future<(bool, bool)?> showDisclosuresDialog(
  BuildContext context, {
  required bool paid,
  required bool ai,
}) {
  return showCardDialog<(bool, bool)>(
    context,
    maxWidth: 480,
    builder: (ctx) => _DisclosureCard(paid: paid, ai: ai),
  );
}

class _DisclosureCard extends StatefulWidget {
  const _DisclosureCard({required this.paid, required this.ai});

  final bool paid;
  final bool ai;

  @override
  State<_DisclosureCard> createState() => _DisclosureCardState();
}

class _DisclosureCardState extends State<_DisclosureCard> {
  late bool _paid = widget.paid;
  late bool _ai = widget.ai;

  Widget _row(AppPalette p, String title, String text, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CupertinoSwitch(
            value: value,
            activeTrackColor: p.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardHeader(
          title: 'Content disclosures',
          onClose: () => Navigator.of(context).pop(),
        ),
        _row(
          p,
          'Paid Partnership',
          'Let others know this post promotes a brand or business.',
          _paid,
          (v) => setState(() => _paid = v),
        ),
        _row(
          p,
          'Made with AI',
          'Let others know this post contains synthetically-generated content.',
          _ai,
          (v) => setState(() => _ai = v),
        ),
        const SizedBox(height: 28),
        DialogPillButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop((_paid, _ai)),
        ),
      ],
    );
  }
}
