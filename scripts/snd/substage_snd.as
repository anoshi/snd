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
		_log("** SND SubStage::start_match");

		sendFactionMessage(m_metagame, -1, m_displayName + " starts!");

		// clear game's score display
		m_metagame.resetScores();
		_log("** SND: Scoreboard Reset", 1);
		m_winner = -1;
		// add map view overlay to show safezone boundary and match/level type (AS/DE/HR)
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
			// sound bytes for ct / terrorist wins are fired via (bomb|hostage|vip)_tracker.as
			for (uint f = 0; f < m_match.m_factions.length(); ++f) {
				playSound(m_metagame, "rounddraw.wav", f);
			}
		}

		// finalise round scoring (RP rewards etc) and save out stats, ready to load for persistence into next subStage
		m_metagame.save();
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
