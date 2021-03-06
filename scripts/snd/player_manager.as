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

	int m_playerId = -1;	// the 'player_id'. Value positive only when player is in-game
	int m_charId = -1;		// the 'character_id' of the player. Value positive only when player is in-game

	string m_primary = "";
	string m_secondary = "";
	string m_gren = "";
	int m_grenNum = 0;
	string m_armour = "";

	int m_rp;
	float m_xp;

	// --------------------------------------------
	SNDPlayer(string username, string hash, string sid, string ip, int id, string pri="", string sec="", string gren="", int grenNum=0, string arm="std_armour") {
		m_username = username;
		m_hash = hash;
		m_sid = sid;
		m_ip = ip;
		m_playerId = id;
		m_primary = pri;
		m_secondary = sec;
		m_gren = gren;
		m_grenNum = grenNum;
		m_armour = arm;
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
			savedPlayer.setStringAttribute("primary", player.m_primary);
			savedPlayer.setStringAttribute("secondary", player.m_secondary);
			savedPlayer.setStringAttribute("gren", player.m_gren);
			savedPlayer.setIntAttribute("gren_num", player.m_grenNum);
			savedPlayer.setStringAttribute("armour", player.m_armour);
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

				// we want to allow "ID0" (local player) to join for local testing but not if the game is being run online
				// "ID0" is also a player who hasn't logged into steam. Ignore connects from "ID0" if anyone is already in the server
				if (key == "ID0") {
					_log("** SND: WARNING: Local or non-steam player connected", 1);
					if (m_trackedPlayers.size() > 0) {
						_log("** SND: Online server active, must be connected to steam to play! Connection attempt rejected!", 1);
						kickPlayer(m_metagame, connId);
					}
				}
				if (m_savedPlayers.exists(key)) {
					SNDPlayer@ aPlayer;
					@aPlayer = m_savedPlayers.get(key);
					_log("** SND: known player " + aPlayer.m_username + " rejoining server", 1);
					// sanity check the known player's RP and XP
					_log("\t RP: " + aPlayer.m_rp, 1);
					_log("\t XP: " + aPlayer.m_xp, 1);
					_log("\t Pri: " + aPlayer.m_primary, 1);
					_log("\t Sec: " + aPlayer.m_secondary, 1);
					if (aPlayer.m_grenNum > 0) {
						_log("\t Gre: " + aPlayer.m_gren, 1);
						_log("\t Num: " + aPlayer.m_grenNum, 1);
					}
					_log("\t Arm: " + aPlayer.m_armour, 1);
					aPlayer.m_username = connName;
					aPlayer.m_ip = connIp;
					aPlayer.m_playerId = connId;
					m_trackedPlayers.add(aPlayer);
					m_savedPlayers.remove(aPlayer);
				} else {
					// assign stock starter kit
					SNDPlayer@ aPlayer = SNDPlayer(connName, connHash, key, connIp, connId);
					_log("** SND: Unknown/new player " + aPlayer.m_username + " joining server", 1);
					// set RP and XP for new players
					assignDefaults(aPlayer);
					m_trackedPlayers.add(aPlayer);
				}
				// } else {
				// 	_log("** SND: player with ID0 connected. Will not be tracked", 1);
				// }
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

		if (player !is null) {
			string key = player.getStringAttribute("sid");
			string hash = player.getStringAttribute("profile_hash");
			string playerCharId = player.getStringAttribute("character_id");
			int pcIdint = player.getIntAttribute("character_id");

			// In some cases, getCharacterInfo queries return a negative int for a character's id:
			// sending: TagName=command class=make_query id=329.000     TagName=data class=character id=1.000
			// waiting for response for the query...
			// received: TagName=query_result query_id=329     TagName=character id=-1

			// When this occurs, the commands to update RP and XP as well as the setPlayerInventory method
			// will fail and the metagame will throw an index out of bounds exception. Terminal!

			// before we go too far, let's make sure the spawned player's reported character ID matches that stored by the metagame.
			const XmlElement@ thisChar = getCharacterInfo(m_metagame, pcIdint);

			// one way to know we have an issue is if the returned Character XML Element doesn't have a 'faction_id' attribute.
			if (!thisChar.hasAttribute("faction_id")) {
				_log("** SND: WARNING! Failed to lookup Character ID " + pcIdint + ". giving up on getCharacterInfo...", 1);
				// Remove player from m_trackedPlayers; we will notice additional connect and spawn events for this player shortly...
				if (m_trackedPlayers.exists(key)) {
					SNDPlayer@ noGoPlayer;
					@noGoPlayer = m_trackedPlayers.get(key);
					m_savedPlayers.add(noGoPlayer);
					m_trackedPlayers.remove(noGoPlayer);
					return; // break out - the PlayerSpawnEvent has been recorded or handled incorrectly
				}
			}
			// great! we're OK to continue

			if (m_trackedPlayers.exists(key)) { // must have connected to be in this dict
				SNDPlayer@ spawnedPlayer;
				@spawnedPlayer = m_trackedPlayers.get(key);
				bool defaultKit = false;
				// associate player's dynamic character_id with their sid.
				cidTosid.set(playerCharId, key);
				spawnedPlayer.m_charId = pcIdint;
				_log("** SND: spawned player cidTosid check: " + spawnedPlayer.m_sid + ": " + spawnedPlayer.m_charId + ", character_id: " + playerCharId);
				if (!m_metagame.getIsFirstSubStage()) {
					// match character's RP and XP to saved stats
					// but subtract default/initial RP and XP values, which are applied on spawn.
					const UserSettings@ settings = m_metagame.getUserSettings();
					_log("** SND: Grant " + spawnedPlayer.m_rp + " RP and " + spawnedPlayer.m_xp + " XP to " + spawnedPlayer.m_username, 1);
					string setCharRP = "<command class='rp_reward' character_id='" + playerCharId + "' reward='" + (spawnedPlayer.m_rp - settings.m_initialRp) + "'></command>";
					m_metagame.getComms().send(setCharRP);
					string setCharXP = "<command class='xp_reward' character_id='" + playerCharId + "' reward='" + (spawnedPlayer.m_xp - settings.m_initialXp) + "'></command>";
					m_metagame.getComms().send(setCharXP);
					defaultKit = false;

				} else {
					_log("** SND: First round of rotation. Assigning Defaults", 1);
					// reset XP, RP, and inventory every first round of rotation
					defaultKit = true;
					assignDefaults(spawnedPlayer);
				}

				m_metagame.setPlayerInventory(pcIdint, defaultKit, spawnedPlayer.m_primary, spawnedPlayer.m_secondary, spawnedPlayer.m_gren, spawnedPlayer.m_grenNum, spawnedPlayer.m_armour);

			} else {
				_log("** SND: Player spawned, but not registered as having connected. Doing nothing...", 1);
			}

			// increment live player count for faction
			m_metagame.updateFactionPlayerCount(player.getIntAttribute("faction_id"), 1);
		}
	}

	// --------------------------------------------
	protected void handlePlayerDisconnectEvent(const XmlElement@ event) {
		_log("** SND: PlayerTracker Handling player disconnection!");
		const XmlElement@ disconn = event.getFirstElementByTagName("player");
		if (disconn !is null) {
			string key = disconn.getStringAttribute("sid");
			// decrement live player count for faction (if dc'd player was not dead)
			const XmlElement@ dcCharId = getCharacterInfo(m_metagame, disconn.getIntAttribute("character_id"));
			if (dcCharId.getIntAttribute("dead") != 1) {
				int dcPlayerFaction = disconn.getIntAttribute("faction_id");
				m_metagame.updateFactionPlayerCount(disconn.getIntAttribute("faction_id"), -1);
			}
			handlePlayerDisconnect(key);
		}
	}

	// ----------------------------------------------------
	protected void handlePlayerDisconnect(string key) {
		if (m_trackedPlayers.exists(key)) {
			SNDPlayer@ p = m_trackedPlayers.get(key);
			_log("** SND: Tracked player " +  p.m_username + " disconnected", 1);
			flushPendingDropEvents();
			flushPendingRewards();
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

		if (!m_metagame.getTrackPlayerDeaths()) {
			return;
		}

		const XmlElement@ playerKiller = event.getFirstElementByTagName("killer");
		const XmlElement@ playerTarget = event.getFirstElementByTagName("target");

		if (playerKiller !is null) {
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

		// if not tracking player deaths (e.g. round ended), bail
		if (!m_metagame.getTrackPlayerDeaths()) {
			return;
		}

		// enforce no respawning (1 life per round)
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint i = 0; i < allFactions.length(); ++i) {
			string noRespawnComm = "<command class='set_soldier_spawn' faction_id='" + i + "' enabled='0' />";
			m_metagame.getComms().send(noRespawnComm);
		}

		const XmlElement@ deadPlayer = event.getFirstElementByTagName("target");

		int playerCharId = deadPlayer.getIntAttribute("character_id");
		string key = deadPlayer.getStringAttribute("sid");

		if (m_trackedPlayers.exists(key)) {
			SNDPlayer@ deadPlayerObj = m_trackedPlayers.get(key);
			_log("** SND: Player " + deadPlayerObj.m_username + " has died", 1);
			// empty that player's inventory
			deadPlayerObj.m_primary = "";
			deadPlayerObj.m_secondary = "";
			deadPlayerObj.m_gren = "";
			deadPlayerObj.m_grenNum = 0;
			deadPlayerObj.m_armour = "";
		}

		m_metagame.updateFactionPlayerCount(deadPlayer.getIntAttribute("faction_id"), -1);
	}

	// ----------------------------------------------------
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
			_log("** SND: Inventory update/save for character " + char + " (player ID: " + event.getIntAttribute("player_id") + ") has been queued", 1);
			dropEvents.insertLast(char);
		}
	}

	// ---------------------------------------------------
	protected void flushPendingDropEvents() {
		// if a handleItemDropEvent has fired since last check, save out associated player chars' inventories
		if (dropEvents.length() > 0) {
			for (uint j = 0; j < dropEvents.length(); ++j) {
				// get player SID from character_id
				string cid = "" + dropEvents[j] + "";
				if (cidTosid.exists(cid)) {
					updateSavedInventory(dropEvents[j]);
				}
			}
			dropEvents.clear();
		}
	}

	// ----------------------------------------------------
	protected void flushPendingRewards() {
		dictionary rpRewards = m_metagame.getPendingRPRewards();
		for (uint i = 0; i < rpRewards.getKeys().size(); ++i) {
			string rewardChar = rpRewards.getKeys()[i];
			// get the SID from the character_id being rewarded
			string rewardSid = string(cidTosid[rewardChar]);
			// use the SID to get the player object
			if (m_trackedPlayers.exists(rewardSid)) {
				SNDPlayer@ aPlayer;
				@aPlayer = m_trackedPlayers.get(rewardSid);
				if (int(rpRewards[rewardChar]) < 0 || aPlayer.m_rp < m_metagame.getUserSettings().m_maxRp) {
					_log("** SND: rewarding player " + rewardSid + ": " + aPlayer.m_username + " " + int(rpRewards[rewardChar]) + " RP", 1);
					aPlayer.m_rp += int(rpRewards[rewardChar]);
					if (aPlayer.m_rp > m_metagame.getUserSettings().m_maxRp) {
						aPlayer.m_rp = m_metagame.getUserSettings().m_maxRp;
					} else if (aPlayer.m_rp < 0) {
							aPlayer.m_rp = 0;
					}
					_log("** SND: " + aPlayer.m_username + " RP now at: " + aPlayer.m_rp, 1);
				} else {
					_log("** SND: " + aPlayer.m_username + " already at Max RP. Cannot reward any further", 1);
				}
			} else { _log("** SND: couldn't find player " + rewardSid + ": " + rewardChar + " to reward...", 1); }
		}
	}

	// ----------------------------------------------------
	protected void assignDefaults(SNDPlayer@ aPlayer) {
		_log("** SND: granting player " + aPlayer.m_username + " starting kit", 1);
		const UserSettings@ settings = m_metagame.getUserSettings();
		aPlayer.m_primary = "";
		aPlayer.m_secondary = "";
		aPlayer.m_gren = "";
		aPlayer.m_grenNum = 0;
		aPlayer.m_armour = settings.m_initialArmour;
		aPlayer.m_rp = settings.m_initialRp;
		aPlayer.m_xp = settings.m_initialXp;
	}

	// ----------------------------------------------------
	protected void updateSavedInventory(int charId) {
		// note we are not recording items in the backpack to prevent stockpiling of resources between rounds
		// may consider implementing at a later date, but the effort outweighs the benefit
		_log("** SND: Updating saved inventory for character id " + charId, 1);
		string scharId = "" + charId + "";
		string key = string(cidTosid[scharId]);
		if (m_trackedPlayers.exists(key)) {
			// we have an active player to update the inventory for
			SNDPlayer@ aPlayer;
			@aPlayer = m_trackedPlayers.get(key);
			// get the character info + inventory
			const XmlElement@ playerInv = m_metagame.getPlayerInventory(charId);
			array<const XmlElement@> pInv = playerInv.getElementsByTagName("item");
			for (uint k = 0; k < pInv.size(); ++k) {
				string invItem = pInv[k].getStringAttribute("key");
				if (invItem == "") {
					continue;
				} else {
					_log("** SND: slot " + k + ": " + (pInv[k].getIntAttribute("amount") > 0 ? invItem : ''), 1);
					switch (k) {
						case 0:
							if (pInv[k].getIntAttribute("amount") > 0) {
								aPlayer.m_primary = invItem;
							} else { aPlayer.m_primary = ""; }
							break;
						case 1:
							// prevent medi_shot stockpiling, lose pistol if not equipped (worst case you get a free one at round start)
							if (pInv[k].getIntAttribute("amount") > 0 && invItem != "medi_shot.weapon") {
								aPlayer.m_secondary = invItem;
							} else { aPlayer.m_secondary = ""; }
							break;
						case 2:
							if (pInv[k].getIntAttribute("amount") > 0) {
								aPlayer.m_gren = invItem;
								aPlayer.m_grenNum = pInv[k].getIntAttribute("amount");
							} else {
								aPlayer.m_gren = "";
								aPlayer.m_grenNum = 0;
							}
							break;
						case 4:
							if (pInv[k].getIntAttribute("amount") > 0) {
								aPlayer.m_armour = invItem;
							} else { aPlayer.m_armour = ""; }
							break;
						default:
							_log("** SND: WARNING! untracked slot " + k + "!", 1);
					}
				}
			}
		}
	}

	// --------------------------------------------
	void save() {
		// called by substages' handleMatchEndEvent methods
		_log("** SND: PlayerTracker finalising this round's RP rewards", 1);
		flushPendingRewards();
		_log("** SND: Round ended. PlayerTracker now updating player inventories", 1);
		flushPendingDropEvents();
		for (uint i=0; i < m_trackedPlayers.getKeys().size(); ++i) {
			string sid = m_trackedPlayers.getKeys()[i];
			_log("** SND: Working with player " + sid, 1);
			array<const XmlElement@> allPlayers = getPlayers(m_metagame);
			// TagName=player character_id=3 name=LC1A player_id=0 sid=ID0 (among others)
			for (uint j=0; j < allPlayers.length(); ++j) {
				int characterId = allPlayers[j].getIntAttribute("character_id");
				updateSavedInventory(characterId);
			}
		}
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

		_log("** SND: PlayerTracker " + m_trackedPlayers.size() + " active players saved", 1);
		_log("** SND: PlayerTracker " + m_savedPlayers.size() + " inactive players saved", 1);
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
					string primary = loadPlayer.getStringAttribute("primary");
					string secondary = loadPlayer.getStringAttribute("secondary");
					string gren = loadPlayer.getStringAttribute("gren");
					int grenNum = loadPlayer.getIntAttribute("gren_num");
					string armour = loadPlayer.getStringAttribute("armour");

					SNDPlayer player(username, hash, sid, ip, -1, primary, secondary, gren, grenNum, armour);
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
			flushPendingRewards();
			flushPendingDropEvents();
			playerCheckTimer = CHECK_IN_INTERVAL;
		}
	}
}
