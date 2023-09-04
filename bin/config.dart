import 'dart:io';

import 'package:yaml/yaml.dart';

final _yamlConfig = loadYaml(File("config.yaml").readAsStringSync());

class DungeonClubConfig {
  static String _databasePath = _yamlConfig["database_path"] ?? ".";
  static int _storageMegabytesPerCampaign = _yamlConfig["storage_megabytes_per_campaign"] ?? 25;
  static int _prefabsPerCampaign = _yamlConfig["prefabs_per_campaign"] ?? 20;
  static int _scenesPerCampaign = _yamlConfig["scenes_per_campaign"] ?? 20;
  static int _mapsPerCampaign = _yamlConfig["maps_per_campaign"] ?? 10;
  static int _campaignsPerAccount = _yamlConfig["campaigns_per_account"] ?? 10;

  static String getDatabasePath() {
    return _databasePath;
  }

  static int getStorageMegabytesPerCampaign() {
    return _storageMegabytesPerCampaign;
  }

  static int getPrefabsPerCampaign() {
    return _prefabsPerCampaign;
  }

  static int getScenesPerCampaign() {
    return _scenesPerCampaign;
  }

  static int getMapsPerCampaign() {
    return _mapsPerCampaign;
  }

  static int getCampaignsPerAccount() {
    return _campaignsPerAccount;
  }
}
