import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single source of truth for the active timeline context
/// (specs/behaviors/context-selector.md). Title, feed, audience indicator, and
/// compose destination all read this — they can never disagree.
sealed class ActiveContext {
  const ActiveContext();
}

class FriendsContext extends ActiveContext {
  const FriendsContext();
}

class SquadContext extends ActiveContext {
  const SquadContext(this.id, this.name);
  final String id;
  final String name;
}

final activeContextProvider =
    NotifierProvider<ActiveContextController, ActiveContext>(
      ActiveContextController.new,
    );

class ActiveContextController extends Notifier<ActiveContext> {
  @override
  ActiveContext build() => const FriendsContext();

  void toFriends() => state = const FriendsContext();
  void toSquad(String id, String name) => state = SquadContext(id, name);
}
