import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfileFormPhotoSection extends StatelessWidget {
  final Uri? photo;
  final bool isNewProfile;
  final Function(Uri?) onPhotoChanged;

  const ProfileFormPhotoSection({
    super.key,
    required this.photo,
    required this.isNewProfile,
    required this.onPhotoChanged,
  });

  Future<void> _pickPhoto() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      onPhotoChanged(
          kIsWeb ? Uri.parse(pickedFile.path) : File(pickedFile.path).uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: isNewProfile ? 280 : 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.8, 1.0],
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
        Positioned(
          top: 36,
          child: Column(
            children: [
              Stack(
                children: [
                  photo != null
                      ? Stack(
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundImage:
                                  kIsWeb || !photo!.isScheme('file')
                                      ? NetworkImage(photo.toString())
                                      : FileImage(File(
                                              Uri.decodeComponent(photo!.path)))
                                          as ImageProvider,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => onPhotoChanged(null),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              child: const Icon(Icons.person, size: 64),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: _pickPhoto,
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
              if (isNewProfile) ...[
                const SizedBox(height: 24),
                const Text(
                  'Welcome to SquadQuest!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Tell us a bit about yourself to get started',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
