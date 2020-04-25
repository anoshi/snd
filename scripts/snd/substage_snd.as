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

		// reset the list of tracked character Ids
		array<int> trackedCharIds = m_metagame.getTrackedCharIds();
		for (uint i = 0; i < trackedCharIds.length; ++i) {
			m_metagame.removeTrackedCharId(trackedCharIds[i]);
		}

		// reset game's score display
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
		// (as|de|hr)_substage.as files pass winner to this method
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

		// declare winner or draw
		if (m_winner >= 0) {
			// declare winner
			Faction@ faction = m_match.m_factions[m_winner];
			sendFactionMessage(m_metagame, -1, "round winner " + faction.m_config.m_name + "!");
		} else {
			sendFactionMessage(m_metagame, -1, "the round is drawn");
		}

		string winWav = "";
		switch (m_winner) {
			case 0:
				winWav = "ctwin.wav";
				break;
			case 1:
				winWav = "terwin.wav";
				break;
			default:
				winWav = "rounddraw.wav";
		}
		playSound(m_metagame, winWav, -1);

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
