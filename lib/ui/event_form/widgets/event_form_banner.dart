import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Banner photo selection section for event form.
///
/// Displays a banner photo picker that allows users to:
/// - Add a photo from their gallery
/// - View the selected photo
/// - Edit or delete the selected photo
class EventFormBanner extends ConsumerWidget {
  const EventFormBanner({
    super.key,
    required this.bannerPhotoProvider,
  });

  final StateProvider<Uri?> bannerPhotoProvider;

  Future<void> _pickImage(WidgetRef ref) async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      ref.read(bannerPhotoProvider.notifier).state =
          kIsWeb ? Uri.parse(pickedFile.path) : File(pickedFile.path).uri;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final bannerPhoto = ref.watch(bannerPhotoProvider);
              if (bannerPhoto != null) {
                return kIsWeb || !bannerPhoto.isScheme('file')
                    ? Image.network(
                        bannerPhoto.toString(),
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(Uri.decodeComponent(bannerPhoto.path)),
                        fit: BoxFit.cover,
                      );
              }
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Cover Photo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final bannerPhoto = ref.watch(bannerPhotoProvider);
              if (bannerPhoto != null) {
                return Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          ref.read(bannerPhotoProvider.notifier).state = null;
                        },
                        icon: const Icon(Icons.delete),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _pickImage(ref),
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                );
              }
              return Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickImage(ref),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
