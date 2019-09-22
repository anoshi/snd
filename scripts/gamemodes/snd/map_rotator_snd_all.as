#include "map_rotator_snd.as"
#include "safe_zone.as"
#include "stage_snd.as"
#include "warmup_substage.as"
#include "snd_substage.as"


// --------------------------------------------
class MapRotatorSNDAll : MapRotatorSND {

	MapRotatorSNDAll(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}
	// ------------------------------------------------------------------------------------------------
	protected void setupStages() {
		setupPlaylist1();
		// setupPlaylist2();
		// setupPlaylist3();
		// setupPlaylist4();
	}

	// just the one playlist for now is heeeeaps
	// ------------------------------------------------------------------------------------------------
	protected void setupPlaylist1() {
		int maxSoldiers = 10;

		// ------------------------------------------------------------------------------------------------
		{
			Stage@ stage = createStage();
			stage.m_mapInfo.m_name = "Islet of Eflen";
			stage.m_mapInfo.m_path = "media/packages/snd/maps/pvp1";
			stage.m_mapIndex = 13;

			stage.m_includeLayers.insertLast("bases.default");
			stage.m_includeLayers.insertLast("layer1.targetLocations");

			stage.m_factionConfigs.insertLast(m_factionConfigs[0]);
			stage.m_factionConfigs.insertLast(m_factionConfigs[1]);
			// neutral/bots too
			stage.m_factionConfigs.insertLast(m_factionConfigs[2]);

			// examples of different kind of matches=sub gamemodes:
			// - team deathmatch
			// - koth
			// - deliver vehicle/ambush
			// - deliver item/ambush
			// - deliver character/ambush
			// - assault/defend
			// - destroy target/defend

			// each match class can support variety of settings,
			// e.g.
			// - which bases the factions own as starting point,
			// - which resources are available
			// - timers
			// - targets
			// - ...

			// first is the warmup substage
			{
				// warmup only ends when there's enough players in the game or an admin decides,
				// by default 2 is enough
				SubStage@ substage = WarmupSubStage(stage, m_metagame.getUserSettings().m_minimumPlayersToStart);
				substage.m_mapViewOverlayFilename = "none.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 2;
        		match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[2]);
					faction.makeNeutral();
					match.m_factions.insertLast(faction);
				}
				// add any initial commands here, can be used as modifiers e.g. for substage specific faction resources
				//substage.m_initCommands.insertLast("");
				@substage.m_match = @match;
			}

			// actual substages start here
			{
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				int maxScore = m_metagame.getUserSettings().m_sndMaxScore;
				SubStage@ substage = SNDSubStage(stage, maxTime);


				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 2;
        		match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[2]);
					faction.makeNeutral();
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				int maxScore = m_metagame.getUserSettings().m_sndMaxScore;
				SubStage@ substage = SNDSubStage(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_koth1.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 2;
        		match.m_playerAiReduction = 2;
				// KothSubStage will fill defense win timer
				match.m_baseCaptureSystem = "any";

				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[2]);
					faction.makeNeutral();
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "koth1"));
			}

			{
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				int maxScore = m_metagame.getUserSettings().m_sndMaxScore;
				SubStage@ substage = SNDSubStage(stage, maxTime);
				substage.m_mapViewOverlayFilename = "pvp1_overlay_th1.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 2;
        		match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("East Coast");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[2]);
					faction.m_capacityMultiplier = 0.0001;
					//faction.makeNeutral();
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addInitCommand("<command class='commander_ai' active='0' />");

				substage.addTracker(SafeZone(m_metagame, "th1"));
			}

			{
				// the map has declared some additional stuff for the substage, matched with a tag
				float maxTime = m_metagame.getUserSettings().m_sndMaxTime;
				int maxScore = m_metagame.getUserSettings().m_sndMaxScore;
				SubStage@ substage = SNDSubStage(stage, maxTime);


				substage.m_mapViewOverlayFilename = "pvp1_overlay_tdm1.png";

				Match@ match = Match(m_metagame);
				match.m_maxSoldiers = maxSoldiers;
				match.m_soldierCapacityModel = "constant";
				match.m_playerAiCompensation = 2;
       			match.m_playerAiReduction = 2;
				match.m_baseCaptureSystem = "none";
				{
					Faction@ faction = Faction(m_factionConfigs[0]);
					faction.m_ownedBases.insertLast("East Coast");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[1]);
					faction.m_ownedBases.insertLast("Heel Quarter");
					match.m_factions.insertLast(faction);
				}
				{
					Faction@ faction = Faction(m_factionConfigs[2]);
					faction.makeNeutral();
					match.m_factions.insertLast(faction);
				}
				@substage.m_match = @match;

				substage.addTracker(SafeZone(m_metagame, "tdm2"));
			}

			m_stages.insertLast(stage);
		}
	}
}
