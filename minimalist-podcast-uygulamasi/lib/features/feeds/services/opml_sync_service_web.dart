class OpmlSyncService {
  Future<String?> getFolderPath() async => null;

  Future<void> setFolderPath(String? path) async {}

  Future<String?> pickFolder() async => null;

  Future<String?> readOpmlFromFolder(String folderPath) async => null;

  Future<bool> shouldSync(String folderPath) async => false;

  Future<void> markSynced(String folderPath) async {}
}
