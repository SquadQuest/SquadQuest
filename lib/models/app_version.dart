typedef AppBuild = int;

enum AppVersionChannel { web, android, ios, githubAPK, testflight }

class AppVersion {
  final AppBuild build;
  final String version;
  final DateTime released;
  final bool supported;
  final String? notices;
  final String? news;
  final List<AppVersionChannel> availability;

  AppVersion(
      {required this.build,
      required this.version,
      required this.released,
      required this.supported,
      required this.notices,
      required this.news,
      required this.availability});

  factory AppVersion.fromMap(Map<String, dynamic> map) {
    return AppVersion(
      build: map['build'] as AppBuild,
      version: map['version'] as String,
      released: DateTime.parse(map['released']).toLocal(),
      supported: map['supported'],
      notices: map['notices'],
      news: map['news'],
      availability: map['availability'] == null
          ? []
          : map['availability']
              .map((channel) => AppVersionChannel.values.firstWhere(
                    (e) => e.name == channel,
                  ))
              .toList()
              .cast<AppVersionChannel>(),
    );
  }

  @override
  String toString() {
    return 'AppVersion{build: $build, version: $version}';
  }
}
