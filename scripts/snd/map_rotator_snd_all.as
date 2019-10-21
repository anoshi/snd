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
		setupPlaylist1();
		setupPlaylist2();
		// setupPlaylist3();
		// setupPlaylist4();
	}

	/////////////////////////////////
	// PLAYLIST 1 : HR, DE, HR, DE //
	/////////////////////////////////
	// ------------------------------------------------------------------------------------------------
	protected void setupPlaylist1() {
		int maxSoldiers = 0;
		// ------------------------------------------------------------------------------------------------
		{
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Islet of Eflen";
			stage.m_mapInfo.m_path = "media/packages/snd/maps/pvp1";
			stage.m_mapIndex = 13;

			stage.m_includeLayers.insertLast("bases.default");
			stage.m_includeLayers.insertLast("layer1.hostageLocations");
			stage.m_includeLayers.insertLast("layer2.hostageLocations");
			stage.m_includeLayers.insertLast("layer1.targetLocations");
			stage.m_includeLayers.insertLast("layer2.targetLocations");

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
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = Assassination(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				SubStage@ substage = HostageRescue(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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

	/////////////////////////////////
	// PLAYLIST 2 : HR, DE, HR, DE //
	/////////////////////////////////
	// ------------------------------------------------------------------------------------------------
	protected void setupPlaylist2() {
		int maxSoldiers = 0;

		// ------------------------------------------------------------------------------------------------
		{
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Islet of Eflen";
			stage.m_mapInfo.m_path = "media/packages/snd/maps/pvp1";
			stage.m_mapIndex = 13;

			stage.m_includeLayers.insertLast("bases.default");
			stage.m_includeLayers.insertLast("layer1.targetLocations");
			stage.m_includeLayers.insertLast("layer2.targetLocations");
			stage.m_includeLayers.insertLast("layer1.hostageLocations");
			stage.m_includeLayers.insertLast("layer2.hostageLocations");

			stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
			stage.m_factionConfigs.insertLast(m_factionConfigs[1]);
			// neutral/bots too
			//stage.m_factionConfigs.insertLast(m_factionConfigs[2]);

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

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
