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

  static String get databasePath => _databasePath;
  static int get storageMegabytesPerCampaign => _storageMegabytesPerCampaign;
  static int get prefabsPerCampaign => _prefabsPerCampaign;
  static int get scenesPerCampaign => _scenesPerCampaign;
  static int get mapsPerCampaign => _mapsPerCampaign;
  static int get campaignsPerAccount => _campaignsPerAccount;
}
