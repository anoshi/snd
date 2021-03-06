#include "map_rotator_snd.as"
#include "safe_zone.as"
#include "stage_snd.as"
#include "warmup_substage.as"
#include "de_substage.as"
#include "hr_substage.as"
#include "as_substage.as"

// --------------------------------------------
class MapRotatorSNDAll : MapRotatorSND {

	MapRotatorSNDAll(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}
	// ------------------------------------------------------------------------------------------------
	protected void setupStages() {

		// array<uint> stages = {0, 1, 2};
		// uint stageType;
		// // random seed isn't initialised yet so this always generates the same order
		// while (stages.length() > 0) {
		// 	stageType = rand(0, stages.length() -1);
		// 	switch (stages[stageType]) {
		// 		case 0:
		// 			setupPlaylist1();
		// 			_log("** SND: loaded Assassination stages", 1);
		// 			break;
		// 		case 1:
		// 			setupPlaylist2();
		// 			_log("** SND: loaded Demolition stages", 1);
		// 			break;
		// 		case 2:
		// 			setupPlaylist3();
		// 			_log("** SND: loaded Hostage Rescue stages", 1);
		// 			break;
		// 		default:
		// 			_log("** SND: stageType " + stageType + " does not exist, break.", 1);
		// 			break;
		// 	}
		// 	stages.removeAt(stageType);
		// }

		setupPlaylist1();
		setupPlaylist2();
	}

	/////////////////////////////////////////
	// PLAYLIST 1 : AS, HR, DE, AS, HR, DE //
	/////////////////////////////////////////
	// ------------------------------------------------------------------------------------------------
	protected void setupPlaylist1() {
		int maxSoldiers = 0;
		// ------------------------------------------------------------------------------------------------
		{
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Islet of Eflen";
			stage.m_mapInfo.m_path = "media/packages/snd/maps/pvp1";
			stage.m_mapIndex = 13;

			stage.m_includeLayers.insertLast("bases.snd");
			stage.m_includeLayers.insertLast("layer1.hostageLocations");
			stage.m_includeLayers.insertLast("layer2.hostageLocations");
			stage.m_includeLayers.insertLast("layer1.targetLocations");
			stage.m_includeLayers.insertLast("layer2.targetLocations");
			stage.m_includeLayers.insertLast("layer3.snd");

			stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
			stage.m_factionConfigs.insertLast(m_factionConfigs[1]);

			// first is the warmup substage
			{
				// warmup only ends when there's enough players in the game or an admin decides,
				// by default 2 is enough
				SubStage@ substage = WarmupSubStage(stage, m_metagame.getUserSettings().m_minimumPlayersToStart);
				substage.m_mapViewOverlayFilename = "none.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}

				// add any initial commands here, can be used as modifiers e.g. for substage specific faction resources
				//substage.m_initCommands.insertLast("");
				@substage.m_match = @match;
			}

			// actual substages start here

			// ASSASSINATION
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = Assassination(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_as.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// HOSTAGE RESCUE
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = HostageRescue(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_hr.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// BOMB DEFUSAL
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = BombDefusal(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_de.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// ASSASSINATION
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = Assassination(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_as.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// HOSTAGE RESCUE
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = HostageRescue(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_hr.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// BOMB DEFUSAL
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = BombDefusal(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_de.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
       			match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			m_stages.insertLast(stage);
		}
	}

	/////////////////////////////////////////
	// PLAYLIST 2 : HR, AS, DE, HR, AS, DE //
	/////////////////////////////////////////
	// ------------------------------------------------------------------------------------------------
	protected void setupPlaylist2() {
		int maxSoldiers = 0;

		// ------------------------------------------------------------------------------------------------
		{
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Islet of Eflen";
			stage.m_mapInfo.m_path = "media/packages/snd/maps/pvp1";
			stage.m_mapIndex = 13;

			stage.m_includeLayers.insertLast("bases.snd");
			stage.m_includeLayers.insertLast("layer1.targetLocations");
			stage.m_includeLayers.insertLast("layer2.targetLocations");
			stage.m_includeLayers.insertLast("layer1.hostageLocations");
			stage.m_includeLayers.insertLast("layer2.hostageLocations");
			stage.m_includeLayers.insertLast("layer3.snd");

			stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
			stage.m_factionConfigs.insertLast(m_factionConfigs[1]);

			// first is the warmup substage
			{
				// warmup only ends when there's enough players in the game or an admin decides,
				// by default 2 is enough
				SubStage@ substage = WarmupSubStage(stage, m_metagame.getUserSettings().m_minimumPlayersToStart);
				substage.m_mapViewOverlayFilename = "none.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				// add any initial commands here, can be used as modifiers e.g. for substage specific faction resources
				//substage.m_initCommands.insertLast("");
				@substage.m_match = @match;
			}

			// actual substages start here

			// HOSTAGE RESCUE
			{
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = HostageRescue(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_hr.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
       			match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// ASSASSINATION
			{
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = Assassination(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_as.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// BOMB DEFUSAL
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = BombDefusal(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_de.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// HOSTAGE RESCUE
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = HostageRescue(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_hr.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// ASSASSINATION
			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = Assassination(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_as.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			// BOMB DEFUSAL
			{
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = BombDefusal(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_de.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 0;
				match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					faction.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
					faction.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
					faction.m_capacityMultiplier = 0.0001;
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			m_stages.insertLast(stage);
		}
	}
}
