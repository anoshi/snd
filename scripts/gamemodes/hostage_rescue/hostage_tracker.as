#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class HostageTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected bool m_started = false;

	protected int alive; 		// when m_metagame.getTrackedCharIds().length() == 0, all hostages are accounted for

	// --------------------------------------------
	HostageTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting HostageTracker tracker", 1);
		string trackCharSpawn = "<command class='set_metagame_event' name='character_spawn' enabled='1' />";
		m_metagame.getComms().send(trackCharSpawn);
		string trackCharKill = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(trackCharKill);
		// string trackCharDie = "<command class='set_metagame_event' name='character_die' enabled='1' />";
		// m_metagame.getComms().send(trackCharDie);
		// disable CommanderAI / orders
		m_metagame.disableCommanderAI();
		addHostages();
		m_started = true;
	}

	///////////////////////
	// HOSTAGE LIFECYCLE //
	///////////////////////
	// --------------------------------------------
	protected void addHostages() {
		array<Vector3> hostageStartPositions = m_metagame.getTargetLocations();
		_log("** SND: Spawning hostages", 1);
		for (uint i = 0; i < hostageStartPositions.length(); ++i) {
			// spawn a hostage (faction 0) at each location.
			string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + hostageStartPositions[i].toString() + "' instance_key='hostage' /></command>";
			m_metagame.getComms().send(spawnCommand);
		}
		alive = hostageStartPositions.length();
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
		// soldier_group_name=hostage
		// wounded=0
		// xp=0

		const XmlElement@ hostage = event.getFirstElementByTagName("character");
		// hostages have own soldier group. If not a hostage, bail.
		if (hostage.getStringAttribute("soldier_group_name") != "hostage") {
			return;
		}
		int charId = hostage.getIntAttribute("id");
		_log("** SND: Adding a hostage for tracking! Id: " + charId, 1);
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
		// soldier_group_name=hostage
		// wounded=0
		// xp=0

		const XmlElement@ target = event.getFirstElementByTagName("target");
		// only concerned with killed hostages
		if (target.getStringAttribute("soldier_group_name") != "hostage") {
			return;
		}
		int hostageCharId = target.getIntAttribute("id");
		_log("** SND: Hostage (id: " + hostageCharId + " was killed!", 1);
		// penalise killer
		const XmlElement@ killer = event.getFirstElementByTagName("killer");
		int pKillerId = killer.getIntAttribute("player_id");
		if (pKillerId >= 0) {
			// TODO Rollover RP reward (penalty) to next round - looks like you can't do a negative RP reward on the fly
			string penaliseHostageKiller = "<command class='rp_reward' character_id='" + pKillerId + "' reward='-1200'></command>";
			m_metagame.getComms().send(penaliseHostageKiller);
			m_metagame.addRP(pKillerId, -1200);
			sendFactionMessage(m_metagame, -1, "A hostage has been executed!");
		}
		// stop tracking the hostage
		m_metagame.removeTrackedCharId(hostageCharId);
		alive = m_metagame.getTrackedCharIds().length();
		if (alive <= 0) {
			winRound(1);
		}
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
		if (alive > 0) {
			sleep(2); // allow other hitboxHandlers to do their stuff
			_log("** SND: hostage_tracker checking number of hostages still being tracked", 1);
			alive = m_metagame.getTrackedCharIds().length();
			int rescued = m_metagame.getNumExtracted();
			if (alive == 0) {
				_log("** SND: All Hostages rescued or killed. End round or go to attrition?", 1);
				// TODO move this into an end-of-round cash thingo.
				// scoring ref: https://counterstrike.fandom.com/wiki/Hostage
				array<int> ctIds = getFactionPlayerCharacterIds(m_metagame, 0);
				for (uint j = 0; j < ctIds.length() ; ++j) {
					string hostageRescuedReward = "<command class='rp_reward' character_id='" + ctIds[j] + "' reward='" + (850 * rescued) + "'></command>";
					m_metagame.getComms().send(hostageRescuedReward);
					m_metagame.addRP(ctIds[j], (850 * rescued));
				}
				if ((rescued > 2) && (m_metagame.getTrackedCharIds().length() == 0)) {
					winRound(0);
				}
				// if all hostages are dead, it comes down to clock timeout or attrition.
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
