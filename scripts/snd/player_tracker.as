#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "snd_helpers.as"

// --------------------------------------------
class PlayerTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected array<string> playerHashes;			// stores the unique 'hash' for each active player
	protected array<uint> factionPlayers = {0, 0}; 	// stores the number of active, alive players per faction

	protected array<dictionary> playerStats = {};

  	// dictionary dict = {{'one', 1}, {'object', object}, {'handle', @handle}};
	// // Examine and access the values through get or set methods ...
	// 	if( dict.exists('one') )
	// 	{
	// 	// get returns true if the stored type is compatible with the requested type
	// 	bool isValid = dict.get('handle', @handle);
	// 	if( isValid )
	// 	{
	// 		dict.delete('object');
	// 		dict.set('value', 1);
	// 	}
	// }

	// --------------------------------------------
	PlayerTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
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

		string pHash = player.getStringAttribute("profile_hash");

		bool newPlayer = true;
		for (uint i = 0; i < playerStats.length(); ++i) {
			dictionary curPlayer = playerStats[i];
			bool found = curPlayer.get('hash', pHash);
			if (found) {
				_log("** SND: player exists", 1);
				newPlayer = false;
				break;
			}
		}
		if (newPlayer) {
			_log("** SND: adding new player to playerStats array<dictionary>", 1);
			playerStats.insertLast(dictionary = {
				{ 'hash', pHash },
				{ 'name', player.getStringAttribute("name") },
				{ 'pId', player.getStringAttribute("player_id") },
				{ 'cId', player.getIntAttribute("character_id") },
				{ 'RP', 'unknown' },
				{ 'XP', 'unknown' }
			});
			_log("** SND: added a new player to playerStats dictionary!", 1);
			uint pSlen = playerStats.length() - 1;
			_log("** SND: " + (pSlen + 1) + " players stored in playerStats array vs " + playerHashes.length() + " in playerHashes array...", 1);
			dictionary dic = playerStats[pSlen];
			_log("** SND: Added player's name: " + string(dic['name']) + " ", 1);
		}
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
			m_metagame.addScore(factionId, -1);
		} else if (playerKiller.getIntAttribute("faction_id") == playerTarget.getIntAttribute("faction_id")) {
			// killed teammate
			_log("** SND: Player " + pKillerId+ " killed a friendly unit. Cash penalty and decrement score", 1);
			string penaliseTeamKills = "<command class='rp_reward' character_id='" + pKillerCharId + "' reward='-3300'></command>";
			m_metagame.getComms().send(penaliseTeamKills);
			m_metagame.addScore(factionId, -1);
		} else if (playerKiller.getIntAttribute("player_id") != playerTarget.getIntAttribute("player_id")) {
			// killed player on other team
			_log("** SND: Player " + pKillerId + " killed an enemy unit. Cash reward and increase score", 1);
			playSound(m_metagame, "enemydown.wav", factionId);
			string rewardEnemyKills = "<command class='rp_reward' character_id='" + pKillerCharId + "' reward='300'></command>";
			m_metagame.getComms().send(rewardEnemyKills);
			m_metagame.addScore(factionId, 2);
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

	// ----------------------------------------------------
	protected void updateFactionPlayerCounts(uint faction, int num) {
		if (factionPlayers[faction] + num > 0) {
			factionPlayers[faction] += num;
			_log("** SND: faction " + faction + " has " + num + " players alive", 1);
		} else {
			// first check we're still tracking character deaths
			if (!m_metagame.getTrackPlayerDeaths()) {
				// we're not, bail.
				return;
			}
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

	// --------------------------------------------
	void save(XmlElement@ root) {
		// called by /scripts/gamemodes/campaign/gamemode_snd.as
		XmlElement@ parent = root;

		XmlElement playerData("player_data");
		savePlayerData(playerData); // see protected method, below
		parent.appendChild(playerData);
	}

	// --------------------------------------------
	protected void savePlayerData(XmlElement@ playerData) {
		// writes <playerData> section to savegames/<savegame_name>.save/metagame_invasion.xml
		bool doSave = true;
		_log("** SND: saving playerData to metagame_invasion.xml", 1);

		// save player hashes and RP
		if (playerHashes.size() > 0) {
			XmlElement players("players");
			for (uint i = 0; i < playerHashes.size(); ++i) {
				if (playerHashes[i] == "") {
					// if any spawned player doesn't have an associated hash, we're not in a position to save data
					_log("** SND: Player " + i + " has no hash recorded. Skipping save.", 1);
					doSave = false;
					continue;
				} else {
					string pNum = "player" + (i + 1);
					XmlElement pData(pNum);
					pData.setStringAttribute("hash", playerHashes[i]);
					//pData.setIntAttribute("cash", m_playerRP[i]);
					players.appendChild(pData);
				}
			}
			if (doSave) {
				playerData.appendChild(players);
				_log("** SND: Player data saved to metagame_invasion.xml", 1);
			}
		} else {
			_log("** SND: no data in m_playersSpawned. No character info to save.", 1);
		}


		// any more info to add here? Create and populate another XmlElement and append to the playerData XmlElement
		// playerData.appendChild(another_XmlElement);
		_log("** SND: PlayerTracker::savePlayerData() done", 1);
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		_log("** SND: Loading Data", 1);
		// m_playerHashes.clear();
		// m_playerRP.clear();

		// const XmlElement@ playerData = root.getFirstElementByTagName("Search_and_Destroy");
		// if (playerData !is null) {
		// 	_log("** SND: loading level data", 1);
		// 	const XmlElement@ levelData = playerData.getFirstElementByTagName("level");
		// 	float levelProgress = levelData.getFloatAttribute("progress");
		// 	approachGoalXP(levelProgress);
		// 	_log("** SND: loading player data", 1); // tag elements (one element per saved player)
		// 	array<const XmlElement@> playerData = playerData.getElementsByTagName("players");
		// 	for (uint i = 0; i < playerData.size(); ++ i) {
		// 		_log("** SND: player" + (i + 1), 1); // load player[1..999] tag elements
		// 		array<const XmlElement@> curPlayer = playerData[i].getElementsByTagName("player" + (i + 1));

		// 		for (uint j = 0; j < curPlayer.size(); ++j) {
		// 			const XmlElement@ pData = curPlayer[i];
		// 			string hash = pData.getStringAttribute("hash");
		// 			m_playersSpawned.insertLast(hash);
		// 			int lives = pData.getIntAttribute("lives");
		// 			m_playerLives.insertLast(lives);
		// 			float score = pData.getFloatAttribute("score");
		// 			m_playerScore.insertLast(score);
		// 			_log("** SND: Score: " + score + ". Lives: " + lives, 1);
		// 		}
		// 	}
		// }
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