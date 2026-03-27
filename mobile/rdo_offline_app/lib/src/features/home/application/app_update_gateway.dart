class AppUpdateInfo {
  const AppUpdateInfo({
    required this.available,
    required this.downloadUrl,
    required this.versionName,
    required this.buildNumber,
    required this.forceUpdate,
    this.minSupportedBuild,
    this.releaseNotes = '',
  });

  final bool available;
  final String downloadUrl;
  final String versionName;
  final int buildNumber;
  final bool forceUpdate;
  final int? minSupportedBuild;
  final String releaseNotes;
}

abstract class AppUpdateGateway {
  Future<AppUpdateInfo?> fetchLatestUpdate({String platform = 'android'});
}
