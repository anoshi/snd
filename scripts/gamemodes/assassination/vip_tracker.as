#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class VIPTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected bool m_started = false;
	protected bool inPlay = false; 		// when m_metagame.getTrackedCharIds().length() == 0, the vip has escaped or been killed

	// --------------------------------------------
	VIPTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting VIPTracker tracker", 1);
		string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
		// string trackCharDie = "<command class='set_metagame_event' name='character_die' enabled='1' />";
		// m_metagame.getComms().send(trackCharDie);
		// disable Commander orders to AI
		m_metagame.disableCommanderAI();
	}

	///////////////////
	// VIP LIFECYCLE //
	///////////////////
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

		// Triggers VIP spawn near the first player on CT side. Could be improved, but works for single-player test, plus cbf.
		_log("** SND: VIPTracker::handlePlayerSpawnEvent", 1);
		if (inPlay) {
			return;
		} else {
			const XmlElement@ player = event.getFirstElementByTagName("player");
			int factionId = player.getIntAttribute("faction_id");
			if (factionId == 0) {
				int charId = player.getIntAttribute("character_id");
				const XmlElement@ vipFriend = getCharacterInfo(m_metagame, charId);
				string playerPos = vipFriend.getStringAttribute("position");
				addVIP(playerPos);
				inPlay = true;
			}
		}

	}

	// --------------------------------------------
	protected void addVIP(string position) {
		Vector3 pos = stringToVector3(position);
		pos.m_values[0] += 5.0;
		_log("** SND: Spawning VIP", 1);
		// spawn a vip (faction 0) very near the requested location.
		string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + pos.toString() + "' instance_key='vip' /></command>";
		m_metagame.getComms().send(spawnCommand);
		m_started = true;

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
		int charId = vip.getIntAttribute("id");
		_log("** SND: Adding a vip for tracking! Id: " + charId, 1);
		m_metagame.addTrackedCharId(charId);
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
		_log("** SND: VIP (id: " + vipCharId + " was killed!", 1);
		// penalise killer
		const XmlElement@ killer = event.getFirstElementByTagName("killer");
		int pKillerId = killer.getIntAttribute("player_id");
		if (pKillerId >= 0) {
			// TODO Rollover RP reward (penalty) to next round - looks like you can't do a negative RP reward on the fly
			string penaliseVIPKiller = "<command class='rp_reward' character_id='" + pKillerId + "' reward='-1200'></command>";
			m_metagame.getComms().send(penaliseVIPKiller);
			sendFactionMessage(m_metagame, -1, "A vip has been executed!");
		}
		// stop tracking the vip
		m_metagame.removeTrackedCharId(vipCharId);
	}

	// died (confirm otherwise)
	// --------------------------------------------
	// protected void handleCharacterDieEvent(const XmlElement@ event) {
	// 	// TagName=character_die
	// 	// character_id=4

	// 	const XmlElement@ deadChar = event.getFirstElementByTagName("character");
	// 	int deadCharId = deadChar.getIntAttribute("id");
	// }

	// --------------------------------------------
	protected void handleHitboxEvent(const XmlElement@ event) {
		if (inPlay) {
			_log("** SND: vip_tracker checking number of vips still being tracked", 1);
			if (m_metagame.getTrackedCharIds().length() == 0) {
				inPlay = false;
			}
			int rescued = m_metagame.getNumExtracted();
			if (!inPlay) {
				_log("** SND: All VIPs rescued or killed. End round or go to attrition?", 1);
				// TODO move this into an end-of-round cash thingo.
				// scoring ref: https://counterstrike.fandom.com/wiki/VIP
				array<int> ctIds = getFactionPlayerCharacterIds(m_metagame, 0);
				for (uint j = 0; j < ctIds.length() ; ++j) {
					string vipRescuedReward = "<command class='rp_reward' character_id='" + ctIds[j] + "' reward='" + (850 * rescued) + "'></command>";
					m_metagame.getComms().send(vipRescuedReward);
				}
				if ((rescued > 2) && (m_metagame.getTrackedCharIds().length() == 0)) {
					winRound(0);
				}
				// if all vips are dead, it comes down to clock timeout or attrition.
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
	}
}
