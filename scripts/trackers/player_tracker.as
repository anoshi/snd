#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "snd_helpers.as"

// --------------------------------------------
class PlayerTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected array<string> playerHashes;			// stores the unique 'hash' for each active player
	protected array<uint> factionPlayers = {0, 0}; 	// stores the number of active, alive players per faction
	protected array<float> playerScores;    		// TODO stores the scores of each player

    protected float m_localPlayerCheckTimer;
    protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	protected bool levelComplete;

	// --------------------------------------------
	PlayerTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
        levelComplete = false;
		// enable character_kill tracking for SND game mode (off by default)
		string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
	}

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

    // track alive players
       // alert when one side all dead (other side wins, all dead side loses --> cycle map)
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
		// profile_hash=ID2089185859
		// sid=ID0

		_log("** SND: PlayerTracker::handlePlayerDieEvent", 1);

		// skip die event processing if disconnected
		if (event.getBoolAttribute("combat") == false) return;

		// level already won/lost? bug out
		// if (levelComplete) {
		// 	_log("** SND: Level already won or lost. Dropping out of method", 1);
		// 	return;
		// }

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

	// --------------------------------------------
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
				} else {
					winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
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