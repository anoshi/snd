#include "tracker.as"

// internal
#include "metagame.as"
#include "map_info.as"
#include "query_helpers.as"

// snd
#include "substage_snd.as"
#include "faction_snd.as"
#include "match_snd.as"

// generic trackers
#include "map_rotator.as"

// --------------------------------------------
class Stage {
	protected GameModeSND@ m_metagame;
	protected MapRotatorSND@ m_mapRotator;

	MapInfo@ m_mapInfo;
	int m_mapIndex = -1;

	// factions involved in this stage,
	array<FactionConfig@> m_factionConfigs;

	array<string> m_includeLayers;

	protected array<SubStage@> m_substages;
	protected uint m_currentSubStageIndex = 0;

	array<string> m_resourcesToLoad;

	// --------------------------------------------
	Stage(GameModeSND@ metagame, MapRotatorSND@ mapRotator) {
		@m_metagame = @metagame;
		@m_mapRotator = @mapRotator;
		@m_mapInfo = MapInfo();

		m_resourcesToLoad.insertLast("<weapon file='all_weapons.xml' />");
		m_resourcesToLoad.insertLast("<projectile file='all_throwables.xml' />");
		m_resourcesToLoad.insertLast("<call file='all_calls.xml' />");
		m_resourcesToLoad.insertLast("<carry_item file='all_carry_items.xml' />");
		m_resourcesToLoad.insertLast("<vehicle file='all_vehicles.xml' />");
	}

	// --------------------------------------------
	void addSubstage(SubStage@ subStage) {
		m_substages.insertLast(subStage);
	}

	// --------------------------------------------
	GameModeSND@ getMetagame() {
		return m_metagame;
	}

	// --------------------------------------------
	int getCurrentSubStageIndex() {
		return m_currentSubStageIndex;
	}

	// --------------------------------------------
	SubStage@ getCurrentSubStage() {
		return m_substages[m_currentSubStageIndex];
	}

	// --------------------------------------------
	string getChangeMapCommand() {
		string mapConfig = "<map_config>\n";

		for (uint i = 0; i < m_includeLayers.length(); ++i) {
			mapConfig += "<include_layer name='" + m_includeLayers[i] + "' />\n";
		}

		for (uint i = 0; i < m_factionConfigs.length(); ++i) {
			mapConfig += "<faction file='" + m_factionConfigs[i].m_file + "' />\n";
		}

		for (uint i = 0; i < m_resourcesToLoad.length(); ++i) {
			mapConfig += m_resourcesToLoad[i] + "\n";
		}

		mapConfig += "</map_config>\n";

		string overlays = "";

		for (uint i = 0; i < m_metagame.getUserSettings().m_overlayPaths.length(); ++i) {
			string path = m_metagame.getUserSettings().m_overlayPaths[i];
			_log("adding overlay " + path);
			overlays += "<overlay path='" + path + "' />\n";
		}

		string changeMapCommand =
			"<command class='change_map'" +
			"	map='" + m_mapInfo.m_path + "'>" +
			overlays +
			mapConfig +
			"</command>";

		return changeMapCommand;
	}

	// --------------------------------------------
	void start() {
		_log("Stage::start");

		m_metagame.getComms().clearQueue();

		m_metagame.setMapInfo(m_mapInfo);
		for (uint i = 0; i < m_factionConfigs.length(); ++i) {
			m_metagame.setFactionPlayerCount(i, 0);
		}
		SubStage@ substage = getCurrentSubStage();

		// call substage to start the match
		// - does pre/post match in metagame clearing old trackers
		// - starts the match in server
		// - adds substage specific trackers in metagame, and self
		substage.startMatch();
	}

	// --------------------------------------------
	void substageEnded() {
		_log("Stage::substage_ended");

		// prepare to start next substage, allow a moment to read messages and chat
		if (m_currentSubStageIndex == m_substages.length() - 1) {
			_log("** SND: at last substage. No time delay before advancing to next round", 1);
			// if we are at the last substage, do insta-advance in order to begin changing the stage which includes waiting
		} else {
			// not at last substage yet
			_log("** SND: NOT at last substage. Announce time delay and countdown before advancing to next round", 1);
			int time = int(m_metagame.getUserSettings().m_timeBetweenSubstages);
			for (int timer = time; timer > 0; --timer) {
				if (timer % 5 == 0) {
					sendFactionMessage(m_metagame, -1, "starting in " + timer + " seconds");
				}
				sleep(1);
			}
		}
		// start new map immediately or after delay, as dictated above
		_log("** SND: now running advanceToNextSubstage...", 1);

		// to overcome timer bug, just manually push the advance instead of relying on getTaskSequencer to work
		// suggests something is clearing the task list that contains the task that is counting down before executing ...
		advanceToNextSubstage();
	}

	// --------------------------------------------
	void advanceToNextSubstage() {
		// rotate to next substage
		m_currentSubStageIndex++;
		if (m_currentSubStageIndex >= m_substages.length()) {
			_log("all substages completed");
			// inform the map rotator that we're done
			// stageEnded() does not exist in map_rotator.as
			m_mapRotator.stageEnded();
		} else {
			_log("next substage: " + m_currentSubStageIndex);
			// if index is 1, reset all player's XP and RP to starting values
			bool isFirstSubStage = m_currentSubStageIndex == 1;
			m_metagame.setIsFirstSubStage(isFirstSubStage);
			start();
		}
	}
}
