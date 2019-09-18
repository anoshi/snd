#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "snd_helpers.as"

// --------------------------------------------
class PlayerTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected array<string> playerHashes;	// stores the unique 'hash' for each active player
	protected array<float> playerScores;    // stores the

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

    // track alive players
       // alert when one side all dead (other side wins, all dead side loses --> cycle map)

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