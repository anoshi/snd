#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class BombTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected bool m_started = false;
	protected bool bombIsArmed = false; // a correctly planted and located bomb is automatically armed
	protected bool bombInPlay = false;  // should only ever be 1 bomb in play
	protected int bombCarrier = -1;	    // and one (or no) character_id carrying it
	protected int bombFaction = -1;     // the faction_id of the current bombCarrier
	protected int bombOwnerFaction = -1;// the faction_id of the faction who start the round with the bomb
	protected string bombPosition = ""; // xxx.xxx yyy.yyy zzz.zzz

	protected float BOMB_POS_UPDATE_TIME = 10.0;	// how often the position of the bomb is checked
	protected float bombPosUpdateTimer = 0.0;		// the time remaining until the next update

	protected float bombTimer = 45.0;	// when bombIsArmed, the timer starts.

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
			// get the characterIds for all terrorists
			array<int> terPlayerIds = getFactionPlayerCharacterIds(m_metagame, 1); // terrorsts are faction 1
			if (terPlayerIds.length() > 0) {
				// choose a terrorist at random to give the bomb to
				uint i = rand(0, terPlayerIds.length() - 1);
				bombCarrier = terPlayerIds[i];
			} else {
				_log("** SND: No terrorists! Maybe single player? Giving a random player the bomb.", 1);
				uint i = rand(0, players.length() - 1);
				// get a specific player's character
				const XmlElement@ player = players[i];
				bombCarrier = player.getIntAttribute("character_id");
			}
			// and give that character the bomb
			addItemToBackpack("bomb.weapon", bombCarrier);
			_log("** SND: gave player (id: " + bombCarrier + ") the bomb", 1);
			// get detailed info about that character
			const XmlElement@ bomber = getCharacterInfo(m_metagame, bombCarrier);
			// record where the bomb is and who has it this round
			bombPosition = bomber.getStringAttribute("position");
			bombFaction = bomber.getIntAttribute("faction_id");
			// another faction may steal the bomb. Remember who can use the bomb to win the round.
			bombOwnerFaction = bomber.getIntAttribute("faction_id");
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
				_log("** SND: nobody had the bomb at last check. It's either on the ground or someone has it equipped", 1);
				// confirm noone has picked up the bomb directly to secondary weapon slot, which is not tracked
				// get all the players
				array<const XmlElement@> players = getPlayers(m_metagame);
				// for each player, get character_id and use to inspect the secondary weapon slot in the inventory
				for (uint i = 0; i < players.length(); ++i) {
					int playerCharId = players[i].getIntAttribute("character_id");
					const XmlElement@ playerInv = getPlayerInventory(m_metagame, playerCharId);
					array<const XmlElement@> pInv = playerInv.getElementsByTagName("item");
					// element '1' is the secondary weapon slot, the only place the bomb could be and not be detected by events.
					if (pInv[1].getStringAttribute("key") == "bomb.weapon") {
						_log("** SND: Found who has the bomb. Updating bomb holder and location info", 1);
						bombCarrier = playerCharId;
						bombFaction = players[i].getIntAttribute("faction_id");
						break;
					}
				}
				_log("** SND: noone has the bomb, must be on the ground...", 1);
				return bombPosition; // unchanged
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
	protected void markBombPosition(string position, int faction = -1, bool enabled = true) {
		if (bombInPlay) {
			// marks the current location of the bomb on screen, screen-edge, and/or map overlay
			// by default, all factions are alerted to the location of the bomb. Pass a faction_id as the int to override
			_log("** SND: Marking location of bomb", 1);

			string bombMarkerCmd = "";
			if (faction == -1 ) {
				// mark for everybody
				array<Faction@> allFactions = m_metagame.getFactions();
				for (uint f = 0; f < allFactions.length(); ++f) {
					bombMarkerCmd = "<command class='set_marker' id='" + (8008 + f) + "' enabled='" + (enabled ? 1 : 0) + "' atlas_index='2' faction_id='" + f + "' text='' position='" + position + "' color='#FFFFFF' size='1.0' show_in_game_view='0' show_in_map_view='1' show_at_screen_edge='0' />";
				}
			} else {
				// mark for friendlies only
				bombMarkerCmd = "<command class='set_marker' id='8008' enabled='" + (enabled ? 1 : 0) + "' atlas_index='2' faction_id='" + faction + "' text='' position='" + position + "' color='#FFFFFF' size='1.0' show_in_game_view='1' show_in_map_view='1' show_at_screen_edge='1' />";
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

		array<Faction@> allFactions = m_metagame.getFactions();

		if (vehKey == "bomb_planted.vehicle") {
			// sanity
			if (bombIsArmed) {
				return;
			}
			// get the bomb position
			bombPosition = event.getStringAttribute("position");
			// check if the bomb was placed in a valid targetLocation
			array<Vector3> validLocs = m_metagame.getTargetLocations();
			for (uint i = 0; i < validLocs.length(); ++i) {
				if (checkRange(stringToVector3(bombPosition), validLocs[i], 8.0)) {
					_log("** SND: bomb has been planted within 8 units of " + validLocs[i].toString() + ".", 1);
					array<int> planterTeamCharIds = getFactionPlayerCharacterIds(m_metagame, bombOwnerFaction);
					for (uint j = 0; j < planterTeamCharIds.length() ; ++j) {
						string rewardPlanterTeamChar = "<command class='rp_reward' character_id='" + planterTeamCharIds[j] + "' reward='800'></command>";
						m_metagame.getComms().send(rewardPlanterTeamChar);
					}
					string rewardBombPlanter = "<command class='rp_reward' character_id='" + bombCarrier + "' reward='300'></command>";
					m_metagame.getComms().send(rewardBombPlanter);
					bombCarrier = -1;
					// create the bomb
					string placeBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='vehicle' instance_key='bomb_armed.vehicle' position='" + bombPosition + "' />";
					m_metagame.getComms().send(placeBombCmd);
					// create pulsing light at location
					string highlightBombCmd = "<command class='create_instance' faction_id='" + bombFaction + "' instance_class='grenade' instance_key='bomb_armed.projectile' activated='1' position='" + bombPosition + "' />";
					m_metagame.getComms().send(highlightBombCmd);
					// start the bombTimer clock
					_log("** SND: Bomb countdown started!", 1);
					for (uint f = 0; f < allFactions.length(); ++f) {
						playSound(m_metagame, "bombpl.wav", f);
					}
					sendFactionMessage(m_metagame, -1, "THE BOMB HAS BEEN PLANTED!");
					// remove bomb marker
					markBombPosition(getBombPosition(), bombFaction, false);
					bombIsArmed = true;
					break;
				} else {
					_log("** SND: bomb not planted within 8 units of " + validLocs[i].toString() + ". Checking next targetLocation.", 1);
				}
			}
			if (!bombIsArmed) {
				// Some goofball planted the bomb in the wrong place. Give them another chance...
				addItemToBackpack("bomb.weapon", bombCarrier);
				// probably worth berating the player via notice / message as well.
			}
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
				string rewardBombDefuser = "<command class='rp_reward' character_id='" + event.getIntAttribute("character_id") + "' reward='300'></command>";
				m_metagame.getComms().send(rewardBombDefuser);
				array<int> defuserTeamCharIds = getFactionPlayerCharacterIds(m_metagame, -(bombOwnerFaction) +1);
				for (uint i = 0; i < defuserTeamCharIds.length() ; ++i) {
					string rewardDefuserTeamChar = "<command class='rp_reward' character_id='" + defuserTeamCharIds[i] + "' reward='3600'></command>";
					m_metagame.getComms().send(rewardDefuserTeamChar);
				}
				for (uint f = 0; f < allFactions.length(); ++f) {
					playSound(m_metagame, "bombdef.wav", f);
				}
				sendFactionMessage(m_metagame, -1, "THE BOMB HAS BEEN DEFUSED!");
				bombIsArmed = false;
				// defusingTeam has won
				winRound(-(bombOwnerFaction) +1); // -1 + 1 = 0. -0 + 1 = 1
				// winRound(event.getIntAttribute("owner_id")); // validating will allow for more than 2 faction games
			} else {
				_log("** SND: wire cutters were not used within 2 units of the bomb's location. Bomb remains active", 1);
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
					_log("** SND: Bomb (" + itemKey + ") dropped onto ground", 1);
					// bad idea! Now everyone gets to find out where the bomb is
					bombCarrier = -1;
					markBombPosition(getBombPosition());
					break;
				case 1:
					_log("** SND: Bomb (" + itemKey + ") sold to armoury", 1);
					addItemToBackpack("bomb.weapon", bombCarrier);
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
	protected void winRound(uint faction, uint consecutive = 1) {
		string winLoseCmd = "";
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint f = 0; f < allFactions.length(); ++f) {
			if (f == faction) {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
			} else {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' lose='1'></command>";
				array<int> losingTeamCharIds = getFactionPlayerCharacterIds(m_metagame, -faction + 1);
				for (uint i = 0; i < losingTeamCharIds.length() ; ++i) {
					string rewardLosingTeamChar = "<command class='rp_reward' character_id='" + losingTeamCharIds[i] + "' reward='" + (900 + (consecutive * 500)) + "'></command>";
					m_metagame.getComms().send(rewardLosingTeamChar);
				}
			}
			m_metagame.getComms().send(winLoseCmd);
			// sound byte to advise which team won
			if (faction == 0) {
				playSound(m_metagame, "ctwin.wav", f);
			} else if (faction == 1) {
				playSound(m_metagame, "terwin.wav", f);
			}
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
			if ((bombPosUpdateTimer < 0.0) && (!bombIsArmed)) {
				markBombPosition(getBombPosition(), bombFaction);
				bombPosUpdateTimer = BOMB_POS_UPDATE_TIME;
			}
			if (bombIsArmed) {
				bombTimer -= time;
			}
			if (bombTimer <= 0.0) {
				// blow up the bomb. Regardless of who planted it, the original owner faction will win (it's their bomb, planted at one of their target locations)
				string detonateBombCmd = "<command class='create_instance' faction_id='" + bombOwnerFaction + "' instance_class='grenade' instance_key='bomb.projectile' activated='1' position='" + bombPosition + "' />";
				m_metagame.getComms().send(detonateBombCmd);
				bombIsArmed = false;
				array<int> planterTeamCharIds = getFactionPlayerCharacterIds(m_metagame, bombOwnerFaction);
				for (uint i = 0; i < planterTeamCharIds.length() ; ++i) {
					string rewardPlanterTeamChar = "<command class='rp_reward' character_id='" + planterTeamCharIds[i] + "' reward='1900'></command>";
					m_metagame.getComms().send(rewardPlanterTeamChar);
				}
				winRound(bombOwnerFaction);
			}
		}
	}
}