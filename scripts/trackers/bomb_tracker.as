#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "snd_helpers.as" // don't think needed as already included

// --------------------------------------------
class BombTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected bool m_started = false;
	protected bool bombInPlay = false;  // should only ever be 1 bomb in play
	protected int bombCarrier = -1;	    // and one (or no) character_id carrying it
	protected int bombFaction = -1;     // the faction_id of the bombCarrier
	protected string bombPosition = ""; // xxx.xxx yyy.yyy zzz.zzz

	protected float BOMB_POS_UPDATE_TIME = 15.0;
	protected float bombPosUpdateTimer = 0.0;

	// --------------------------------------------
	BombTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting BombTracker tracker", 1);
		addBomb();
		m_started = true;
	}

	////////////////////
	// BOMB LIFECYCLE //
	////////////////////

	// --------------------------------------------
	void addBomb() {
		// get all the players
		array<const XmlElement@> players = getPlayers(m_metagame);
		uint i = rand(0, players.length() - 1);
		// get a specific player's character
		const XmlElement@ player = players[i];
		bombCarrier = player.getIntAttribute("character_id");
		// and give that character the bomb
		addBombToBackpack(m_metagame, bombCarrier);
		_log("** SND: gave player (id: " + bombCarrier + ") the bomb", 1);
		// get detailed info about that character
		const XmlElement@ bomber = getCharacterInfo(m_metagame, bombCarrier);
		// record where the bomb is and who has it this round
		bombPosition = bomber.getStringAttribute("position");
		bombFaction = bomber.getIntAttribute("faction_id");
		// let friendlies know where the bomb is
		markBombLocation(bombPosition, bombFaction);

		// we got a game going on now
		bombInPlay = true;
	}

	// --------------------------------------------
	protected string getBombLocation() {
		// gets and returns current location of the bombCarrier
		// relies on bombCarrier int to be updated when the bomb changes hands, is dropped, etc.
		// see handleItemDropEvent method
		if (bombCarrier == -1) {
			return bombPosition;
		} else {
			const XmlElement@ bomberLoc = getCharacterInfo(m_metagame, bombCarrier);
			string position = bomberLoc.getStringAttribute("position");
			return position;
		}
	}

	// --------------------------------------------
	protected void markBombLocation(string position, int faction = -1, int charId = -1) {
		// marks the current location of the bomb on screen, screen-edge, and/or map overlay
		// by default, all factions are alerted to the location of the bomb. Pass a faction_id as the int to override
		_log("** SND: Marking location of bomb", 1);
		string bombMarkerCmd = "";
		if (faction == -1 ) {
			array<Faction@> allFactions = m_metagame.getFactions();
			for (uint f = 0; f < allFactions.length(); ++f) {
				bombMarkerCmd = "<command class='set_marker' id='" + (8008 + f) + "' atlas_index='2' faction_id='" + f + "' text='' position='" + position + "' color='#FFFFFF' size='1.0' show_in_game_view='0' show_in_map_view='1' show_at_screen_edge='0' />";
			}
		} else {
			bombMarkerCmd = "<command class='set_marker' id='8008' atlas_index='2' faction_id='" + faction + "' text='' position='" + position + "' color='#FFFFFF' size='1.0' show_in_game_view='1' show_in_map_view='1' show_at_screen_edge='1' />";
		}
		m_metagame.getComms().send(bombMarkerCmd);
		_log("** SND: Updated bomb location marker!", 1);
	}


	// alert all when bomb is correctly deployed within one of the target locations
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// TagName=vehicle_destroyed_event
		// character_id=75
		// faction_id=0
		// owner_id=0
		// position=559.322 14.6788 618.121
		// vehicle_key=bomb_armed.vehicle

		// in this game mode, a dummy vehicle (with 0 ttl) is spawned when the bomb_resource.weapon is placed (arming the bomb.projectile)
		// this allows us to ensure the bomb has been placed within a valid target area, and if not, to ensure the bomb

		// we are only interested in the destruction of 'bomb_*'-related "vehicles"
        if (!startsWith(event.getStringAttribute("vehicle_key"), "bomb_")) {
			return;
		}
		_log("** SND: BombHandler going to work!", 1);
		// variablise attributes
		string vehKey = event.getStringAttribute("vehicle_key");

		if (vehKey == "bomb_armed.vehicle") {
			// confirm destroyer character is the recorded bombCarrier
			int destroyer = event.getIntAttribute("character_id");
			if (destroyer == bombCarrier) {
				_log("** SND: Bomb carrier has planted the bomb", 1);
				// update the bomb carrier and position
				string destroyPos = event.getStringAttribute("position");
				bombCarrier = -1;
				bombPosition = position;
				// now continue to see if bomb was placed in a valid targetLocation
			} else {
				_log("** SND: Bomb has been planted (destroyed) by unexpected character id: " + destroyer, 1);
				// may need to bail here / dodgy fake bomb?
			}

			// confirm the bomb has been placed within one of this match's targetLocations

			// TODO
			_log("** SND: The bomb has been planted", 1);
		}
    }

	// alert team with bomb when bomb_resource.weapon is dropped (item drops on ground through death or via inventory)
	// --------------------------------------------
	protected void handleItemDropEvent(const XmlElement@ event) {
		// character_id=11
		// item_class=0
		// item_key=bomb_resource.weapon
		// item_type_id=53
		// player_id=0
		// position=359.807 7.54902 486.65
		// target_container_type_id=2 (backpack) id=0 (ground)

		// if it's not a bomb, this tracker isn't interested
		if (!startsWith(event.getStringAttribute("item_key"), "bomb_")) {
			return;
		}
		// otherwise, continue
		string itemKey = event.getStringAttribute("item_key");
		string position = event.getStringAttribute("position");

		// this block deals only with the placeable bomb weapon
		if (itemKey == "bomb_resource.weapon") {
			bombPosition = position;
			int dropChar = event.getIntAttribute("character_id");
			// if dropChar matches the character_id of the player who is carrying the legit bomb
			if (dropChar == bombCarrier) {
				const XmlElement@ bomber = getCharacterInfo(m_metagame, bombCarrier);
				bombFaction = bomber.getIntAttribute("faction_id");
				switch (event.getIntAttribute("target_container_type_id")) {
					case 0:
						_log("** SND: Bomb (" + itemKey + ") dropped onto ground ", 1);
						// bad idea! Now everyone gets to find out where the bomb is
						bombCarrier = -1;
						markBombLocation(position);
						break;
					case 2:
						_log("** SND: Bomb dropped into backpack", 1);
						markBombLocation(position, bombFaction);
						break;
					default: // shouldn't ever get here, but sanity
				_log("** SND: WARNING! Bomb was dropped in target_container_type_id: " + event.getIntAttribute("target_container_type_id") + ". Not tracked!", 1);
				}
			} else {
				// otherwise, it's probably a fake bomb!
				_log("** SND: WARNING! Bomb dropped by illegitimate character", 1);
			}
		}
	}

	// alert all when bomb explodes (bombers win, disarmers lose --> cycle map)
	// bombInPlay = false;
	// alert all when bomb defused (disarmers win, bombers lose --> cycle map)
	// bombInPlay = false;

	// --------------------------------------------
	bool hasEnded() const {
			// always on
			return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
			// always on
			return m_started;
	}

	// --------------------------------------------
	void update(float time) {
		bombPosUpdateTimer -= time;
		if (bombPosUpdateTimer < 0.0) {
			markBombLocation(getBombLocation(), bombFaction);
			bombPosUpdateTimer = BOMB_POS_UPDATE_TIME;
		}
	}
}
