import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/avatar.dart';
import '../widgets/responsive.dart';

/// Update display name, bio and profile picture.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  PickedImage? _newAvatar;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final img = await pickGalleryImage();
      if (img != null && mounted) setState(() => _newAvatar = img);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = Validators.displayName(_name.text) ?? Validators.bio(_bio.text);
    if (problem != null) {
      showError(context, problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      String? avatarUrl;
      final img = _newAvatar;
      if (img != null) {
        avatarUrl = await Api.uploadImage(
          bucket: AppConfig.avatarsBucket,
          image: img,
        );
      }
      await Api.updateProfile(
        displayName: _name.text,
        bio: _bio.text,
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final profile = widget.profile;
    final img = _newAvatar;

    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: AdaptiveAppBar(
        title: 'Edit profile',
        actions: [
          AdaptiveAppBarAction(
            title: _busy ? 'Saving…' : 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (img != null)
                          ClipOval(
                            child: Image.memory(
                              img.bytes,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Avatar(
                            url: profile.avatarUrl,
                            name: profile.name,
                            size: 96,
                          ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x55000000),
                          ),
                          child: Icon(
                            AppIcons.camera,
                            color: const Color(0xFFFFFFFF),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: AdaptiveButton(
                    color: AppPalette.of(context).accent,
                    onPressed: _pickAvatar,
                    label: 'Change photo',
                    style: AdaptiveButtonStyle.plain,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Name', style: TextStyle(color: p.subtext, fontSize: 13)),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _name,
                  placeholder: 'Your name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Text('Bio', style: TextStyle(color: p.subtext, fontSize: 13)),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _bio,
                  placeholder: 'Tell people about yourself',
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_bio.text.length}/${AppConfig.maxBioLength}',
                      style: TextStyle(
                        color: _bio.text.length > AppConfig.maxBioLength
                            ? p.danger
                            : p.subtext,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Username', style: TextStyle(color: p.subtext, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '@${profile.username}',
                  style: TextStyle(color: p.text, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
