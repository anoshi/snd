#include "metagame.as"
#include "log.as"
#include "map_rotator_snd_all.as"
#include "score_tracker.as"

// --------------------------------------------
class GameModeSND : Metagame {
	protected UserSettings@ m_userSettings;
	protected MapRotator@ m_mapRotator;
	protected ScoreTracker@ m_scoreTracker;

	//protected MapInfo@ m_mapInfo; // already exists in Metagame class
	protected array<Faction@> m_factions;
	protected dictionary pendingRPRewards = {}; // queue to store RP rewards to grant to players

	array<Vector3> targetLocations;		// locations where bombs may be placed or hostages may start
	array<Vector3> extractionPoints;	// locations that units must reach in order to escape
	array<int> trackedCharIds;			// Ids of characters being tracked against collisions with hitboxes
	int numExtracted = 0;				// the number of hostages safely rescued

	protected bool trackPlayerDeaths = true;

	protected string m_tournamentName = "";

	// --------------------------------------------
	GameModeSND(UserSettings@ settings) {
		super(settings.m_startServerCommand);
		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		Metagame::init();
		// add the scoreboard
		setupScoreboard();
		// trigger map change right now
		setupMapRotator();
		m_mapRotator.init();
		m_mapRotator.startRotation();
	}

	// --------------------------------------------
	void uninit() {
		save();
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	void save() {
		_log("** SND: saves to snd_players.xml!", 1);
	}

	// --------------------------------------------
	void load() {
		_log("** SND: loading metagame!", 1);
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		@m_mapRotator = MapRotatorSNDAll(this);
	}

	// --------------------------------------------
	protected void setupScoreboard() {
		@m_scoreTracker = ScoreTracker(this);
		// per-faction score tracking
		addTracker(m_scoreTracker);
		_log("** SND: ScoreTracker Added", 1);
		resetScores();
		_log("** SND: Scores reset", 1);
	}

	// --------------------------------------------
	// MapRotator calls here when a battle has started
	void postBeginMatch() {
		Metagame::postBeginMatch();
		// add tracker for match end to switch to next
		addTracker(m_mapRotator);
	}

	// --------------------------------------------
	void disableCommanderAI(bool commanderAI=true) {
		// Trackers call this method to disable Commander AI on a per-map basis
		// with no commander to give orders, AI units stand stay put until added to a player's squad
		if (commanderAI == false) {
			return; // RWR enables the AI / bot commander by default
		} else {
			for (uint i = 0; i < m_factions.length(); ++i) {
				string disableCommAI = "<command class='commander_ai' faction='" + i + "' active='0'>'";
				getComms().send(disableCommAI);
			}
			_log("** SND: commander_ai disabled for this round", 1);
		}
	}

	// --------------------------------------------
	void resetScores() {
		m_scoreTracker.reset();
	}

	// --------------------------------------------
	void addScore(int factionId, int score) {
		_log("** SND: GameModeSND addScore adding " + score + " points to faction " + factionId, 1);
		m_scoreTracker.addScore(factionId, score);
	}

	// --------------------------------------------
	array<int> getScores() {
		return m_scoreTracker.getScores();
	}

	// --------------------------------------------
	dictionary getPendingRPRewards() {
		dictionary queued = {};
		for (uint i = 0; i < pendingRPRewards.getKeys().size(); ++i) {
			_log("** SND: pendingRPRewards size is: " + pendingRPRewards.getKeys().size() + " and iterator (i) is: " + i, 1);
			string key = pendingRPRewards.getKeys()[i];
			queued.set(key, int(pendingRPRewards[key]));
		}
		// all pending rewards accounted for, empty dictionary.
		pendingRPRewards.deleteAll();
		return queued;
	}

	// --------------------------------------------
	void addRP(int cId, int rp) {
		string charId = "" + cId + "";
		if (pendingRPRewards.exists(charId)) {
			int val = int(pendingRPRewards[charId]);
			pendingRPRewards[charId] = val + rp;
		} else {
			pendingRPRewards.set(charId, rp);
		}
	}

	// --------------------------------------------
	void addXP(int charId, float xp) {
		// nothing yet grants XP bonuses.
	}

	// --------------------------------------------
	void setTrackPlayerDeaths(bool pDeaths=true) {
		trackPlayerDeaths = pDeaths;
	}

	// --------------------------------------------
	bool getTrackPlayerDeaths() {
		_log("** SND: got trackPlayerDeaths: (" + trackPlayerDeaths + ")", 1);
		return trackPlayerDeaths;
	}

	// --------------------------------------------
	void setTargetLocations(array<Vector3> v3array) {
		// Trackers call this method to store target locations on the current map
		targetLocations = v3array;
	}

	// --------------------------------------------
	array<Vector3> getTargetLocations() {
		// Trackers call this method to retrieve target locations on the current map
		return targetLocations;
	}

	// --------------------------------------------
	void setExtractionPoints(array<Vector3> v3array) {
		// Trackers call this method to store escape points on the current map
		extractionPoints = v3array;
	}

	// --------------------------------------------
	array<Vector3> getExtractionPoints() {
		// Trackers call this method to retrieve escape points on the current map
		return extractionPoints;
	}

	// --------------------------------------------
	void addNumExtracted(int num) {
		numExtracted += num;
	}

	// --------------------------------------------
	int getNumExtracted() {
		return numExtracted;
	}

	// --------------------------------------------
	void addTrackedCharId(int charId) {
		// Trackers call this method to add a character ID to the list of tracked character IDs
		trackedCharIds.insertLast(charId);
		_log("** SND: GameModeSND::addTrackedCharId " + charId, 1);
	}

	// --------------------------------------------
	void removeTrackedCharId(int charId) {
		// Trackers call this method to remove a character ID from the list of tracked character IDs
		_log("** SND: GameModeSND::removeTrackedCharId " + charId, 1);
		int idx = trackedCharIds.find(charId);
		if (idx >= 0) {
			trackedCharIds.removeAt(idx);
			_log("\t charId: " + charId + " removed", 1);
		}
	}

	// --------------------------------------------
	array<int> getTrackedCharIds() {
		// Trackers call this method to retrieve the full list of tracked character IDs
		return trackedCharIds;
	}

	// -----------------------------
	const XmlElement@ getPlayerInventory(int characterId) {
		_log("** SND: Inspecting character " + characterId + "'s inventory", 1);
		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = {
					{"TagName", "data"},
					{"class", "character"},
					{"id", characterId},
					{"include_equipment", 1}
				}
			})
		);
		const XmlElement@ doc = getComms().query(query);
		return doc.getFirstElementByTagName("character"); //.getElementsByTagName("item")

		// TagName=query_result query_id=22
		// TagName=character
		// block=11 17
		// dead=0
		// faction_id=0
		// id=3
		// leader=1
		// name=CT: 62
		// player_id=0
		// position=375.557 2.74557 609.995
		// rp=9400
		// soldier_group_name=default
		// squad_size=0
		// wounded=0
		// xp=0

		// TagName=item amount=1 index=17 key=steyr_aug.weapon slot=0
		// TagName=item amount=0 index=3 key=9x19mm_sidearm.weapon slot=1
		// TagName=item amount=1 index=3 key=hand_grenade.projectile slot=2
		// TagName=item amount=0 index=-1 key= slot=4
		// TagName=item amount=1 index=3 key=kevlar_plus_helmet.carry_item slot=5
	}

	// -----------------------------
	void setPlayerInventory(int characterId, bool newPlayer=false, string pri="", string sec="", string gren="", int grenNum=0, string arm="") {
		// container_type_ids (slot=[0-5])
		// 0 : primary weapon (cannot add directly, put in backpack instead)
		// 1 : secondary weapon
		// 2 : grenade
		// 3 : ?
		// 4 : armour
		// 5 : armour

		const XmlElement@ thisChar = getCharacterInfo(this, characterId);
		uint iter = 0;
		while (thisChar.getIntAttribute("id") != characterId && iter < 5) {
			_log("** SND: getCharacterInfo returned a negative characterId. Retrying ...", 1);
			sleep(2);
			const XmlElement@ thisChar = getCharacterInfo(this, characterId);
			iter++;
			if (iter == 4) {
				_log("** SND: giving up on getCharacterInfo call for character " + characterId, 1);
				return;
			}
		}

		int faction = thisChar.getIntAttribute("faction_id");

		// assign / override equipment to player character
		if (newPlayer) {
			// give the character appropriate starting kit for their faction
			_log("** SND: Equipping new player (id: " + characterId + ") with " + (faction == 0 ? 'Counter Terrorist' : 'Terrorist') + " starting gear", 1);
			string addSec = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + (faction == 0 ? 'km_45_tactical_free.weapon' : '9x19mm_sidearm_free.weapon') + "' /></command>";
			getComms().send(addSec);
		} else {
			_log("** SND: Updating inventory for player (character_id: " + characterId + ")", 1);
			// primary into backpack, cannot override slot
			if (pri != '') {
				string addPri = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + pri + "' /></command>";
				getComms().send(addPri);
			}
			if (sec != '') {
				string addSec = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + sec + "' /></command>";
				getComms().send(addSec);
			}
			if (startsWith(sec, '9x19') || startsWith(sec, 'km_45') || startsWith(sec, '228') || startsWith(sec, 'night_hawk') || startsWith(sec, 'es_five') || startsWith(sec, '40_dual')) {
				// player has a sidearm. no action required
			} else {
				// you always get a pistol if you aren't carrying one
				_log("** SND: Character " + characterId + " has no sidearm. Granting a free " + (faction == 0 ? 'km_45_tactical_free.weapon' : '9x19mm_sidearm_free.weapon'), 1);
				string addSec = "<command class='update_inventory' character_id='" + characterId + "' container_type_class='backpack'><item class='weapon' key='" + (faction == 0 ? 'km_45_tactical_free.weapon' : '9x19mm_sidearm_free.weapon') + "' /></command>";
				getComms().send(addSec);
			}
			for (int gn = 0; gn < grenNum; ++gn) {
				string addGren = "<command class='update_inventory' character_id='" + characterId + "' container_type_id='2'><item class='grenade' key='" + gren + "' /></command>";
				getComms().send(addGren);
			}
			if (arm != '') {
				string addArm = "<command class='update_inventory' character_id='" + characterId + "' container_type_id='4'><item class='carry_item' key='" + arm + "' /></command>";
				getComms().send(addArm);
			}
		}
	}

	// -----------------------------
	array<int> getFactionPlayerCharacterIds(uint faction) {
		array<int> playerCharIds;
		array<const XmlElement@> players = getPlayers(this);
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ player = players[i];
			uint factionId = player.getIntAttribute("faction_id");
			if (factionId == faction) {
				playerCharIds.insertLast(player.getIntAttribute("character_id"));
			}
		}
		return playerCharIds;
	}

	// --------------------------------------------
	string getTournamentName() {
		return m_tournamentName;
	}

	// --------------------------------------------
	bool isTournamentOngoing() {
		return m_tournamentName != "";
	}

	// --------------------------------------------
	void startTournament(string name) {
		m_tournamentName = name;
	}

	// --------------------------------------------
	void endTournament() {
		m_tournamentName = "";
	}

	// --------------------------------------------
	// map rotator feeds in data about current situation here
	void setFactions(array<Faction@> factions) {
		m_factions = factions;
	}

	// --------------------------------------------
	// map rotator feeds in data about current situation here
	void setMapInfo(MapInfo@ info) {
		m_mapInfo = info;
	}

	// --------------------------------------------
	array<Faction@> getFactions() {
		return m_factions;
	}

	// --------------------------------------------
	// pos is array of 3 elements, x,y,z
	string getRegion(Vector3@ pos) {
		return Metagame::getRegion(pos);
	}
}
