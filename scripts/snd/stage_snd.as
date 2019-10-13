#include "tracker.as"

// internal
#include "metagame.as"
#include "map_info.as"
#include "query_helpers.as"

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

		m_metagame.setMapInfo(m_mapInfo);

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
			float time = m_metagame.getUserSettings().m_timeBetweenSubstages;
			m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame,time,true));
		}

		// start new map, using the task sequencer which includes the potential time wait task just added above
		_log("** SND: now running advanceToNextSubstage...", 1);
		m_metagame.getTaskSequencer().add(Call(CALL(this.advanceToNextSubstage)));
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
			start();
		}
	}
}

// --------------------------------------------
// SubStage works as a base class for specialized substages that define the actual mode logic
// - the stage rotates substages one by one, calling SubStage::start when it's time for SubStage to do its thing
// - substage itself defines how and when it ends; to get the stage advance to the next substage, the stage
//   must be notified with Stage::substage_ended call
abstract class SubStage : Tracker {
	protected GameModeSND@ m_metagame;
	protected Stage@ m_stage;
	// substage specific trackers
	protected array<Tracker@> m_trackers;

	protected array<string> m_initCommands;

	protected int m_winner = -1;

	// name is used a directory name, so avoid spaces and oddball characters
	string m_name = "unset_substage_name";
	// use display name as what is announced to players
	string m_displayName = "";

	Match@ m_match;
	string m_mapViewOverlayFilename = "none.png";

	protected bool m_started = false;
	protected bool m_ended = false;

	// --------------------------------------------
	SubStage(Stage@ stage) {
		// setup two-way connection between substage and stage
		@m_stage = @stage;
		m_stage.addSubstage(this);
		// cache metagame
		@m_metagame = m_stage.getMetagame();

		m_started = false;
		m_ended = false;
	}

	// --------------------------------------------
	// trackers added through this method are added in metagame at start_match
	void addTracker(Tracker@ tracker) {
		m_trackers.insertLast(tracker);
	}

	// --------------------------------------------
	void addInitCommand(string command) {
		m_initCommands.insertLast(command);
	}

	// --------------------------------------------
   	void startMatch() {
		_log("SubStage::start_match");

		sendFactionMessage(m_metagame, -1, m_displayName + " starts!");

		// clear game's score display
		for (uint i = 0; i < m_match.m_factions.length(); ++i) {
			int id = i;
			string command = "<command class='update_score_display' id='" + id + "' text='' />";
			m_metagame.getComms().send(command);
		}

		{
			string command = "<command class='update_score_display' max_text='' />";
			m_metagame.getComms().send(command);
		}

		m_winner = -1;

		{
			string command = "<command class='update_map_view' overlay_texture='" + m_mapViewOverlayFilename + "' />";
			m_metagame.getComms().send(command);
		}

		m_metagame.preBeginMatch();

		m_match.start();

		// wait here

		// substage itself is a tracker, add it
		m_metagame.addTracker(this);

		// create substage specific trackers:
		_log("** SND: active trackers: " + m_trackers.length());
		for (uint i = 0; i < m_trackers.length(); ++i) {
			m_metagame.addTracker(m_trackers[i]);
		}
		m_metagame.postBeginMatch();

		for (uint i = 0; i < m_initCommands.length(); ++i) {
			m_metagame.getComms().send(m_initCommands[i]);
		}
	}

	// --------------------------------------------
	void start() {
		m_started = true;
	}

	// --------------------------------------------
   	protected void setWinner(int winner) {
		m_winner = winner;
	}

	// --------------------------------------------
	void maxScoreReached(int winner) { }

	// --------------------------------------------
   	void end() {
		m_ended = true;

		// force respawn lock now
		for (uint i = 0; i < m_match.m_factions.length(); ++i) {
			int id = i;
			string command = "<command class='set_soldier_spawn' faction_id='" + id + "' enabled='0' />";
			m_metagame.getComms().send(command);
		}

		// make losing factions lose
		if (m_winner >= 0) {
			for (uint i = 0; i < m_match.m_factions.length(); ++i) {
				int id = i;
				if (id == m_winner) {
					continue;
				}

				string command = "<command class='set_match_status' faction_id='" + id + "' lose='1' />";
				m_metagame.getComms().send(command);
			}
			// declare winner(s)
			Faction@ faction = m_match.m_factions[m_winner];
			sendFactionMessage(m_metagame, -1, "round winner " + faction.m_config.m_name + "!");
		} else {
			sendFactionMessage(m_metagame, -1, "the round is a tie");
			// sound bytes for ct / terrorist wins are fired via bomb_tracker.as
			for (uint f = 0; f < m_match.m_factions.length(); ++f) {
				playSound(m_metagame, "rounddraw.wav", f);
			}
		}

		// record inventories of all players still alive

		// finalise round scoring (RP rewards etc)

		// save out stats, ready to load for persistence into next subStage

		// remove trackers added by this substage in order to make after-game events not register as game events
		for (uint i = 0; i < m_trackers.length(); ++i) {
			m_metagame.removeTracker(m_trackers[i]);
		}
		m_stage.substageEnded();
	}

