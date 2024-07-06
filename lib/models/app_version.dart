typedef AppBuild = int;

class AppVersion {
  final AppBuild build;
  final String version;
  final DateTime released;
  final bool supported;
  final String? notices;
  final String? news;

  AppVersion(
      {required this.build,
      required this.version,
      required this.released,
      required this.supported,
      required this.notices,
      required this.news});

  factory AppVersion.fromMap(Map<String, dynamic> map) {
    return AppVersion(
      build: map['build'] as AppBuild,
      version: map['version'] as String,
      released: DateTime.parse(map['released']).toLocal(),
      supported: map['supported'],
      notices: map['notices'],
      news: map['news'],
    );
  }

  @override
  String toString() {
    return 'AppVersion{build: $build, version: $version}';
  }
}
