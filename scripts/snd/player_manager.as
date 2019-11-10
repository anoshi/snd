#include "tracker.as"
#include "log.as"
#include "helpers.as"

//////////////////////////////////
// Each player is a game object //
//////////////////////////////////
// --------------------------------------------
class SNDPlayer {
	string m_username = "";
	string m_hash = "";
	string m_sid = "ID0";
	string m_ip = "";

	int m_rp;
	float m_xp;
	XmlElement m_kit("equipment");

	int m_playerId = -1;	// the 'player_id'. Value positive only when player is in-game
	int m_charId = -1;		// the 'character_id' of the player. Value positive only when player is in-game

	// --------------------------------------------
	SNDPlayer(string username, string hash, string sid, string ip, int id, XmlElement@ inv=kit("equipment")) {
		m_username = username;
		m_hash = hash;
		m_sid = sid;
		m_ip = ip;
		m_playerId = id;
		m_kit.appendChild(inv);
	}

	// --------------------------------------------
	string getKey() const {
		return m_sid;
	}
}

//////////////////////////////////////////////
// Store all player objects in a dictionary //
//////////////////////////////////////////////
// --------------------------------------------
class SNDPlayerStore {
	protected PlayerTracker@ m_playerTracker;
	protected string m_name; // name of the storage container e.g. 'goodGuys', 'faction3'...
	protected dictionary m_players;

	// --------------------------------------------
	SNDPlayerStore(PlayerTracker@ playerTracker, string name) {
		@m_playerTracker = @playerTracker;
		m_name = name;
	}

	// --------------------------------------------
	array<string> getKeys() const {
		return m_players.getKeys();
	}

	// --------------------------------------------
	bool exists(string key) const {
		return m_players.exists(key);
	}

	// --------------------------------------------
	SNDPlayer@ get(string key) const {
		SNDPlayer@ player;
		m_players.get(key, @player);
		return player;
	}

	// --------------------------------------------
	void add(SNDPlayer@ player) {
		_log("** SND: PlayerTracker, " + m_name + ": add, player=" + player.m_username + ", hash=" + player.m_hash + ", player count before=" + m_players.size() + ", sid=" + player.m_sid);
		m_players.set(player.m_sid, @player);
	}

	// --------------------------------------------
	void remove(SNDPlayer@ player) {
		int s = size();
		m_players.erase(player.m_sid);
		if (size() != s) {
			_log("** SND: PlayerTracker, " + m_name + ": remove, player=" + player.m_username + ", sid=" + player.m_sid);
		}
	}

	// --------------------------------------------
	void addPlayersToSave(XmlElement@ root) {
		for (uint i = 0; i < m_players.getKeys().size(); ++i) {
			string sid = m_players.getKeys()[i];
			_log("** SND: Saving player " + sid, 1);
			SNDPlayer@ player = get(sid);
			XmlElement savedPlayer("player");
			savedPlayer.setStringAttribute("username", player.m_username);
			savedPlayer.setStringAttribute("hash", player.m_hash);
			savedPlayer.setStringAttribute("sid", player.m_sid);
			savedPlayer.setStringAttribute("ip", player.m_ip);
			savedPlayer.setIntAttribute("rp", player.m_rp);
			savedPlayer.setFloatAttribute("xp", player.m_xp);
			savedPlayer.appendChild(player.m_kit); // add sub element contaning inventory
			root.appendChild(savedPlayer);
			_log("** SND: Saved player " + i + " " + player.m_username, 1);
		}
	}

	// --------------------------------------------
	int size() const {
		return m_players.size();
	}

	// --------------------------------------------
	void clear() {
		m_players = dictionary();
	}
}

