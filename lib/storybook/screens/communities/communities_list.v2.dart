import 'package:flutter/material.dart';

class CommunitiesListV2Screen extends StatelessWidget {
  const CommunitiesListV2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Communities'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () {},
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: true,
                    ),
                    _FilterChip(
                      label: 'Most Active',
                      icon: Icons.local_fire_department,
                    ),
                    _FilterChip(
                      label: 'Near Me',
                      icon: Icons.location_on,
                    ),
                    _FilterChip(
                      label: 'New',
                      icon: Icons.new_releases,
                    ),
                    _FilterChip(
                      label: 'My Interests',
                      icon: Icons.favorite,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _mockCategories
                        .map((category) => _CategoryCard(category: category))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Trending This Week',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _mockTrendingCommunities
                        .map((community) =>
                            _TrendingCommunityCard(community: community))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._mockActivities
                    .map((activity) => _ActivityCard(activity: activity)),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recommended for You',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._mockRecommendedCommunities
                    .map((community) => _CommunityCard(community: community)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Create Community'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        onSelected: (value) {},
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _MockCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: 32,
                color: category.color,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingCommunityCard extends StatelessWidget {
  final _MockTrendingCommunity community;

  const _TrendingCommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(community.name[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${community.memberCount} members',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              community.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.5),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 16,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  community.trendReason,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _MockActivity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple,
              child: Text(activity.communityName[0]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: activity.communityName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: activity.action),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.timeAgo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final _MockCommunity community;

  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(community.name[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${community.memberCount} members • ${community.eventsCount} upcoming events',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Join'),
                ),
              ],
            ),
            if (community.matchReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      community.matchReason!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MockCategory {
  final String name;
  final IconData icon;
  final Color color;

  const _MockCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

final _mockCategories = [
  _MockCategory(
    name: 'Tech',
    icon: Icons.computer,
    color: Colors.blue,
  ),
  _MockCategory(
    name: 'Sports',
    icon: Icons.sports_basketball,
    color: Colors.orange,
  ),
  _MockCategory(
    name: 'Arts',
    icon: Icons.palette,
    color: Colors.purple,
  ),
  _MockCategory(
    name: 'Food',
    icon: Icons.restaurant,
    color: Colors.red,
  ),
  _MockCategory(
    name: 'Music',
    icon: Icons.music_note,
    color: Colors.green,
  ),
  _MockCategory(
    name: 'Books',
    icon: Icons.book,
    color: Colors.brown,
  ),
];

class _MockTrendingCommunity {
  final String name;
  final int memberCount;
  final String description;
  final String trendReason;

  const _MockTrendingCommunity({
    required this.name,
    required this.memberCount,
    required this.description,
    required this.trendReason,
  });
}

final _mockTrendingCommunities = [
  _MockTrendingCommunity(
    name: 'Philly Tech Meetup',
    memberCount: 1243,
    description:
        'A community for tech enthusiasts in Philadelphia. We host regular meetups, workshops, and networking events.',
    trendReason: '45% growth this week',
  ),
  _MockTrendingCommunity(
    name: 'Urban Gardeners',
    memberCount: 892,
    description:
        'Connect with fellow gardeners, share tips, and participate in community garden projects.',
    trendReason: '12 new events added',
  ),
  _MockTrendingCommunity(
    name: 'Local Game Dev',
    memberCount: 567,
    description:
        'A space for game developers to collaborate, share work, and organize game jams.',
    trendReason: 'High engagement rate',
  ),
];

class _MockActivity {
  final String communityName;
  final String action;
  final String timeAgo;

  const _MockActivity({
    required this.communityName,
    required this.action,
    required this.timeAgo,
  });
}

final _mockActivities = [
  _MockActivity(
    communityName: 'Philly Tech Meetup',
    action: 'just announced a new workshop series',
    timeAgo: '2 hours ago',
  ),
  _MockActivity(
    communityName: 'Urban Gardeners',
    action: 'is planning a community garden cleanup',
    timeAgo: '4 hours ago',
  ),
  _MockActivity(
    communityName: 'Local Game Dev',
    action: 'posted new resources for beginners',
    timeAgo: '6 hours ago',
  ),
];

class _MockCommunity {
  final String name;
  final int memberCount;
  final int eventsCount;
  final String? matchReason;

  const _MockCommunity({
    required this.name,
    required this.memberCount,
    required this.eventsCount,
    this.matchReason,
  });
}

final _mockRecommendedCommunities = [
  _MockCommunity(
    name: 'Women in Tech PHL',
    memberCount: 892,
    eventsCount: 3,
    matchReason: 'Matches your interests in technology',
  ),
  _MockCommunity(
    name: 'Center City Book Club',
    memberCount: 432,
    eventsCount: 1,
    matchReason: 'Active near you',
  ),
  _MockCommunity(
    name: 'Philly Street Photography',
    memberCount: 654,
    eventsCount: 2,
    matchReason: 'Similar to communities you\'ve joined',
  ),
];
