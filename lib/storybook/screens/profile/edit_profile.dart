import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storybook_toolkit/storybook_toolkit.dart';
import 'package:squadquest/app_scaffold.dart';

class EditProfileScreen extends ConsumerWidget {
  final bool isNewProfile;

  const EditProfileScreen({
    super.key,
    this.isNewProfile = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfilePhoto = context.knobs.boolean(
      label: 'Has profile photo',
      initial: false,
      description: 'Toggle profile photo state',
    );

    return AppScaffold(
      title: isNewProfile ? 'Create Profile' : 'Edit Profile',
      body: CustomScrollView(
        slivers: [
          // Profile Photo Section
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: isNewProfile ? 280 : 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
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
                          hasProfilePhoto
                              ? Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 64,
                                      backgroundImage: NetworkImage(
                                          'https://picsum.photos/200'),
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
                                          onPressed: () {},
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 64,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                      child: const Icon(Icons.person, size: 64),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
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
            ),
          ),

          // Form Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              hintText: 'Enter your first name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Enter your last name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your last name will only be visible to confirmed friends',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Appearance Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: const Text('Trail Color'),
                            subtitle: const Text(
                                'Choose the color for your map trail'),
                            trailing: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  FilledButton(
                    onPressed: () {},
                    child: Text(isNewProfile ? 'Get Started' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
