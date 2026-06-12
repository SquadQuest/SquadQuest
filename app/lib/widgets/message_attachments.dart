import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/message.dart';
import '../providers/providers.dart';

/// A compose-time attachment tray: an attach button that picks + uploads an image
/// (kind `message`) and a pending-thumbnail strip with remove. Owns the pending
/// list and reports changes via [onChanged]. Shared by the squad composer and
/// thread-reply input (specs/api/messages.md, plans/v2-message-attachments-ui).
class MessageAttachmentField extends ConsumerStatefulWidget {
  const MessageAttachmentField({
    super.key,
    required this.attachments,
    required this.onChanged,
    this.enabled = true,
  });

  final List<MessageAttachment> attachments;
  final ValueChanged<List<MessageAttachment>> onChanged;
  final bool enabled;

  @override
  ConsumerState<MessageAttachmentField> createState() =>
      _MessageAttachmentFieldState();
}

class _MessageAttachmentFieldState
    extends ConsumerState<MessageAttachmentField> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy || !widget.enabled) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final contentType = picked.mimeType ?? _guessType(picked.name);
      final upload = await ref
          .read(uploadRepositoryProvider)
          .uploadImage(kind: 'message', bytes: bytes, contentType: contentType);
      widget.onChanged([
        ...widget.attachments,
        MessageAttachment(key: upload.key, url: upload.url),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t add that image. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(MessageAttachment a) => widget.onChanged(
    widget.attachments.where((x) => x.key != a.key).toList(),
  );

  static String _guessType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('attachImageButton'),
          tooltip: 'Add a photo',
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          onPressed: widget.enabled && !_busy ? _pick : null,
        ),
        Expanded(
          child: SizedBox(
            height: widget.attachments.isEmpty ? 0 : 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in widget.attachments)
                  Padding(
                    key: Key('pendingAttachment_${a.key}'),
                    padding: const EdgeInsets.only(right: 6),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            a.url,
                            height: 56,
                            width: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _remove(a),
                            child: const CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Read-path: render a message's image attachments as a wrapped thumbnail row,
/// tap to view full-screen. Empty list renders nothing.
class MessageAttachmentThumbs extends StatelessWidget {
  const MessageAttachmentThumbs({super.key, required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in attachments)
            GestureDetector(
              key: Key('attachmentThumb_${a.key}'),
              onTap: () => _viewFull(context, a.url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  a.url,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _viewFull(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }
}
