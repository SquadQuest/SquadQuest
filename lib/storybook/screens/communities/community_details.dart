import 'package:flutter/material.dart';

class CommunityDetailsScreen extends StatelessWidget {
  const CommunityDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Ladies of Civic Tech'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.purple.shade300,
                          Colors.purple.shade700,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '324 members',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '47 events',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A community for women and non-binary individuals working in civic technology, government digital services, and public interest tech. We focus on professional development, mentorship, and creating positive change through technology.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Featured Cohosts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._mockCohosts.map((cohost) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(cohost.name[0]),
                          ),
                          title: Text(cohost.name),
                          subtitle: Text(cohost.role),
                        ),
                      )),
                  const Text(
                    'Photo Gallery',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _mockPhotos
                          .map((photo) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photo,
                                    width: 160,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Announcements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._mockAnnouncements.map((announcement) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(announcement.author[0]),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          announcement.author,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          announcement.date,
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
                              Text(announcement.content),
                              if (announcement.hasLink) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {},
                                  child: const Text('View Details'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Resources',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Add Resource'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._mockResources.map((resource) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            resource.type == ResourceType.link
                                ? Icons.link
                                : Icons.description,
                            color: Colors.blue,
                          ),
                          title: Text(resource.title),
                          subtitle: Text(resource.description),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () {},
                          ),
                        ),
                      )),
                  const SizedBox(height: 24),
                  const Text(
                    'Featured Cohosts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._mockCohosts.map((cohost) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(cohost.name[0]),
                          ),
                          title: Text(cohost.name),
                          subtitle: Text(cohost.role),
                        ),
                      )),
                  const SizedBox(height: 24),
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._mockEvents.map((event) => _EventCard(event: event)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Join Community'),
        icon: const Icon(Icons.group_add),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final _MockEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(event.title),
            subtitle: Text(event.date),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Venue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(event.venue.name),
                Text(
                  event.venue.address,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Proposed Activities',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...event.activities.map((activity) => _ActivityVoteCard(
                      activity: activity,
                    )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityVoteCard extends StatelessWidget {
  final _MockActivity activity;

  const _ActivityVoteCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: activity.votes / 10, // Max votes for demo
                  backgroundColor: Colors.grey.withAlpha(40),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text('${activity.votes} votes'),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              activity.hasVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: activity.hasVoted ? Colors.blue : null,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _MockCohost {
  final String name;
  final String role;

  const _MockCohost({
    required this.name,
    required this.role,
  });
}

final _mockCohosts = [
  _MockCohost(
    name: 'Tara Chen',
    role: 'Digital Services Director, City of Philadelphia',
  ),
  _MockCohost(
    name: 'Maria Rodriguez',
    role: 'Tech Lead, Code for Philly',
  ),
  _MockCohost(
    name: 'Sarah Johnson',
    role: 'Product Manager, Civic Tech Solutions',
  ),
];

class _MockVenue {
  final String name;
  final String address;

  const _MockVenue({
    required this.name,
    required this.address,
  });
}

class _MockActivity {
  final String name;
  final int votes;
  final bool hasVoted;

  const _MockActivity({
    required this.name,
    required this.votes,
    this.hasVoted = false,
  });
}

class _MockEvent {
  final String title;
  final String date;
  final _MockVenue venue;
  final List<_MockActivity> activities;

  const _MockEvent({
    required this.title,
    required this.date,
    required this.venue,
    required this.activities,
  });
}

enum ResourceType {
  link,
  document,
}

class _MockAnnouncement {
  final String author;
  final String date;
  final String content;
  final bool hasLink;

  const _MockAnnouncement({
    required this.author,
    required this.date,
    required this.content,
    this.hasLink = false,
  });
}

final _mockAnnouncements = [
  _MockAnnouncement(
    author: 'Tara Chen',
    date: 'Feb 1, 2025',
    content:
        'Excited to announce our partnership with the City of Philadelphia\'s Digital Services team for an upcoming workshop series!',
    hasLink: true,
  ),
  _MockAnnouncement(
    author: 'Maria Rodriguez',
    date: 'Jan 28, 2025',
    content:
        'Looking for speakers for our March event. If you\'re working on an interesting civic tech project, we\'d love to hear from you.',
  ),
  _MockAnnouncement(
    author: 'Sarah Johnson',
    date: 'Jan 25, 2025',
    content:
        'New mentorship program launching next month. Stay tuned for details on how to participate as either a mentor or mentee.',
    hasLink: true,
  ),
];

class _MockResource {
  final String title;
  final String description;
  final ResourceType type;

  const _MockResource({
    required this.title,
    required this.description,
    required this.type,
  });
}

final _mockResources = [
  _MockResource(
    title: 'Civic Tech Career Guide',
    description:
        'A comprehensive guide to finding and growing your career in civic technology',
    type: ResourceType.document,
  ),
  _MockResource(
    title: 'Open Data Resources',
    description:
        'Collection of APIs and datasets from the City of Philadelphia',
    type: ResourceType.link,
  ),
  _MockResource(
    title: 'Tech for Public Good Toolkit',
    description: 'Best practices and case studies for civic tech projects',
    type: ResourceType.document,
  ),
];

final _mockPhotos = [
  'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=400',
  'https://images.unsplash.com/photo-1491438590914-bc09fcaaf77a?w=400',
  'https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=400',
  'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=400',
  'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=400',
];

final _mockEvents = [
  _MockEvent(
    title: 'February Meetup: Tech for Public Good',
    date: 'Feb 15, 2025 • 6:00 PM',
    venue: _MockVenue(
      name: 'CIC Philadelphia',
      address: '3675 Market Street, Philadelphia, PA',
    ),
    activities: [
      _MockActivity(
        name: 'Lightning Talks: Civic Tech Projects',
        votes: 8,
        hasVoted: true,
      ),
      _MockActivity(
        name: 'Workshop: Open Data Analysis',
        votes: 6,
      ),
      _MockActivity(
        name: 'Panel: Women in Government Tech',
        votes: 7,
      ),
    ],
  ),
  _MockEvent(
    title: 'March Social: Network & Learn',
    date: 'Mar 20, 2025 • 5:30 PM',
    venue: _MockVenue(
      name: 'Independence Library',
      address: '18 S 7th Street, Philadelphia, PA',
    ),
    activities: [
      _MockActivity(
        name: 'Speed Networking',
        votes: 5,
      ),
      _MockActivity(
        name: 'Tech Career Panel',
        votes: 9,
        hasVoted: true,
      ),
      _MockActivity(
        name: 'Project Showcase',
        votes: 4,
      ),
    ],
  ),
];
