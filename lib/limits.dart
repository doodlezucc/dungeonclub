import 'package:dungeonclub/dungeon_club_config.dart';

final campaignsPerAccount = DungeonClubConfig.getCampaignsPerAccount();
final scenesPerCampaign = DungeonClubConfig.getScenesPerCampaign();
final prefabsPerCampaign = DungeonClubConfig.getPrefabsPerCampaign();
final mapsPerCampaign = DungeonClubConfig.getMapsPerCampaign();
const movablesPerScene = 500;
const playersPerCampaign = 20;

final mediaBytesPerCampaign = DungeonClubConfig.getStorageMegabytesPerCampaign() * 1000 * 1000;
