mixin Upgradeable {
  Future<void> upgradeFromTo(int currentVersion, int targetVersion) async {
    for (var v = currentVersion + 1; v <= targetVersion; v++) {
      await applyVersion(targetVersion);
    }
  }

  Future<void> applyVersion(int targetVersion);
}
