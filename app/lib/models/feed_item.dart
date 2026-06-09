import 'activity.dart';
import 'message.dart';

/// A heterogeneous squad-timeline item (specs/screens/squads.md): an idea/activity
/// or a free-text message, tagged by the server's `type` field.
sealed class FeedItem {
  const FeedItem();

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      json['type'] == 'message'
      ? MessageFeedItem(Message.fromJson(json))
      : ActivityFeedItem(Activity.fromJson(json));
}

class ActivityFeedItem extends FeedItem {
  const ActivityFeedItem(this.activity);
  final Activity activity;
}

class MessageFeedItem extends FeedItem {
  const MessageFeedItem(this.message);
  final Message message;
}
