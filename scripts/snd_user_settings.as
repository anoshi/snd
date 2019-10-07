// #include "user_settings.as"

// class SNDUserSettings : UserSettings {
// 	int m_difficulty = 0;
// 	int m_maxPlayers = 10;

// 	int m_minimumPlayersToStart = 2; //1;
// 	int m_minimumPlayersToContinue = 2; //1;

// 	float m_timeBetweenSubstages = 20.0;

// 	// search and destroy mode
// 	float m_sndMaxTime = 600.0;

// 	// koth mode
// 	float m_kothMaxTime = 900.0;
// 	float m_kothDefenseTime = 180.0;

// 	float m_quickmatchMaxTime = 3600.0;

// 	//string m_startServerCommand = "";


// 	// --------------------------------------------
// 	SNDUserSettings() {
// 		super();
// 	}

// 	// --------------------------------------------
// 	void fromXmlElement(const XmlElement@ settings) {
// 		if (settings.hasAttribute("continue")) {
// 			m_continue = settings.getBoolAttribute("continue");

// 		} else {
// 			m_savegame = settings.getStringAttribute("savegame");
// 			m_username = settings.getStringAttribute("username");
// 			if (settings.hasAttribute("difficulty")) {
// 				m_difficulty = settings.getIntAttribute("difficulty");
// 			}
// 			m_baseCaptureSystem = "single";

// 			if (m_difficulty == 0) {
// 				// Recruit
// 				m_fellowCapacityFactor = 1.0;
// 				m_fellowAiAccuracyFactor = 0.95;
// 				m_enemyCapacityFactor = 1.0;
// 				m_enemyAiAccuracyFactor = 0.96;
// 				m_xpFactor = 1.0;
// 				m_rpFactor = 1.0;
// 				m_fov = true;
// 			} else if (m_difficulty == 1) {
// 				// Professional
// 				m_fellowCapacityFactor = 1.0;
// 				m_fellowAiAccuracyFactor = 0.95;
// 				m_enemyCapacityFactor = 1.0;
// 				m_enemyAiAccuracyFactor = 0.98;
// 				m_xpFactor = 1.0;
// 				m_rpFactor = 1.0;
// 				m_fov = true;
// 			} else if (m_difficulty == 2) {
// 				// Veteran
// 				m_fellowCapacityFactor = 0.99;
// 				m_fellowAiAccuracyFactor = 0.95;
// 				m_enemyCapacityFactor = 1.0;
// 				m_enemyAiAccuracyFactor = 0.99;
// 				m_xpFactor = 1.0;
// 				m_rpFactor = 1.0;
// 				m_fov = true;
// 			}
// 			if (settings.hasAttribute("continue_as_new_campaign") && settings.getIntAttribute("continue_as_new_campaign") != 0) {
// 				m_continueAsNewCampaign = true;
// 			}
// 		}
// 	}

// 	// --------------------------------------------
// 	XmlElement@ toXmlElement(string name) const {
// 		// NOTE, won't serialize continue keyword, it only works as input
// 		XmlElement settings(name);

// 		settings.setStringAttribute("savegame", m_savegame);
// 		settings.setStringAttribute("username", m_username);
// 		settings.setIntAttribute("difficulty", m_difficulty);

// 		return settings;
// 	}

// 	// --------------------------------------------
// 	void print() const {
// 		_log(" ** SND: using savegame name: " + m_savegame);
// 		_log(" ** SND: using username: " + m_username);
// 		_log(" ** SND: using difficulty: " + m_difficulty);
// 		_log(" ** SND: using fov: " + m_fov);
// 		_log(" ** SND: using faction choice: " + m_factionChoice);

// 		// we can use this to provide difficulty settings, user faction, etc
// 		_log(" ** SND: using fellow capacity: " + m_fellowCapacityFactor);
// 		_log(" ** SND: using fellow ai accuracy: " + m_fellowAiAccuracyFactor);
// 		_log(" ** SND: using fellow ai reduction: " + m_playerAiReduction);
// 		_log(" ** SND: using enemy capacity: " + m_enemyCapacityFactor);
// 		_log(" ** SND: using enemy ai accuracy: " + m_enemyAiAccuracyFactor);
// 		_log(" ** SND: using xp factor: " + m_xpFactor);
// 		_log(" ** SND: using rp factor: " + m_rpFactor);

// 		_log(" ** SND: using initial xp: " + m_initialXp);
// 		_log(" ** SND: using initial rp: " + m_initialRp);
// 		//_log(" ** SND: using max rp: " + m_maxRp);

// 		_log(" ** SND: minimum players to start: " + m_minimumPlayersToStart);
// 		_log(" ** SND: minimum players to continue: " + m_minimumPlayersToContinue);
// 		_log(" ** SND: time between substages: " + m_timeBetweenSubstages);

// 		_log(" ** SND: snd max time: " + m_sndMaxTime);

// 		// _log(" ** SND: koth max time: " + m_kothMaxTime);
// 		// _log(" ** SND: koth max defense time: " + m_kothDefenseTime);
// 	}
// }
