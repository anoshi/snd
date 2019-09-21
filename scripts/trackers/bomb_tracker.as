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

	protected float BOMB_POS_UPDATE_TIME = 10.0;	// how often the position of the bomb is checked
	protected float bombPosUpdateTimer = 0.0;		// the time remaining until the next update

	protected float bombTimer = 30.0;	// when bombIsArmed, the timer starts.

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
			addItemToBackpack("bomb.weapon", bombCarrier);
			_log("** SND: gave player (id: " + bombCarrier + ") the bomb", 1);
			// get detailed info about that character
			const XmlElement@ bomber = getCharacterInfo(m_metagame, bombCarrier);
			// record where the bomb is and who has it this round
			bombPosition = bomber.getStringAttribute("position");
			bombFaction = bomber.getIntAttribute("faction_id");
			// give the other team wire_cutters!
			for (uint p = 0; p < players.length(); ++p) {
				int playerCharId = players[p].getIntAttribute("character_id");
				const XmlElement@ thisPlayer = getCharacterInfo(m_metagame, playerCharId);
				if (thisPlayer.getIntAttribute("faction_id") != bombFaction) {
					addItemToBackpack("wire_cutters.weapon", playerCharId);
				}
			}
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
		} else {
			_log("** SND: can't locate bomb carrier or bomb :-(", 1);
			return "0 0 0";
		}
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

		// in this game mode, a dummy vehicle (with 0 ttl) is spawned when the bomb.weapon is placed (arming the bomb.projectile)
		// this allows us to ensure the bomb has been placed within a valid target area, and if not, to ensure the bomb

		// we are only interested in the destruction of 'bomb_*'-related "vehicles"
        if (!startsWith(event.getStringAttribute("vehicle_key"), "bomb_")) {
			return;
		}
		_log("** SND: BombHandler going to work!", 1);
		// variablise attributes
		string vehKey = event.getStringAttribute("vehicle_key");

		if (vehKey == "bomb_planted.vehicle") {
			// sanity
			if (bombIsArmed) {
				return;
			}
			// get the bomb position
			bombPosition = event.getStringAttribute("position");
			// check if the bomb was placed in a valid targetLocation
			array<Vector3> validLocs = getTargetLocations(); // public method in snd_helpers.as
			for (uint i = 0; i < validLocs.length(); ++i) {
				if (checkRange(stringToVector3(bombPosition), validLocs[i], 15.0)) {
					_log("** SND: bomb has been planted within 15 units of " + validLocs[i].toString() + ".", 1);
					bombCarrier = -1;
					// create the bomb
					string placeBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='vehicle' instance_key='bomb_armed.vehicle' position='" + bombPosition + "' />";
					m_metagame.getComms().send(placeBombCmd);
					// create pulsing light at location
					string highlightBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='grenade' instance_key='bomb_armed.projectile' activated='1' position='" + bombPosition + "' />";
					m_metagame.getComms().send(highlightBombCmd);
					// start the bombTimer clock
					_log("** SND: Bomb countdown started!", 1);
					sendFactionMessage(m_metagame, -1, "THE BOMB HAS BEEN PLANTED!");
					bombIsArmed = true;
					break;
				} else {
					_log("** SND: bomb not planted within 15 units of " + validLocs[i].toString() + ". Checking next targetLocation.", 1);
				}
			}
			if (!bombIsArmed) {
				// Some goofball planted the bomb in the wrong place. Give them another chance...
				addItemToBackpack("bomb.weapon", bombCarrier);
				// probably worth berating the player via notice / message as well.
			}
			//update the bomb marker for friendlies
			markBombPosition(getBombPosition(), event.getIntAttribute("owner_id"));
		} else if (vehKey == "bomb_defused.vehicle") {
			// sanity / no point checking if bomb hasn't been planted
			if (!bombIsArmed) {
				return;
			}
			// where were the wire cutters used?
			string snipPosition = event.getStringAttribute("position");
			// confirm the person who's used the wire cutters is immediately adjacent to the bomb
			if (checkRange(stringToVector3(snipPosition), stringToVector3(bombPosition), 2.0)) {
				_log("** SND: wire cutters used within 2 units of bomb location", 1);
				_log("** SND: The bomb has been defused", 1);
				sendFactionMessage(m_metagame, -1, "THE BOMB HAS BEEN DEFUSED!");
				bombIsArmed = false;
				//	defusingTeam has won
				winRound(-(bombFaction) +1); // -1 + 1 = 0. -0 + 1 = 1
				// winRound(event.getIntAttribute("owner_id")); // validating will allow for more than 2 faction games
			} else {
				_log("** SND: wire cutters were not used 2 units of the bomb's location. Bomb remains active", 1);
			}
		}
    }

	// alert team with bomb when bomb.weapon is dropped (item drops on ground through death or via inventory)
	// --------------------------------------------
	protected void handleItemDropEvent(const XmlElement@ event) {
		// character_id=11
		// item_class=0
		// item_key=bomb.weapon
		// item_type_id=53
		// player_id=0
		// position=359.807 7.54902 486.65
		// target_container_type_id=2 (backpack) id=0 (ground)

		// if it's not a bomb, this tracker isn't interested
		if (!startsWith(event.getStringAttribute("item_key"), "bomb")) {
			return;
		}
		// otherwise, continue
		string itemKey = event.getStringAttribute("item_key");
		string position = event.getStringAttribute("position");

		// this block deals only with the placeable bomb weapon
		if (itemKey == "bomb.weapon") {
			// update the bombPosition
			bombPosition = position;
			// and the carrier
			bombCarrier = event.getIntAttribute("character_id");
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
		}
	}

	// --------------------------------------------
	protected void winRound(uint faction) {
		string winLoseCmd = "";
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint f = 0; f < allFactions.length(); ++f) {
			if (f == faction) {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
			} else {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' lose='1'></command>";
			}
			m_metagame.getComms().send(winLoseCmd);
		}
		bombInPlay = false;
	}

	// -----------------------------
	protected void addItemToBackpack(string item, int charId) {
		if (item == "bomb.weapon") {
			bombCarrier = charId;
		}
		_log("** SND: Adding " + item + " to backpack of player (id: " + charId + ")", 1);
		string addItemCmd = "<command class='update_inventory' character_id='" + charId + "' container_type_class='backpack'><item class='weapon' key='" + item + "' /></command>";
		m_metagame.getComms().send(addItemCmd);
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
			if (bombIsArmed) {
				bombTimer -= time;
			}
			if (bombTimer <= 0.0) {
				// blow up the bomb
				string detonateBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='grenade' instance_key='bomb.projectile' activated='1' position='" + bombPosition + "' />";
				m_metagame.getComms().send(detonateBombCmd);
					bombIsArmed = false;
				winRound(bombFaction);
			}
		}
	}
}
