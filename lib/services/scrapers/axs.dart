import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:squadquest/models/instance.dart';

class AxsScraper {
  static bool canHandle(Uri url) {
    return (url.host == 'www.axs.com' || url.host == 'axs.com') &&
        url.path.startsWith('/events/');
  }

  static Future<Instance> scrape(Uri url) async {
    final response = await http.get(url, headers: {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load event page from AXS');
    }

    // Extract JSON-LD data
    final regex = RegExp(
        r'<script type="application\/ld\+json">(.*?)<\/script>',
        multiLine: true,
        dotAll: true);
    final match = regex.firstMatch(response.body);

    if (match == null) {
      throw Exception('Failed to find event data on page');
    }

    final jsonStr = match.group(1)!;
    final eventData = json.decode(jsonStr);

    if (eventData['@type'] != 'MusicEvent' && eventData['@type'] != 'Event') {
      throw Exception('Not a valid event page');
    }

    final startTime = DateTime.parse(eventData['startDate']);

    return Instance(
      title: eventData['name'] ?? 'Untitled Event',
      startTimeMin: startTime,
      startTimeMax: startTime.add(const Duration(minutes: 15)),
      endTime: eventData['endDate'] != null
          ? DateTime.parse(eventData['endDate'])
          : null,
      locationDescription: eventData['location']?['name'] ??
          eventData['location']?['address']?['addressLocality'] ??
          '',
      link: url,
      notes: eventData['description'],
      bannerPhoto: eventData['image'] != null
          ? Uri.parse(eventData['image'].toString().startsWith('//')
              ? 'https:${eventData['image']}'
              : eventData['image'])
          : null,
      visibility: InstanceVisibility.public,
    );
  }
}
