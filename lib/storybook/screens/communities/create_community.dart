import 'package:flutter/material.dart';

class CreateCommunityScreen extends StatelessWidget {
  const CreateCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Community'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            title: 'Why Create a Community?',
            description:
                'Communities offer more than just events. They provide a space for lasting connections, recurring meetups, and meaningful impact.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Community Name',
              hintText: 'e.g., Ladies of Civic Tech',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'What is your community about?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Community Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._mockFeatures.map((feature) => _FeatureCard(feature: feature)),
          const SizedBox(height: 24),
          const Text(
            'Venue Partnership',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Primary Venue'),
                  subtitle: const Text('Where most events will be hosted'),
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Select'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Partner with venues to get special perks:\n'
                    '• Priority booking for recurring events\n'
                    '• Discounted rates for community events\n'
                    '• Dedicated space for member meetups\n'
                    '• Co-marketing opportunities',
                    style: TextStyle(
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Engagement Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._mockSettings.map((setting) => _SettingCard(setting: setting)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String description;

  const _InfoCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _MockFeature feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                feature.icon,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
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

class _SettingCard extends StatelessWidget {
  final _MockSetting setting;

  const _SettingCard({required this.setting});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        title: Text(setting.title),
        subtitle: Text(setting.description),
        value: setting.defaultValue,
        onChanged: (value) {},
      ),
    );
  }
}

class _MockFeature {
  final String title;
  final String description;
  final IconData icon;

  const _MockFeature({
    required this.title,
    required this.description,
    required this.icon,
  });
}

final _mockFeatures = [
  _MockFeature(
    title: 'Recurring Events',
    description:
        'Set up regular meetups with consistent venues, times, and formats.',
    icon: Icons.repeat,
  ),
  _MockFeature(
    title: 'Member Directory',
    description:
        'Enable members to connect, share expertise, and build relationships.',
    icon: Icons.people,
  ),
  _MockFeature(
    title: 'Resource Library',
    description:
        'Share documents, guides, and resources specific to your community.',
    icon: Icons.library_books,
  ),
  _MockFeature(
    title: 'Activity Voting',
    description:
        'Let members vote on event activities to ensure engaging meetups.',
    icon: Icons.how_to_vote,
  ),
];

class _MockSetting {
  final String title;
  final String description;
  final bool defaultValue;

  const _MockSetting({
    required this.title,
    required this.description,
    this.defaultValue = true,
  });
}

final _mockSettings = [
  _MockSetting(
    title: 'Member Introductions',
    description: 'Allow members to post introductions in the community feed',
  ),
  _MockSetting(
    title: 'Activity Suggestions',
    description: 'Enable members to suggest activities for upcoming events',
  ),
  _MockSetting(
    title: 'Resource Sharing',
    description: 'Let members contribute to the resource library',
    defaultValue: false,
  ),
  _MockSetting(
    title: 'Event Co-hosting',
    description: 'Allow trusted members to create and host events',
    defaultValue: false,
  ),
];
