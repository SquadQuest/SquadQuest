import 'package:flutter/material.dart';

class CommunitiesListScreen extends StatelessWidget {
  const CommunitiesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mockCommunities.length,
        itemBuilder: (context, index) {
          final community = _mockCommunities[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Colors.primaries[index % Colors.primaries.length],
                child: Text(
                  community.name[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(community.name),
              subtitle: Text('${community.memberCount} members'),
              trailing: community.isMember
                  ? TextButton(
                      onPressed: () {},
                      child: const Text('JOINED'),
                    )
                  : OutlinedButton(
                      onPressed: () {},
                      child: const Text('JOIN'),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _MockCommunity {
  final String name;
  final int memberCount;
  final bool isMember;

  const _MockCommunity({
    required this.name,
    required this.memberCount,
    this.isMember = false,
  });
}

final _mockCommunities = [
  _MockCommunity(
    name: 'Philly Board Games',
    memberCount: 1243,
    isMember: true,
  ),
  _MockCommunity(
    name: 'Center City Running Club',
    memberCount: 892,
  ),
  _MockCommunity(
    name: 'Weekend Hikers',
    memberCount: 567,
    isMember: true,
  ),
  _MockCommunity(
    name: 'Photography Enthusiasts',
    memberCount: 1892,
  ),
  _MockCommunity(
    name: 'Local Food Adventures',
    memberCount: 2341,
  ),
  _MockCommunity(
    name: 'Tech Meetup Group',
    memberCount: 782,
    isMember: true,
  ),
  _MockCommunity(
    name: 'Urban Gardening Club',
    memberCount: 432,
  ),
  _MockCommunity(
    name: 'Art Gallery Hoppers',
    memberCount: 654,
  ),
];
