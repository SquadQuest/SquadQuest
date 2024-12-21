import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadquest/app_scaffold.dart';

class FriendFinderScreen extends ConsumerStatefulWidget {
  const FriendFinderScreen({super.key});

  @override
  ConsumerState<FriendFinderScreen> createState() => _FriendFinderScreenState();
}

class _FriendFinderScreenState extends ConsumerState<FriendFinderScreen> {
  final List<_MockFriend> _suggestedFriends = [
    _MockFriend(
      name: "Sarah Chen",
      mutualActivities: ["Hiking", "Photography"],
      mutualFriends: 3,
      imageUrl: null,
    ),
    _MockFriend(
      name: "Mike Rodriguez",
      mutualActivities: ["Board Games", "Rock Climbing"],
      mutualFriends: 5,
      imageUrl: null,
    ),
    _MockFriend(
      name: "Alex Kim",
      mutualActivities: ["Photography", "Movie Nights"],
      mutualFriends: 2,
      imageUrl: null,
    ),
  ];

  final Set<String> _selectedFriends = {};

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Find Your Friends',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Look who\'s already here!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect with friends and see what activities they\'re planning.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for friends',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Text(
                  'Suggested Friends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text('Based on your interests'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _suggestedFriends.length,
              itemBuilder: (context, index) {
                final friend = _suggestedFriends[index];
                final isSelected = _selectedFriends.contains(friend.name);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Text(friend.name[0]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${friend.mutualFriends} mutual friends',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    friend.mutualActivities.map((activity) {
                                  return Chip(
                                    label: Text(activity),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    labelStyle: const TextStyle(fontSize: 12),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (isSelected) {
                                _selectedFriends.remove(friend.name);
                              } else {
                                _selectedFriends.add(friend.name);
                              }
                            });
                          },
                          icon: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedFriends.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton(
                  onPressed: () {
                    // This would send friend requests in the real app
                  },
                  child: Text(
                    'Send ${_selectedFriends.length} Friend Request${_selectedFriends.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MockFriend {
  final String name;
  final List<String> mutualActivities;
  final int mutualFriends;
  final String? imageUrl;

  _MockFriend({
    required this.name,
    required this.mutualActivities,
    required this.mutualFriends,
    this.imageUrl,
  });
}
