import 'dart:io';

import 'package:yaml/yaml.dart';

final _yamlConfigFile = File("config.yaml");
final _yamlConfig = _yamlConfigFile.existsSync()
    ? loadYaml(_yamlConfigFile.readAsStringSync())
    : {};

class DungeonClubConfig {
  static String? _configDatabasePath = _yamlConfig["database_path"];
  static int? _configStorageMegabytesPerCampaign =
      _yamlConfig["storage_megabytes_per_campaign"];
  static int? _configPrefabsPerCampaign = _yamlConfig["prefabs_per_campaign"];
  static int? _configScenesPerCampaign = _yamlConfig["scenes_per_campaign"];
  static int? _configMapsPerCampaign = _yamlConfig["maps_per_campaign"];
  static int? _configCampaignsPerAccount = _yamlConfig["campaigns_per_account"];

  static final String databasePath = _configDatabasePath ?? ".";
  static final int storageMegabytesPerCampaign =
      _configStorageMegabytesPerCampaign ?? 25;
  static final int prefabsPerCampaign = _configPrefabsPerCampaign ?? 100;
  static final int scenesPerCampaign = _configScenesPerCampaign ?? 20;
  static final int mapsPerCampaign = _configMapsPerCampaign ?? 10;
  static final int campaignsPerAccount = _configCampaignsPerAccount ?? 10;
}
