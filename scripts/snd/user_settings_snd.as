#include "helpers.as"

// --------------------------------------------
class UserSettings {
	bool m_continue = false;
    bool m_continueAsNewCampaign = false;

    string m_savegame = "";
    string m_username = "unknown player";
    int m_factionChoice = 0;

    string m_baseCaptureSystem = "single";

    float m_fellowCapacityFactor = 0.99;
    float m_fellowAiAccuracyFactor = 0.95;
    float m_enemyCapacityFactor = 1.0;
    float m_enemyAiAccuracyFactor = 0.99;
    float m_xpFactor = 1.0;
    float m_rpFactor = 1.0;
    bool m_fov = true;

	float m_initialXp = 0.2000;				// XP is only used to allow CTs to add hostages and VIP to team
	int m_initialRp = 800;					// PlayerTracker assigns RP to each player on spawn
	int m_maxRp = 16000;					// hard limit on RP, as per CS
	int m_initialBandages = 2;				// players start each round with this many bandages
	string m_initialArmour = "std_armour"; 	// pvp healh system based on multi-layer vest as standard

    array<string> m_overlayPaths;

	int m_minimumPlayersToStart = 2;
	int m_minimumPlayersToContinue = 2;
	int m_maxPlayers = 10;

	float m_timeBetweenSubstages = 20.0;

	// search and destroy mode
	float m_sndMaxTime = 300.0;
	float m_quickmatchMaxTime = 300.0;

	string m_startServerCommand = "";

	// --------------------------------------------
	UserSettings() {
		m_overlayPaths.insertLast("media/packages/snd");
	}

	// --------------------------------------------
    void readSettings(const XmlElement@ settings) {
		if (settings.hasAttribute("continue")) {
			m_continue = settings.getBoolAttribute("continue");

		} else {
			m_savegame = settings.getStringAttribute("savegame");
			m_username = settings.getStringAttribute("username");
            m_factionChoice = settings.getIntAttribute("faction_choice");

            // could implement casual / comp modes (like CS) as 'difficulty', but I won't
			// if (settings.hasAttribute("difficulty")) {
			// 	m_difficulty = settings.getIntAttribute("difficulty");
			// }

			if (settings.hasAttribute("continue_as_new_campaign") && settings.getIntAttribute("continue_as_new_campaign") != 0) {
				m_continueAsNewCampaign = true;
			}
		}
	}

	// --------------------------------------------
	XmlElement@ toXmlElement(string name) const {
		// NOTE, won't serialize continue keyword, it only works as input
		XmlElement settings(name);

		settings.setStringAttribute("savegame", m_savegame);
		settings.setStringAttribute("username", m_username);
		settings.setIntAttribute("faction_choice", m_factionChoice);
		//settings.setIntAttribute("difficulty", m_difficulty);

		return settings;
	}

	// --------------------------------------------
	void print() const {
		_log(" ** SND: using savegame name: " + m_savegame);
		_log(" ** SND: using username: " + m_username);
		//_log(" ** SND: using difficulty: " + m_difficulty);
		_log(" ** SND: using fov: " + m_fov);
		_log(" ** SND: using faction choice: " + m_factionChoice);

		_log(" ** SND: using xp factor: " + m_xpFactor);
		_log(" ** SND: using rp factor: " + m_rpFactor);

		_log(" ** SND: using initial xp: " + m_initialXp);
		_log(" ** SND: using initial rp: " + m_initialRp);
		_log(" ** SND: using max rp: " + m_maxRp);

		_log(" ** SND: minimum players to start: " + m_minimumPlayersToStart);
		_log(" ** SND: minimum players to continue: " + m_minimumPlayersToContinue);
		_log(" ** SND: time between substages: " + m_timeBetweenSubstages);

		_log(" ** SND: snd max time: " + m_sndMaxTime);
	}
}
