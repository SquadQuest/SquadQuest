import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/providers.dart';

/// A tappable circular photo picker: pick an image → upload (kind-scoped) →
/// report the stored public URL via [onUploaded]. Reusable across profile,
/// community, and message-attachment surfaces (the shared upload primitive).
class PhotoPicker extends ConsumerStatefulWidget {
  const PhotoPicker({
    super.key,
    required this.kind,
    required this.onUploaded,
    this.currentUrl,
    this.radius = 48,
    this.fallbackIcon = Icons.add_a_photo_outlined,
  });

  /// Upload kind: 'profile' | 'community' | 'message' (see specs/api/uploads.md).
  final String kind;
  final ValueChanged<String> onUploaded;
  final String? currentUrl;
  final double radius;
  final IconData fallbackIcon;

  @override
  ConsumerState<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends ConsumerState<PhotoPicker> {
  bool _busy = false;
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.currentUrl;
  }

  Future<void> _pick() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      // image_picker gives a path/mime; default to jpeg when unknown.
      final contentType = picked.mimeType ?? _guessType(picked.name);
      final upload = await ref
          .read(uploadRepositoryProvider)
          .uploadImage(
            kind: widget.kind,
            bytes: bytes,
            contentType: contentType,
          );
      if (!mounted) return;
      setState(() => _url = upload.url);
      widget.onUploaded(upload.url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t upload that image. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _guessType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Choose a photo',
      child: InkWell(
        key: const Key('photoPicker'),
        onTap: _busy ? null : _pick,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundImage: _url != null ? NetworkImage(_url!) : null,
          child: _busy
              ? const CircularProgressIndicator(strokeWidth: 2)
              : (_url == null
                    ? Icon(widget.fallbackIcon, size: widget.radius * 0.6)
                    : null),
        ),
      ),
    );
  }
}
