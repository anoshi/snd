#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
class BombTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected bool m_started = false;
	protected bool bombIsArmed = false; // a correctly planted and located bomb is automatically armed
	protected bool bombInPlay = false;  // should only ever be 1 bomb in play
	protected int bombCarrier = -1;	    // and one (or no) character_id carrying it
	protected int bombFaction = -1;     // the faction_id of the bombCarrier
	protected string bombPosition = ""; // xxx.xxx yyy.yyy zzz.zzz

	protected float BOMB_POS_UPDATE_TIME = 10.0;
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
		if (!bombInPlay) {
			// get all the players
			array<const XmlElement@> players = getPlayers(m_metagame);
			uint i = rand(0, players.length() - 1);
			// get a specific player's character
			const XmlElement@ player = players[i];
			bombCarrier = player.getIntAttribute("character_id");
			// and give that character the bomb
			addBombToBackpack(bombCarrier);
			_log("** SND: gave player (id: " + bombCarrier + ") the bomb", 1);
			// get detailed info about that character
			const XmlElement@ bomber = getCharacterInfo(m_metagame, bombCarrier);
			// record where the bomb is and who has it this round
			bombPosition = bomber.getStringAttribute("position");
			bombFaction = bomber.getIntAttribute("faction_id");
			// let friendlies know where the bomb is
			markBombPosition(getBombPosition(), bombFaction);
			// we got a game going on now
			bombInPlay = true;
		} else { _log("** SND: Refusing to add a bomb. Already one in play", 1); }
	}

	// --------------------------------------------
	protected string getBombPosition() {
		if (bombInPlay) {
			// gets and returns current location of the bombCarrier
			// relies on bombCarrier int to be updated when the bomb changes hands, is dropped, etc.
			// see handleItemDropEvent method
			if (bombCarrier == -1) {
				return bombPosition;
			} else {
				const XmlElement@ bomberLoc = getCharacterInfo(m_metagame, bombCarrier);
				string position = bomberLoc.getStringAttribute("position");
				bombPosition = position;
				return position;
			}
		} else { return "0 0 0"; }
	}

	// --------------------------------------------
	protected void markBombPosition(string position, int faction = -1, int charId = -1) {
		if (bombInPlay) {
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
			// get the bomb position
			bombPosition = event.getStringAttribute("position");
			// check if the bomb was placed in a valid targetLocation
			array<Vector3> validLocs = getTargetLocations(); // public method in snd_helpers.as
			for (uint i = 0; i < validLocs.length(); ++i) {
				if (checkRange(stringToVector3(bombPosition), validLocs[i], 15.0)) {
					_log("** SND: bomb is within 15 units of this targetLocation", 1);
					_log("** SND: The bomb has been planted", 1);
					bombCarrier = -1;
					// spawn the actual bomb.projectile
					string activateBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='grenade' instance_key='bomb.projectile' activated='1' position='" + bombPosition + "' />";
					m_metagame.getComms().send(activateBombCmd);
					_log("** SND: Bomb countdown started!", 1);
					bombIsArmed = true;
					break;
				} else {
					_log("** SND: bomb is not within 15 units of this targetLocation", 1);
				}
			}
			if (!bombIsArmed) {
				// Some goofball planted the bomb in the wrong place. Give them another chance...
				addBombToBackpack(bombCarrier);
				// probably worth berating the player via notice / message as well.
			}
			//update the bomb marker for friendlies
			markBombPosition(getBombPosition(), event.getIntAttribute("owner_id"));
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
			// update the bombPosition
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
						markBombPosition(getBombPosition());
						break;
					case 2:
						_log("** SND: Bomb dropped into backpack", 1);
						markBombPosition(getBombPosition(), bombFaction);
						break;
					default: // shouldn't ever get here, but sanity
				_log("** SND: WARNING! Bomb was dropped in target_container_type_id: " + event.getIntAttribute("target_container_type_id") + ". Not tracked!", 1);
				}
			} else {
				// otherwise, it's probably a fake bomb!
				// nope, this triggers when original guy picks up the dropped bomb and puts into backpack
				_log("** SND: WARNING! Bomb dropped by illegitimate character", 1);
			}
		}
	}

	// alert all when bomb explodes (bombers win, disarmers lose --> cycle map)
	// bombInPlay = false;
	// alert all when bomb defused (disarmers win, bombers lose --> cycle map)
	// bombInPlay = false;

	// -----------------------------
	protected void addBombToBackpack(int charId) {
		// assign / override equipment to player character
		bombCarrier = charId;
		_log("** SND: Adding bomb to backpack of player (id: " + charId + ")", 1);
		string addBombCmd = "<command class='update_inventory' character_id='" + charId + "' container_type_class='backpack'><item class='weapon' key='bomb_resource.weapon' /></command>";
		m_metagame.getComms().send(addBombCmd);
	}

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
		if (bombInPlay) {
			bombPosUpdateTimer -= time;
			if (bombPosUpdateTimer < 0.0) {
				markBombPosition(getBombPosition(), bombFaction);
				bombPosUpdateTimer = BOMB_POS_UPDATE_TIME;
			}
		}
	}
}
