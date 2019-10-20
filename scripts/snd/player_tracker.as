#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "snd_helpers.as"

// --------------------------------------------
class PlayerTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected SubStage@ m_substage;

	protected array<string> playerHashes;			// stores the unique 'hash' for each active player
	protected array<uint> factionPlayers = {0, 0}; 	// stores the number of active, alive players per faction
	protected array<int> playerScores;

	// --------------------------------------------
	PlayerTracker(GameModeSND@ metagame, SubStage@ substage) {
		@m_metagame = @metagame;
		// setup two-way connection between PlayerTracker and SubStage
		@m_substage = @substage;
	}

	/////////////////////////////
	// Player tracking methods //
	/////////////////////////////

	// --------------------------------------------
	protected void handlePlayerConnectEvent(const XmlElement@ event) {
		// TagName=player_connect_event
		// TagName=player
		// color=0.595 0.476 0 1
		// faction_id=0
		// ip=123.120.169.132
		// name=ANOSHI
		// player_id=2
		// port=30664
		// profile_hash=ID<10_numbers>
		// sid=ID<8_numbers>

		_log("** SND: Processing Player connect request", 1);

		const XmlElement@ connector = event.getFirstElementByTagName("player");
		string connectorHash = connector.getStringAttribute("profile_hash");
		if (playerHashes.find(connectorHash) >= 0) {
			_log("** SND: current player rejoining", 1);
		} else if (int(playerHashes.size()) < m_metagame.getUserSettings().m_maxPlayers) {
            playerHashes.insertLast(connectorHash);
			_log("** SND: New player has joined. " + (m_metagame.getUserSettings().m_maxPlayers - int(playerHashes.size())) + " seats left in server", 1);
		} else {
            _log("** SND: New player joining, but no room left in server", 1);
        }
	}

	// -----------------------------------------------------------
    protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		// TagName=player_spawn
		// TagName=player
		// aim_target=0 0 0
		// character_id=74
		// color=0.595 0.476 0 1
		// faction_id=0
		// ip=117.20.69.32
		// name=ANOSHI
		// player_id=2
		// port=30664
		// profile_hash=ID<10_numbers>
		// sid=ID<8_numbers>

		_log("** SND: PlayerTracker::handlePlayerSpawnEvent", 1);

		const XmlElement@ player = event.getFirstElementByTagName("player");
		// increment live player count for faction
		updateFactionPlayerCounts(player.getIntAttribute("faction_id"), 1);
	}


	// --------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		_log("** SND: PlayerTracker Handling player disconnection!");
		const XmlElement@ disconnector = event.getFirstElementByTagName("player");
		// which faction were they playing as?
		int dcPlayerFaction = disconnector.getIntAttribute("faction_id");
		// decrement live player count for faction
		updateFactionPlayerCounts(disconnector.getIntAttribute("faction_id"), -1);
	}

	// -----------------------------------------------------------
	protected void handlePlayerKillEvent(const XmlElement@ event) {
		// TagName=player_kill
		// key=hand_grenade.projectile
		// method_hint=blast

		// TagName=killer
		// aim_target=589.214 7.54902 544.812
		// character_id=3
		// color=0.68 0.85 0 1
		// faction_id=0
		// ip=
		// name=player1
		// player_id=0
		// port=0
		// profile_hash=ID<10_numbers>
		// sid=ID0

		// TagName=target
		// aim_target=589.214 7.54902 544.812
		// character_id=3
		// color=0.68 0.85 0 1
		// faction_id=0
		// ip=
		// name=player1
		// player_id=0
		// port=0
		// profile_hash=ID<10_numbers>
		// sid=ID0

		const XmlElement@ playerKiller = event.getFirstElementByTagName("killer");
		const XmlElement@ playerTarget = event.getFirstElementByTagName("target");

		int factionId = playerKiller.getIntAttribute("faction_id");
		int pKillerId = playerKiller.getIntAttribute("player_id");
		int pKillerCharId = playerKiller.getIntAttribute("character_id");
		_log("** SND: Player scores: " + playerKiller.getStringAttribute("name") + ", faction " + factionId);

		if (playerKiller.getStringAttribute("profile_hash") == playerTarget.getStringAttribute("profile_hash")) {
			// killed self
			_log("** SND: Player " + pKillerId + " committed suicide. Decrement score", 1);
			// no cash penalty for suicide, just score
			addScore(factionId, -1);
		} else if (playerKiller.getIntAttribute("faction_id") == playerTarget.getIntAttribute("faction_id")) {
			// killed teammate
			_log("** SND: Player " + pKillerId+ " killed a friendly unit. Decrement score", 1);
			string penaliseTeamKills = "<command class='rp_reward' character_id='" + pKillerCharId + "' reward='-3300'></command>";
			m_metagame.getComms().send(penaliseTeamKills);
			addScore(factionId, -1);
		} else if (playerKiller.getIntAttribute("player_id") != playerTarget.getIntAttribute("player_id")) {
			// killed player on other team
			_log("** SND: Player " + pKillerId + " killed an enemy unit. Increase score", 1);
			playSound(m_metagame, "enemydown.wav", factionId);
			string rewardEnemyKills = "<command class='rp_reward' character_id='" + pKillerCharId + "' reward='300'></command>";
			m_metagame.getComms().send(rewardEnemyKills);
			addScore(factionId, 2);
		}
	}

	// -----------------------------------------------------------
	protected void handlePlayerDieEvent(const XmlElement@ event) {
		// TagName=player_die
		// combat=1

		// TagName=target
		// aim_target=557.315 7.54902 551.681
		// character_id=5
		// color=0.68 0.85 0 1
		// faction_id=0
		// ip=
		// name=Host
		// player_id=0
		// port=0
		// profile_hash=ID<10_numbers>
		// sid=ID0

		_log("** SND: PlayerTracker::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// enforce no respawning (1 life per round)
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint i = 0; i < allFactions.length(); ++i) {
			string noRespawnComm = "<command class='set_soldier_spawn' faction_id='" + i + "' enabled='0' />";
			m_metagame.getComms().send(noRespawnComm);
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");

		// use profile_hash stored in playerHashes array to id which char died
		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string playerHash = deadPlayer.getStringAttribute("profile_hash");
		int playerNum = playerHashes.find(playerHash); // will return the index or negative if not found
		_log("** SND: Player " + playerNum + " (character_id: " + playerCharId + ") has died.", 1);

		updateFactionPlayerCounts(deadPlayer.getIntAttribute("faction_id"), -1);
	}

    // // ----------------------------------------------------
	// protected void addScore(int factionId, int score) {
	// 	m_substage.addScore(factionId, score);

	// 	// will need to include the timer here
	// 	// if (m_gameTimer !is null) {
	// 	// 	// GameTimer controls who wins if time runs out, refresh it each time score changes
	// 	// 	m_gameTimer.setWinningTeam(m_scoreTracker.getWinningTeam());
	// 	// }
	// }

	// ----------------------------------------------------
	protected void updateFactionPlayerCounts(uint faction, int num) {
		if (factionPlayers[faction] + num > 0) {
			factionPlayers[faction] += num;
			_log("** SND: faction " + faction + " has " + num + " players alive", 1);
		} else {
			_log("** SND: faction " + faction + " has run out of live players. Lose round!", 1);
			string winLoseCmd = "";
			array<Faction@> allFactions = m_metagame.getFactions();
			for (uint f = 0; f < allFactions.length(); ++f) {
				// in this case, the faction sent to this method is the losing faction (no living players remain)
				if (f == faction) {
					winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' lose='1'></command>";
					array<int> losingTeamCharIds = getFactionPlayerCharacterIds(m_metagame, f);
					for (uint i = 0; i < losingTeamCharIds.length() ; ++i) {
						string rewardLosingTeamChar = "<command class='rp_reward' character_id='" + losingTeamCharIds[i] + "' reward='900'></command>"; // " + (900 + (consecutive * 500)) + " // up to a max of 3400 / round
						m_metagame.getComms().send(rewardLosingTeamChar);
					}
				} else {
					winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
					array<int> winningTeamCharIds = getFactionPlayerCharacterIds(m_metagame, f);
					for (uint i = 0; i < winningTeamCharIds.length() ; ++i) {
						string rewardWinningTeamChar = "<command class='rp_reward' character_id='" + winningTeamCharIds[i] + "' reward='3250'></command>";
						m_metagame.getComms().send(rewardWinningTeamChar);
					}
				}
				m_metagame.getComms().send(winLoseCmd);
				// sound byte to advise which team won
				if (faction == 0) {
					playSound(m_metagame, "terwin.wav", f);
				} else if (faction == 1) {
					playSound(m_metagame, "ctwin.wav", f);
				}
			}
		}
	}

	////////////////////////////
	// Score tracking methods //
	////////////////////////////
	// Bomb Defusal
	// 2 points for a bomb plant. (Terrorist Only)
	// 2 points if that bomb explodes. (Terrorist Only)
	// 2 points for a kill, 3 when bomb planted
	// 3 points for a kill when defending the bomb (Terrorist Only)
	// 1 point when bomb detonate and you are alive
	// 1 point when the bomb is defused and you are alive
	// 1 point for an assist.
	// 2 points for defusing a bomb. (Counter-Terrorist Only)
	// 2 points for rescuing a hostage. (Counter-Terrorist Only)
	// -1 point for killing a teammate.
	// -1 point for committing suicide.

	// --------------------------------------------
	void reset() {
		playerScores = array<int>(0);
		for (uint id = 0; id < m_substage.m_match.m_factions.length(); ++id) {
			// if faction is neutral or it's name is Bots, continue, do not display this faction's score
			Faction@ faction = m_substage.m_match.m_factions[id];

			playerScores.insertLast(0);

			string value = "0";
			string color = faction.m_config.m_color;
			string command = "<command class='update_score_display' id='" + id + "' text='" + value + "' color='" + color + "' />";
			m_metagame.getComms().send(command);
		}
	}

	// ----------------------------------------------------
	void addScore(int factionId, int score) {
		playerScores[factionId] += score;
		// update game's score display
		int value = playerScores[factionId];
		string command = "<command class='update_score_display' id='" + factionId + "' text='" + value + "' />";
		m_metagame.getComms().send(command);
		scoreChanged();
	}

	// ----------------------------------------------------
	protected void scoreChanged() {
		int score;
		for (uint i = 0; i < playerScores.length(); ++i) {
			score = playerScores[i];
		}

		string text = "";
		array<Faction@> factions = m_metagame.getFactions();
		for (uint i = 0; i < factions.length(); ++i) {
			Faction@ faction = factions[i];
			if (i != 0) {
				text += ", ";
			}
			text += faction.m_config.m_name + ": " + playerScores[i];
		}
		sendFactionMessage(m_metagame, -1, text);
	}

	// ----------------------------------------------------
	array<int> getScores() {
		return playerScores;
	}

	// ----------------------------------------------------
	string getScoresAsString() {
		string text = "";
		for (uint i = 0; i < playerScores.length(); ++i) {
			text += playerScores[i];
			if (i != playerScores.length() - 1) {
				text += " - ";
			}
		}

		return text;
	}

    // --------------------------------------------
	void start() {
		_log("** SND: starting PlayerTracker tracker", 1);
	}

	// --------------------------------------------
	bool hasEnded() const {
			// always on
			return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
			// always on
			return true;
	}

}