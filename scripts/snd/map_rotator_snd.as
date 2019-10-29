// internal
#include "tracker.as"
#include "map_info.as"
#include "log.as"
#include "announce_task.as"
#include "generic_call_task.as"
#include "time_announcer_task.as"

// generic trackers
#include "map_rotator.as"
#include "stage_snd.as"

// --------------------------------------------
class MapRotatorSND : MapRotator {
	GameModeSND@ m_metagame;
	array<Stage@> m_stages;
	dictionary m_stagesCompleted;
	bool m_loop = true;
	array<FactionConfig@> m_factionConfigs;

	int m_currentStageIndex;

	MapRotatorSND() { }

	MapRotatorSND(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void setLoop(bool loop) {
		m_loop = loop;
	}

	// --------------------------------------------
	void init() {
		setupFactionConfigs();
		setupStages();
	}

	// --------------------------------------------
	protected array<FactionConfig@> getAvailableFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs;

		availableFactionConfigs.push_back(FactionConfig(-1, "counter_terrorist.xml", "Counter Terrorists", "0.1 0.1 0.4"));
		availableFactionConfigs.push_back(FactionConfig(-1, "terrorist.xml", "Terrorists", "0.4 0.3 0.1"));

		return availableFactionConfigs;
	}

	// --------------------------------------------
	protected void setupFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs = getAvailableFactionConfigs();

		int index = 0;
		while (availableFactionConfigs.length() > 0) {
			int availableIndex = 0;

			FactionConfig@ factionConfig = availableFactionConfigs[availableIndex];
			_log("setting " + factionConfig.m_name + " as index " + index);
			factionConfig.m_index = index;

			m_factionConfigs.insertLast(factionConfig);

			// removes the first item in array
			availableFactionConfigs.removeAt(0);

			index++;
		}

		// - finally add neutral / protectors
		{
			index = m_factionConfigs.length();
			m_factionConfigs.insertLast(FactionConfig(index, "brown.xml", "Bots", "0 0 0"));
		}

		_log("total faction configs " + m_factionConfigs.length());
	}

	// --------------------------------------------
	protected Stage@ createStage() {
		return Stage(m_metagame, this);
	}

	// --------------------------------------------
	protected void setupStages() {
		// override this in derived classes to set up stages and substages for rotation
		// in PvPvE, a stage defines the map + the resources to load and the substages that will take place in that map
		// the substages define the match / round logic and faction settings
	}

	// -------------------------------------------
	protected void waitAndStart(int time = 30, bool sayCountdown = true) {
		int previousStageIndex = m_currentStageIndex;

		// share some information with the server (and thus clients)
		int index = getNextStageIndex();
		string mapName = getMapName(index);

		_log("previous stage index " + previousStageIndex + ", next stage index " + index);

		// wait a while, and let server announce a few things
		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, time, sayCountdown));

		if (previousStageIndex != index) {
			// start new map
			m_metagame.getTaskSequencer().add(CallInt(CALL_INT(this.startMapEx), index));
		} else {
			// restart same map
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));
		}
	}

	// --------------------------------------------
	protected void readyToAdvance() {
		if (m_stagesCompleted.getSize() == m_stages.length()) {
			_log("all stages completed, request for restart");
			sleep(2);

			m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 30, true));
			m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));

		} else {
			waitAndStart();
		}
	}

	// --------------------------------------------
	protected int getStageCount() {
		return m_stages.length();
	}

	// --------------------------------------------
	protected string getMapName(int index) {
		return m_stages[index].m_mapInfo.m_name;
	}

	// --------------------------------------------
	protected string getChangeMapCommand(int index) {
		return m_stages[index].getChangeMapCommand();
	}

	// --------------------------------------------
	protected const XmlElement@ getStartGameCommand(GameModeSND@ metagame) {
		// note, get_start_game_command doesn't make sense in this rotator, and isn't used
		XmlElement command("");
		return command;
	}

	// --------------------------------------------
	protected int getNextStageIndex() const {
		//return m_stagesCompleted.getSize();
		array<string> stages = m_stagesCompleted.getKeys();
		array<int> completedStageIndices;
		for (uint i = 0; i < stages.length(); ++i) {
			completedStageIndices.insertLast(parseInt(stages[i]));
		}
        return pickRandomMapIndex(getStageCount(), completedStageIndices);
	}

	// --------------------------------------------------------
	protected bool isStageCompleted(int index) {
		// if Find finds the value in array, it will return a value >= 0
		return (m_stagesCompleted.exists(formatInt(index)));
	}

	// --------------------------------------------------------
	protected Stage@ getCurrentStage() {
		return m_stages[m_currentStageIndex];
	}

	// --------------------------------------------
    void startMapEx(int index) {
		startMap(index);
	}

	// --------------------------------------------
	void startMap(int index, bool beginOnly = false) {
		_log("start_map, index=" + index + ", begin_only=" + beginOnly);

		Stage@ stage = m_stages[index];
		m_currentStageIndex = index;

		if (!beginOnly) {
			// change map
			string changeMapCommand = getChangeMapCommand(index);
			m_metagame.getComms().send(changeMapCommand);
		}

		// note, get_start_game_command doesn't make sense in this rotator, and isn't used
		stage.start();
	}

	// --------------------------------------------
   	void restartMap() {
		int index = m_currentStageIndex;
		_log("restart_map, index=" + index);

		Stage@ stage = m_stages[index];
		stage.start();
	}

	// --------------------------------------------
	void stageEnded() {
		m_stagesCompleted[formatInt(m_currentStageIndex)] = true;

		// rotate to next map
		readyToAdvance();
	}

	// --------------------------------------------
	protected void handleMatchEndEvent(const XmlElement@ event) {
		// override the default MapRotator behavior;
		// don't do anything here, it's up to substages
	}

	// ----------------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		// first stage is the stage where we go back to if player count goes below a threshold,
		// thus doesn't make sense to check this while in that first stage
		Stage@ stage = getCurrentStage();
		if (stage.getCurrentSubStageIndex() > 0) {
			int players = getPlayerCount(m_metagame);
			if (players < m_metagame.getUserSettings().m_minimumPlayersToContinue) {
				// time to reset
				m_metagame.requestRestart();
			}
		}
	}
}