// --------------------------------------------
class PlayerTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected array<uint> factionPlayers = {0, 0}; 	// stores the number of active, alive players per faction
	protected dictionary cidTosid = {};				// maps player character_ids to SIDs

	protected string FILENAME = "snd_players.xml";	// file name to store player data in
	protected SNDPlayerStore@ m_trackedPlayers;		// active players in the server
	protected SNDPlayerStore@ m_savedPlayers;		// stores inactive players' stats (in 'appdata'/FILENAME), allows drop in/out of server over time

	protected array<uint> dropEvents;				// stores character_ids that have been associated with an ItemDropEvent since last check in.

	protected float playerCheckTimer = 15.0;		// initial delay at round start before starting player stat and inventory checks
	protected float CHECK_IN_INTERVAL = 5.0; 		// must be less than UserSettings.m_timeBetweenSubstages

	// --------------------------------------------
	PlayerTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
		@m_trackedPlayers = SNDPlayerStore(this, "tracked");
		@m_savedPlayers = SNDPlayerStore(this, "persistent");
		load();
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

		const XmlElement@ conn = event.getFirstElementByTagName("player");
		if (conn !is null) {
			string connName = conn.getStringAttribute("name");
			string connHash = conn.getStringAttribute("profile_hash");
			string key = conn.getStringAttribute("sid");
			int connId = conn.getIntAttribute("player_id");
			string connIp = conn.getStringAttribute("ip");

			if (int(m_trackedPlayers.size()) < m_metagame.getUserSettings().m_maxPlayers) {
				_log("** SND: Player " + connName + " has joined. " + (m_metagame.getUserSettings().m_maxPlayers - int(m_trackedPlayers.size() + 1)) + " seats left in server", 1);

				// if (key != "ID0") { // local player receives ID0
					if (m_savedPlayers.exists(key)) {
						SNDPlayer@ aPlayer;
						@aPlayer = m_savedPlayers.get(key);
						_log("** SND: known player " + aPlayer.m_username + " rejoining server", 1);
						// sanity check the known player's RP and XP
						_log("\t RP: " + aPlayer.m_rp, 1);
						_log("\t XP: " + aPlayer.m_xp, 1);
						aPlayer.m_username = connName;
						aPlayer.m_ip = connIp;
						aPlayer.m_playerId = connId;
						m_trackedPlayers.add(aPlayer);
						m_savedPlayers.remove(aPlayer);
					} else {
						// assign stock starter kit
						// TODO: getPlayerInventory(this player's character_id)
						XmlElement kit("equipment"); // placeholder
						SNDPlayer@ aPlayer = SNDPlayer(connName, connHash, key, connIp, connId, kit);
						_log("** SND: Unknown/new player " + aPlayer.m_username + " joining server", 1);
						// set RP and XP for new players
						aPlayer.m_rp = 800;		// starting cash for CS rounds
						aPlayer.m_xp = 0.2000;	// grant enough XP to allow VIP and 2 x hostage escorts
						m_trackedPlayers.add(aPlayer);
					}
				//}
			} else {
				_log("** SND: Player " + connName + " (" + connHash + ") is attempting to join, but no room left in server", 1);
			}
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

		string key = player.getStringAttribute("sid");
		string playerCharId = player.getStringAttribute("character_id");
		int pcIdint = player.getIntAttribute("character_id");
		if (m_trackedPlayers.exists(key)) { // must have connected to be in this dict
			SNDPlayer@ spawnedPlayer;
			@spawnedPlayer = m_trackedPlayers.get(key);
			// associate player's dynamic character_id with their sid.
			cidTosid.set(playerCharId, key);
			spawnedPlayer.m_charId = pcIdint;
			_log("** SND: spawned player cidTosid check: " + spawnedPlayer.m_sid + ": " + spawnedPlayer.m_charId + ", character_id: " + playerCharId);
			// boost charcter's RP and XP to fall in line with saved stats
			_log("** SND: Grant " + spawnedPlayer.m_rp + " RP and " + spawnedPlayer.m_xp + " XP to " + spawnedPlayer.m_username, 1);
			string setCharRP = "<command class='rp_reward' character_id='" + playerCharId + "' reward='" + spawnedPlayer.m_rp + "'></command>";
			m_metagame.getComms().send(setCharRP);
			// improve this so only awarding XP in HR and AS missions, to CT units. Useless stat otherwise?
			string setCharXP = "<command class='xp_reward' character_id='" + playerCharId + "' reward='" + spawnedPlayer.m_xp + "'></command>";
			m_metagame.getComms().send(setCharXP);
			// load up saved inventory
			// TODO: = spawnedPlayer.m_kit[blah];
		} else {
			_log("** SND: Player spawned, but not registered as having connected. Doing nothing...", 1);
		}

		// increment live player count for faction
		updateFactionPlayerCounts(player.getIntAttribute("faction_id"), 1);
	}

	// --------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		_log("** SND: PlayerTracker Handling player disconnection!");
		const XmlElement@ disconn = event.getFirstElementByTagName("player");
		if (disconn !is null) {
			string key = disconn.getStringAttribute("sid");
			if (key != "ID0") {
				handlePlayerDisconnect(key);
			}
		}
		// which faction were they playing as?
		int dcPlayerFaction = disconn.getIntAttribute("faction_id");
		// decrement live player count for faction
		updateFactionPlayerCounts(disconn.getIntAttribute("faction_id"), -1);
	}

	// ----------------------------------------------------
	protected void handlePlayerDisconnect(string key) {
		if (m_trackedPlayers.exists(key)) {
			SNDPlayer@ p = m_trackedPlayers.get(key);
			_log("** SND: PlayerTracker tracked player disconnected, player=" + p.m_username);
			m_savedPlayers.add(p);
			m_trackedPlayers.remove(p);

			p.m_playerId = -1;
			p.m_charId = -1;
		}
	}

	// -----------------------------------------------------------
	protected void handlePlayerKillEvent(const XmlElement@ event) {
		// TagName=player_kill
		// key=hand_grenade.projectile
		// method_hint=blast

		// KILLER									// TARGET / KILLED
		// TagName=killer							// TagName=target
		// aim_target=589.214 7.54902 544.812		// aim_target=589.214 7.54902 544.812
		// character_id=3							// character_id=3
		// color=0.68 0.85 0 1						// color=0.68 0.85 0 1
		// faction_id=0								// faction_id=0
		// ip=										// ip=
		// name=player1								// name=player1
		// player_id=0								// player_id=0
		// port=0									// port=0
		// profile_hash=ID<10_numbers>				// profile_hash=ID<10_numbers>
		// sid=ID0									// sid=ID0

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
			m_metagame.addRP(pKillerCharId, -3300);
			m_metagame.addScore(factionId, -1);
		} else if (playerKiller.getIntAttribute("player_id") != playerTarget.getIntAttribute("player_id")) {
			// killed player on other team
			_log("** SND: Player " + pKillerId + " killed an enemy unit. Cash reward and increase score", 1);
			playSound(m_metagame, "enemydown.wav", factionId);
			string rewardEnemyKills = "<command class='rp_reward' character_id='" + pKillerCharId + "' reward='300'></command>";
			m_metagame.getComms().send(rewardEnemyKills);
			m_metagame.addRP(pKillerCharId, 300);
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
		string key = deadPlayer.getStringAttribute("sid");

		if (m_trackedPlayers.exists(key)) {
			SNDPlayer@ deadPlayerObj = m_savedPlayers.get(key);
			_log("** SND: Player " + deadPlayerObj.m_username + " has died", 1);
		}

		updateFactionPlayerCounts(deadPlayer.getIntAttribute("faction_id"), -1);
	}

	protected void handleItemDropEvent(const XmlElement@ event) {
		// character_id=11
		// item_class=0
		// item_key=bomb.weapon
		// item_type_id=53
		// player_id=0
		// position=359.807 7.54902 486.65
		// target_container_type_id=2 (backpack) id=0 (ground) id=1 (armoury)

		// if it's not related to a player, this tracker isn't interested
		if (event.getIntAttribute("player_id") < 0) {
			return;
		}
		// otherwise, continue
		uint char = event.getIntAttribute("character_id");
		if (dropEvents.find(char) < 0) {
			dropEvents.insertLast(char);
		}
	}

	// ----------------------------------------------------
	protected void updateFactionPlayerCounts(uint faction, int num) {
		if (factionPlayers[faction] + num > 0) {
			factionPlayers[faction] += num;
			_log("** SND: faction " + faction + " has " + num + " players alive", 1);
		} else {
			// first check we're still tracking character deaths
			if (!m_metagame.getTrackPlayerDeaths()) {
				// we're not. Bail.
				return;
			}
			_log("** SND: faction " + faction + " has run out of live players. Lose round!", 1);
			string winLoseCmd = "";
			array<Faction@> allFactions = m_metagame.getFactions();
			for (uint f = 0; f < allFactions.length(); ++f) {
				// in this case, the faction sent to this method is the losing faction (no living players remain)
				if (f == faction) {
					winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' lose='1'></command>";
					array<int> losingTeamCharIds = m_metagame.getFactionPlayerCharacterIds(f);
					for (uint i = 0; i < losingTeamCharIds.length() ; ++i) {
						string rewardLosingTeamChar = "<command class='rp_reward' character_id='" + losingTeamCharIds[i] + "' reward='900'></command>"; // " + (900 + (consecutive * 500)) + " // up to a max of 3400 / round
						m_metagame.getComms().send(rewardLosingTeamChar);
						m_metagame.addRP(losingTeamCharIds[i], 900);
					}
				} else {
					winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
					array<int> winningTeamCharIds = m_metagame.getFactionPlayerCharacterIds(f);
					for (uint i = 0; i < winningTeamCharIds.length() ; ++i) {
						string rewardWinningTeamChar = "<command class='rp_reward' character_id='" + winningTeamCharIds[i] + "' reward='3250'></command>";
						m_metagame.getComms().send(rewardWinningTeamChar);
						m_metagame.addRP(winningTeamCharIds[i], 3250);
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
	void save() {
		// called by substages' handleMatchEndEvent methods
		_log("** SND: PlayerTracker now saving player stats", 1);
		savePlayerStats();
	}

	// --------------------------------------------
	protected void savePlayerStats() {
		// saves to FILENAME in app_data.
		XmlElement root("search_and_destroy");

		m_savedPlayers.addPlayersToSave(root);
		m_trackedPlayers.addPlayersToSave(root);

		XmlElement command("command");
		command.setStringAttribute("class", "save_data");
		command.setStringAttribute("filename", FILENAME);
		command.setStringAttribute("location", "app_data");
		command.appendChild(root);

		m_metagame.getComms().send(command);

		_log("** SND: PlayerTracker " + m_savedPlayers.size() + " players saved", 1);
	}

	// --------------------------------------------
	protected void load() {
		_log("** SND: Loading Saved Player Data", 1);
		// initialise object storage
		m_savedPlayers.clear();
		m_trackedPlayers.clear();

		// retrieve saved data
		XmlElement@ query = XmlElement(
			makeQuery(m_metagame, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"}, {"filename", FILENAME}, {"location", "app_data"} } }));
		const XmlElement@ doc = m_metagame.getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			if (root !is null) {
				_log("** SND: load() iterating over saved players", 1);
				array<const XmlElement@> loadedPlayers = root.getElementsByTagName("player");
				for (uint i = 0; i < loadedPlayers.size(); ++i) {
					_log("\t player" + (i + 1), 1); // load player[1..999] tag elements
					const XmlElement@ loadPlayer = loadedPlayers[i];
					string username = loadPlayer.getStringAttribute("username");
					string hash = loadPlayer.getStringAttribute("hash");
					string sid = loadPlayer.getStringAttribute("sid");
					string ip = loadPlayer.getStringAttribute("ip");
					// TODO: load up the equipment from subelement
					XmlElement kit("equipment");
					SNDPlayer player(username, hash, sid, ip, -1, kit);
					player.m_rp = loadPlayer.getIntAttribute("rp");
					player.m_xp = loadPlayer.getFloatAttribute("xp");

					m_savedPlayers.add(player);
				}
			}
		}

		_log("** SND: PlayerTracker load(): " + m_savedPlayers.size() + " players loaded");
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

	// --------------------------------------------
	void update(float time) {
		playerCheckTimer -= time;
		if (playerCheckTimer <= 0.0) {
			dictionary rpRewards = m_metagame.getPendingRPRewards();
			for (uint i = 0; i < rpRewards.getKeys().size(); ++i) {
				string rewardChar = rpRewards.getKeys()[i];
				// get the SID from the character_id being rewarded
				string rewardSid = string(cidTosid[rewardChar]);
				// use the SID to get the player object
				if (m_trackedPlayers.exists(rewardSid)) {
					SNDPlayer@ aPlayer;
					@aPlayer = m_trackedPlayers.get(rewardSid);
					_log("** SND: rewarding player " + rewardSid + ": " + aPlayer.m_username + " " + int(rpRewards[rewardChar]) + " RP", 1);
					aPlayer.m_rp += int(rpRewards[rewardChar]);
					_log("** SND: " + aPlayer.m_username + " RP now at: " + aPlayer.m_rp, 1);
				} else { _log("** SND: couldn't find player " + rewardSid + ": " + rewardChar + " to reward...", 1); }
			}
			// if a handleItemDropEvent has fired since last check, save out associated player chars' inventories
			if (dropEvents.length() > 0) {
				for (uint j = 0; j < dropEvents.length(); ++j) {
					// save inventory
					const XmlElement@ playerInv = m_metagame.getPlayerInventory(dropEvents[j]);
					array<const XmlElement@> pInv = playerInv.getElementsByTagName("item");
				}
				dropEvents.clear();
			}

			playerCheckTimer = CHECK_IN_INTERVAL;
		}
	}
}
