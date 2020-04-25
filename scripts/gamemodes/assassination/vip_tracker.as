#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class VIPTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected bool m_started = false;
	protected bool inPlay = false; 		// when m_metagame.getTrackedCharIds().length() == 0, the vip has escaped or been killed
	protected bool vipKilled = false;	// used to differentiate between the VIP being assassinated or dying in another manner
	protected int theVIPId;				// the characterId of the VIP.

	protected float VIP_POS_UPDATE_TIME = 5.0;	// how often the position of the VIP is checked
	protected float vipPosUpdateTimer = 10.0;	// the time remaining until the next update

	// --------------------------------------------
	VIPTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting VIPTracker tracker", 1);
		string trackCharSpawn = "<command class='set_metagame_event' name='character_spawn' enabled='1' />";
		m_metagame.getComms().send(trackCharSpawn);
		string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
		string trackCharDie = "<command class='set_metagame_event' name='character_die' enabled='1' />";
		m_metagame.getComms().send(trackCharDie);
		// disable Commander orders to AI
		m_metagame.disableCommanderAI();
		m_metagame.setNumExtracted(0);
		addVIP(); // inPlay = true
		m_metagame.setTrackPlayerDeaths(true);
		m_started = true;
	}

	///////////////////
	// VIP LIFECYCLE //
	///////////////////
	// --------------------------------------------
	protected void addVIP() {
		_log("** SND: Adding VIP", 1);
		if (inPlay) {
			return;
		} else {
			// from all players, get the characterIds for all counter-terrorists only
			array<const XmlElement@> players = getPlayers(m_metagame);
			array<int> ctPlayerIds = m_metagame.getFactionPlayerCharacterIds(0); // counter terrorsts are faction 0
			int charId = -1; // will store the character_id of who the VIP spawns next to
			if (ctPlayerIds.length() > 0) {
				// choose a counter terrorist at random
				uint i = rand(0, ctPlayerIds.length() - 1);
				charId = ctPlayerIds[i];
			} else {
				_log("** SND: No counter terrorists! Maybe single player? Giving a terrorist the VIP.", 1);
				uint i = rand(0, players.length() - 1);
				// get a specific player's character
				const XmlElement@ player = players[i];
				charId = player.getIntAttribute("character_id");
			}
			const XmlElement@ vipFriend = getCharacterInfo(m_metagame, charId);
			string playerPos = vipFriend.getStringAttribute("position");
			Vector3 pos = stringToVector3(playerPos);
			pos.m_values[0] += 5.0;
			_log("** SND: Spawning VIP", 1);
			// spawn a vip (faction 0) very near the requested location.
			string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + pos.toString() + "' instance_key='vip' /></command>";
			m_metagame.getComms().send(spawnCommand);
			playSound(m_metagame, "vip.wav", 0);
			markVIPPosition(pos.toString());
			inPlay = true;
			m_metagame.setMatchEndOverride(); // cannot win a VIP mission if the VIP is alive or has not escaped!
			_log("** SND: VIP has spawned near player " + charId + " at position: " + playerPos, 1);
		}
	}

	// --------------------------------------------
	protected string getVIPPosition() {
		if (inPlay) {
			// gets and returns current location of the VIP
			const XmlElement@ vipInfo = getCharacterInfo(m_metagame, theVIPId);
			string position = vipInfo.getStringAttribute("position");
			return position;
		} else {
			_log("** SND: can't locate the VIP :-(", 1);
			return "0 0 0";
		}
	}

	// --------------------------------------------
	protected void markVIPPosition(string position, int faction = 0, bool enabled = true) {
		if (inPlay) {
			// marks the current location of the VIP on screen, screen-edge, and/or map overlay
			// by default, only counter terrorists (faction 0) are alerted to the VIP's location. Pass a faction_id as the int to override
			_log("** SND: Marking location of vip", 1);
			string vipMarkerCmd = "<command class='set_marker' id='8008' enabled='" + (enabled ? 1 : 0) + "' atlas_index='4' faction_id='" + faction + "' text='' position='" + position + "' color='#FFFFFF' size='1.0' show_in_game_view='1' show_in_map_view='1' show_at_screen_edge='1' />";
			m_metagame.getComms().send(vipMarkerCmd);
			_log("** SND: Updated vip location marker!", 1);
		}
	}

	// spawned
	// --------------------------------------------
	protected void handleCharacterSpawnEvent(const XmlElement@ event) {
		// TagName=character_spawn
		// character_id=4

		// TagName=character
		// dead=0
		// faction_id=0
		// id=4
		// name=CT: 48
		// player_id=-1
		// position=525.159 0 558.281
		// rp=0
		// soldier_group_name=vip
		// wounded=0
		// xp=0

		const XmlElement@ vip = event.getFirstElementByTagName("character");
		// vips have own soldier group. If not a vip, bail.
		if (vip.getStringAttribute("soldier_group_name") != "vip") {
			return;
		}
		theVIPId = vip.getIntAttribute("id");
		_log("** SND: Now tracking the VIP, id: " + theVIPId, 1);
		m_metagame.addTrackedCharId(theVIPId);
	}

	// killed
	// --------------------------------------------
	protected void handleCharacterKillEvent(const XmlElement@ event) {
		// TagName=character_kill
		// key=9x19mm_sidearm.weapon
		// method_hint=hit

		// TagName=killer
		// block=10 15
		// dead=0
		// faction_id=0
		// id=3
		// leader=1
		// name=CT: 40
		// player_id=0
		// position=354.895 7.42591 530.407
		// rp=800
		// soldier_group_name=default
		// wounded=0
		// xp=0

		// TagName=target
		// block=9 15
		// dead=0
		// faction_id=0
		// id=4
		// leader=1
		// name=CT: 83
		// player_id=-1
		// position=336.959 6.21743 533.692
		// rp=0
		// soldier_group_name=vip
		// wounded=0
		// xp=0

		const XmlElement@ target = event.getFirstElementByTagName("target");
		// only concerned with killed vip
		if (target.getStringAttribute("soldier_group_name") != "vip") {
			return;
		}
		int vipCharId = target.getIntAttribute("id");
		_log("** SND: VIP (id: " + vipCharId + ") was killed!", 1);
		// stop tracking the vip
		m_metagame.removeTrackedCharId(vipCharId);

		const XmlElement@ killer = event.getFirstElementByTagName("killer");
		if (killer !is null) {
			vipKilled = true;
			int pKillerId = killer.getIntAttribute("player_id");
			int killerCharId = killer.getIntAttribute("id");
			if (pKillerId >= 0) {
				if (killer.getIntAttribute("faction_id") == target.getIntAttribute("faction_id")) {
					// teamkill, penalise!
					string penaliseVIPTeamKiller = "<command class='rp_reward' character_id='" + killerCharId + "' reward='-3500'></command>";
					m_metagame.getComms().send(penaliseVIPTeamKiller);
					m_metagame.addRP(killerCharId, -3500);
				} else {
					// Terrorist / enemy killed VIP. Winner
					string rewardVIPKiller = "<command class='rp_reward' character_id='" + killerCharId + "' reward='500'></command>";
					m_metagame.getComms().send(rewardVIPKiller);
					m_metagame.addRP(killerCharId, 500);
					array<int> tIds = m_metagame.getFactionPlayerCharacterIds(killer.getIntAttribute("faction_id"));
					for (uint i = 0; i < tIds.length() ; ++i) {
						string vipKilledReward = "<command class='rp_reward' character_id='" + tIds[i] + "' reward='" + 2000 + "'></command>";
						m_metagame.getComms().send(vipKilledReward);
						m_metagame.addRP(tIds[i], 2000);
					}
				}
				winRound(-(target.getIntAttribute("faction_id")) +1);
				sendFactionMessage(m_metagame, -1, "The VIP has been assassinated!");
			}
		}
		// else allow handleCharacterDieEvent to manage it.
	}

	// died (confirm otherwise)
	// --------------------------------------------
	protected void handleCharacterDieEvent(const XmlElement@ event) {
		// TagName=character_die
		// character_id=4

		// TagName=character
		// ...
		// id=10
		// ...
		// soldier_group_name=vip

		sleep(2); // allow some time to pass in case handleCharacterKillEvent method is (still) handling the VIP death;

		if (vipKilled) {
			return;
		} else {
			const XmlElement@ eventChar = event.getFirstElementByTagName("character");
			int deadCharId = eventChar.getIntAttribute("id");
			const XmlElement@ deadChar = getCharacterInfo(m_metagame, deadCharId);
			if (deadChar.getStringAttribute("soldier_group_name") == 'vip') {
				sendFactionMessage(m_metagame, -1, "The VIP did not survive the mission");
				winRound(-(deadChar.getIntAttribute("faction_id"))+1);
			}
		}
	}

	// --------------------------------------------
	protected void vipEscaped() {
		_log("** SND: The VIP has escaped. End round", 1);
		array<int> ctIds = m_metagame.getFactionPlayerCharacterIds(0);
		for (uint j = 0; j < ctIds.length() ; ++j) {
			string vipRescuedReward = "<command class='rp_reward' character_id='" + ctIds[j] + "' reward='" + 2500 + "'></command>";
			m_metagame.getComms().send(vipRescuedReward);
			m_metagame.addRP(ctIds[j], 2500);
		}
		winRound(0);
	}

	// --------------------------------------------
	protected void winRound(uint faction, uint consecutive = 1) {
		// only get here after a win condition has been met. Ok to remove match end override.
		m_metagame.setMatchEndOverride(false);
		inPlay = false;
		string winLoseCmd = "";
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint f = 0; f < allFactions.length(); ++f) {
			if (f == faction) {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' win='1'></command>";
			} else {
				winLoseCmd = "<command class='set_match_status' faction_id='" + f + "' lose='1'></command>";
				array<int> losingTeamCharIds = m_metagame.getFactionPlayerCharacterIds(-faction + 1);
				for (uint i = 0; i < losingTeamCharIds.length() ; ++i) {
					string rewardLosingTeamChar = "<command class='rp_reward' character_id='" + losingTeamCharIds[i] + "' reward='" + (900 + (consecutive * 500)) + "'></command>";
					m_metagame.getComms().send(rewardLosingTeamChar);
					m_metagame.addRP(losingTeamCharIds[i], (900 + (consecutive * 500)));
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
		m_metagame.setTrackPlayerDeaths(false);
		m_metagame.setNumExtracted(0);
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
		if (inPlay) {
			vipPosUpdateTimer -= time;
			if (vipPosUpdateTimer < 0.0) {
				if (m_metagame.getNumExtracted() > 0) {
					vipEscaped();
				} else {
				markVIPPosition(getVIPPosition());
				vipPosUpdateTimer = VIP_POS_UPDATE_TIME;
				}
			}
		}
	}
}
