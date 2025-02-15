import 'package:flutter/material.dart';

class VenueProfileScreen extends StatelessWidget {
  const VenueProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('CIC Philadelphia'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=800',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _StatBadge(
                          icon: Icons.event,
                          label: '47 events hosted',
                        ),
                        const SizedBox(width: 12),
                        _StatBadge(
                          icon: Icons.people,
                          label: '1.2k attendees',
                        ),
                        const SizedBox(width: 12),
                        _StatBadge(
                          icon: Icons.groups,
                          label: '8 communities',
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
                    'CIC provides flexible office space, coworking, and labs for startups and established companies. Our mission is to support innovation and entrepreneurship in Philadelphia.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Venue Benefits',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._mockBenefits
                      .map((benefit) => _BenefitCard(benefit: benefit)),
                  const SizedBox(height: 24),
                  const Text(
                    'Analytics & Impact',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _AnalyticsCard(),
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
        label: const Text('Host an Event'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final _MockBenefit benefit;

  const _BenefitCard({required this.benefit});

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
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                benefit.icon,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    benefit.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    benefit.description,
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

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _AnalyticItem(
                    label: 'Avg. Event Rating',
                    value: '4.8',
                    trend: '+0.3',
                    isPositive: true,
                  ),
                ),
                Expanded(
                  child: _AnalyticItem(
                    label: 'Return Rate',
                    value: '72%',
                    trend: '+5%',
                    isPositive: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _AnalyticItem(
                    label: 'New Visitors',
                    value: '324',
                    trend: '+18%',
                    isPositive: true,
                  ),
                ),
                Expanded(
                  child: _AnalyticItem(
                    label: 'Avg. Group Size',
                    value: '28',
                    trend: '-3',
                    isPositive: false,
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

class _AnalyticItem extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final bool isPositive;

  const _AnalyticItem({
    required this.label,
    required this.value,
    required this.trend,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trend,
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final _MockEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(event.title),
        subtitle: Text(event.date),
        trailing: Text(
          '${event.attendees} attending',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MockBenefit {
  final String title;
  final String description;
  final IconData icon;

  const _MockBenefit({
    required this.title,
    required this.description,
    required this.icon,
  });
}

final _mockBenefits = [
  _MockBenefit(
    title: 'Community Exposure',
    description:
        'Get featured in our venue directory and gain exposure to thousands of active community members.',
    icon: Icons.visibility,
  ),
  _MockBenefit(
    title: 'Analytics Dashboard',
    description:
        'Access detailed analytics about events, attendees, and community engagement at your venue.',
    icon: Icons.analytics,
  ),
  _MockBenefit(
    title: 'Booking Management',
    description:
        'Streamlined booking process with automated confirmations and calendar integration.',
    icon: Icons.calendar_today,
  ),
  _MockBenefit(
    title: 'Promotional Support',
    description:
        'Featured placement in our event recommendations and community newsletters.',
    icon: Icons.campaign,
  ),
];

class _MockEvent {
  final String title;
  final String date;
  final int attendees;

  const _MockEvent({
    required this.title,
    required this.date,
    required this.attendees,
  });
}

final _mockEvents = [
  _MockEvent(
    title: 'Tech for Public Good Meetup',
    date: 'Feb 15, 2025 • 6:00 PM',
    attendees: 42,
  ),
  _MockEvent(
    title: 'Civic Tech Workshop Series',
    date: 'Feb 22, 2025 • 5:30 PM',
    attendees: 28,
  ),
  _MockEvent(
    title: 'Women in Tech Panel',
    date: 'Mar 1, 2025 • 6:30 PM',
    attendees: 35,
  ),
];
