import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadquest/logger.dart';
import 'package:squadquest/common.dart';
import 'package:squadquest/app_scaffold.dart';
import 'package:squadquest/services/supabase.dart';
import 'package:squadquest/services/profiles_cache.dart';
import 'package:squadquest/services/topics_cache.dart';
import 'package:squadquest/controllers/topic_memberships.dart';
import 'package:squadquest/models/user.dart';
import 'package:squadquest/models/instance.dart';
import 'package:squadquest/models/topic.dart';
import 'package:squadquest/models/topic_member.dart';

import 'widgets/profile_header.dart';
import 'widgets/profile_upcoming_events.dart';
import 'widgets/profile_topics.dart';
import 'widgets/profile_mutual_friends.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final UserID userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AsyncValue<UserProfile> profileAsync = const AsyncValue.loading();
  AsyncValue<List<InstanceMember>> rsvpsAsync = const AsyncValue.loading();
  AsyncValue<List<MyTopicMembership>> myTopicMembershipsAsync =
      const AsyncValue.loading();
  AsyncValue<List<UserProfile>> mutualsAsync = const AsyncValue.loading();
  final Map<TopicID, bool> pendingChanges = {};

  Future<void> _loadData() async {
    final supabase = ref.read(supabaseClientProvider);
    final profilesCache = ref.read(profilesCacheProvider.notifier);
    final topicsCache = ref.read(topicsCacheProvider.notifier);

    // load profile
    try {
      final profile = await profilesCache.getById(widget.userId);
      setState(() {
        profileAsync = AsyncValue.data(profile);
      });

      // load mutual friends
      if (profile.mutuals != null && profile.mutuals!.isNotEmpty) {
        try {
          final mutualsMap =
              await profilesCache.fetchProfiles(profile.mutuals!.toSet());
          setState(() {
            mutualsAsync = AsyncValue.data(mutualsMap.values.toList());
          });
        } catch (error, stackTrace) {
          setState(() {
            mutualsAsync = AsyncValue.error(error, stackTrace);
          });
        }
      } else {
        setState(() {
          mutualsAsync = const AsyncValue.data([]);
        });
      }

      // load RSVPs
      final rsvpsData = await supabase
          .from('instance_members')
          .select('*, instance!inner(*)')
          .eq('member', widget.userId)
          .inFilter('status', ['maybe', 'yes', 'omw']).gt(
              'instance.start_time_max', DateTime.now());

      final instancesData = rsvpsData
          .map((rsvpData) => rsvpData['instance'])
          .cast<Map<String, dynamic>>()
          .toList();

      // populate profile data
      await profilesCache.populateData(
          instancesData, [(idKey: 'created_by', modelKey: 'created_by')]);

      // populate topic data
      await topicsCache
          .populateData(instancesData, [(idKey: 'topic', modelKey: 'topic')]);

      setState(() {
        rsvpsAsync = AsyncValue.data(rsvpsData
            .map(InstanceMember.fromMap)
            .toList()
          ..sort((a, b) =>
              a.instance!.startTimeMax.compareTo(b.instance!.startTimeMax)));
      });

      // load topics
      try {
        final response = await supabase.functions.invoke('get-friend-profile',
            method: HttpMethod.get,
            queryParameters: {'user_id': widget.userId});

        final topicMembershipsData =
            response.data['topic_subscriptions'].cast<Map<String, dynamic>>();
        final populatedData = await topicsCache.populateData(
            topicMembershipsData, [(idKey: 'topic', modelKey: 'topic')]);
        populatedData
            .sort((a, b) => a['topic'].name.compareTo(b['topic'].name));

        setState(() {
          myTopicMembershipsAsync = AsyncValue.data(
              populatedData.map(MyTopicMembership.fromMap).toList());
        });
      } on FunctionException catch (error, stackTrace) {
        setState(() {
          myTopicMembershipsAsync = AsyncValue.error(
              Exception(error.details
                  .toString()
                  .replaceAll(RegExp(r'^[a-z\-]+: '), '')),
              stackTrace);
        });
      }
    } catch (error, stackTrace) {
      setState(() {
        profileAsync = AsyncValue.error(error, stackTrace);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _onTopicToggle(
      MyTopicMembership topicMembership, bool? value) async {
    // mark as pending
    setState(() {
      pendingChanges[topicMembership.topic.id!] = value == true;
    });

    // write to database
    try {
      final updatedTopicMembership = await ref
          .read(topicMembershipsProvider.notifier)
          .saveSubscribed(topicMembership, value == true);

      // update loaded memberships with created/updated one
      if (myTopicMembershipsAsync.value != null) {
        myTopicMembershipsAsync = AsyncValue.data(
            updateListWithRecord<MyTopicMembership>(
                myTopicMembershipsAsync.value!,
                (existing) => existing.topic == topicMembership.topic,
                updatedTopicMembership));
      }
    } catch (error) {
      loggerWithStack.e(error);
    }

    // unmark as pending
    setState(() {
      pendingChanges.remove(topicMembership.topic.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: profileAsync.when(
        data: (UserProfile profile) => profile.displayName,
        loading: () => '',
        error: (_, __) => 'Error loading profile',
      ),
      body: profileAsync.when(
        error: (error, __) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (UserProfile profile) => RefreshIndicator(
          onRefresh: () async {
            setState(() {
              profileAsync = const AsyncValue.loading();
              rsvpsAsync = const AsyncValue.loading();
              myTopicMembershipsAsync = const AsyncValue.loading();
              mutualsAsync = const AsyncValue.loading();
            });
            await _loadData();
          },
          child: CustomScrollView(
            slivers: [
              // Profile Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ProfileHeader(profile: profile),
                ),
              ),

              // Mutual Friends
              SliverToBoxAdapter(
                child: mutualsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (mutuals) => mutuals.isEmpty
                      ? const SizedBox.shrink()
                      : ProfileMutualFriends(mutuals: mutuals),
                ),
              ),

              // Upcoming Events
              SliverToBoxAdapter(
                child: rsvpsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (rsvps) => ProfileUpcomingEvents(rsvps: rsvps),
                ),
              ),

              // Topics
              SliverToBoxAdapter(
                child: myTopicMembershipsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (topics) => ProfileTopics(
                    topics: topics,
                    pendingChanges: pendingChanges,
                    onTopicToggle: _onTopicToggle,
                  ),
                ),
              ),

              // Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }
}