	// --------------------------------------------
	bool hasEnded() const {
			return m_ended;
	}

	// --------------------------------------------
	bool hasStarted() const {
			return m_started;
	}

    // ----------------------------------------------------
	void update(float time) {
	}
}

// --------------------------------------------
// match-specific faction settings
class Faction {
	FactionConfig@ m_config;

	int m_bases = -1;

	float m_overCapacity = 0;
	int m_capacityOffset = 0;
	float m_capacityMultiplier = 0; //0.0001;

	// this is optional
	array<string> m_ownedBases;

	Faction(FactionConfig@ factionConfig) {
		@m_config = @factionConfig;
	}

	void makeNeutral() {
		m_capacityMultiplier = 0.0;
	}

	bool isNeutral() {
		return m_capacityMultiplier <= 0.0;
	}

	string getName() {
		return m_config.m_name;
	}
}


// --------------------------------------------
class Match {
	protected GameModeSND@ m_metagame;

	// default match settings, overridden on a per-map basis by map_rotator_snd_all.as
	int m_maxSoldiers = 0;
	float m_soldierCapacityVariance = 0.30;
	string m_soldierCapacityModel = "constant";
	float m_defenseWinTime = -1.0;
	string m_defenseWinTimeMode = "hold_bases";
	int m_playerAiCompensation = 0;
	int m_playerAiReduction = 5;
	string m_baseCaptureSystem = "any";

	array<Faction@> m_factions;

	float m_aiAccuracy = 0.94;

	float m_xpMultiplier = 1.0;
	float m_rpMultiplier = 1.0;

	// --------------------------------------------
	Match(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	const XmlElement@ getStartGameCommand(GameModeSND@ metagame) const {
		XmlElement command("command");
		command.setStringAttribute("class", "start_game");
		command.setStringAttribute("savegame", m_metagame.getUserSettings().m_savegame);
		command.setIntAttribute("vehicles", 1);
		command.setIntAttribute("max_soldiers", m_maxSoldiers);
		command.setFloatAttribute("soldier_capacity_variance", m_soldierCapacityVariance);
		command.setStringAttribute("soldier_capacity_model", m_soldierCapacityModel);
		command.setFloatAttribute("player_ai_compensation", m_playerAiCompensation);
		command.setFloatAttribute("player_ai_reduction", m_playerAiReduction);
		command.setFloatAttribute("xp_multiplier", m_xpMultiplier);
		command.setFloatAttribute("rp_multiplier", m_rpMultiplier);
		command.setFloatAttribute("initial_xp", m_metagame.getUserSettings().m_initialXp);
		command.setFloatAttribute("initial_rp", m_metagame.getUserSettings().m_initialRp);
		command.setFloatAttribute("max_rp", m_metagame.getUserSettings().m_maxRp);
		command.setStringAttribute("base_capture_system", m_baseCaptureSystem);
		command.setBoolAttribute("friendly_fire", true); // may want to go user-specified
		command.setBoolAttribute("clear_profiles_at_start", true);
		command.setBoolAttribute("fov", true);

		if (m_defenseWinTime >= 0) {
			command.setFloatAttribute("defense_win_time", m_defenseWinTime);
			command.setStringAttribute("defense_win_time_mode", m_defenseWinTimeMode);
		}

		for (uint i = 0; i < m_factions.size(); ++i) {
			Faction@ f = m_factions[i];
			XmlElement faction("faction");

			faction.setFloatAttribute("capacity_offset", 0);
			faction.setFloatAttribute("initial_over_capacity", 0);
			faction.setFloatAttribute("capacity_multiplier", 0.0001);

			faction.setFloatAttribute("ai_accuracy", m_aiAccuracy);

			if (i == 0 && f.m_ownedBases.size() > 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_ownedBases.size());
			} else if (f.m_bases >= 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_bases);
			}

			faction.setBoolAttribute("lose_without_bases", false);

			command.appendChild(faction);
		}

		{
			XmlElement player("local_player");
			player.setIntAttribute("faction_id", m_metagame.getUserSettings().m_factionChoice);
			player.setStringAttribute("username", m_metagame.getUserSettings().m_username);
			command.appendChild(player);
		}

		return command;
	}

	// --------------------------------------------
   	void start() {
		_log("Match::start");

		m_metagame.setFactions(m_factions);

		// start game
		const XmlElement@ startGameCommand = getStartGameCommand(m_metagame);
		m_metagame.getComms().send(startGameCommand);
	}

}
