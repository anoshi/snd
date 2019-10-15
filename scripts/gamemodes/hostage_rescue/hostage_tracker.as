#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class HostageTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected bool m_started = false;

	protected array<int> hostageIds;	// dynamic list of living hostage character Ids
	// alive = hostageIds.length();
	protected int rescued = 0; // count of rescued hostages.
	// if > 2 at match end && hostageIds.length() == 0, full CT win

	protected array<int> hostageEscorts;    // char or playerIds of CTs escorting hostages. Probably can't track this

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
		string trackCharDie = "<command class='set_metagame_event' name='character_die' enabled='1' />";
		m_metagame.getComms().send(trackCharDie);
		addHostages();
		m_started = true;
	}

	///////////////////////
	// HOSTAGE LIFECYCLE //
	///////////////////////
	// --------------------------------------------
	protected void addHostages() {
		hostageIds.clear();
		array<Vector3> hostageStartPositions = m_metagame.getTargetLocations();
		_log("** SND: Spawning hostages", 1);
		for (uint i = 0; i < hostageStartPositions.length(); ++i) {
			// spawn a hostage (faction 0) at each location.
			string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + hostageStartPositions[i].toString() + "' instance_key='hostage' /></command>";
			m_metagame.getComms().send(spawnCommand);
		}
	}

	// // --------------------------------------------
	// array<int> getHostageIds() {
	// 	_log("** SND: hostage_tracker advising " + hostageIds.length() + " hostage IDs", 1);
	// 	return hostageIds;
	// }

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
		hostageIds.insertLast(charId);
		_log("** SND: Added a hostage! Id: " + charId, 1);
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

		const XmlElement@ hostage = event.getFirstElementByTagName("target");
		// only concerned with killed hostages
		if (hostage.getStringAttribute("soldier_group_name") != "hostage") {
			return;
		}
		int hostageCharId = hostage.getIntAttribute("id");
		_log("** SND: Hostage (id: " + hostageCharId + " was killed!", 1);
		int deadChar = hostageIds.find(hostage.getIntAttribute("id"));
		m_metagame.removeTrackedCharId(hostageCharId);
		if (deadChar > -1) {
			hostageIds.removeAt(deadChar);
			// could do a sanity here to confirm hostageIds.sort() == m_metagame.trackedCharIds.sort();
		} else { _log("** SND: couldn't find dead hostage id in hostageIds list", 1); }
	}

	// died (confirm otherwise)
	// --------------------------------------------
	protected void handleCharacterDieEvent(const XmlElement@ event) {
		// TagName=character_die
		// character_id=4

		const XmlElement@ deadChar = event.getFirstElementByTagName("character");
		int deadCharId = deadChar.getIntAttribute("id");
		if (hostageIds.find(deadCharId) < 0) {
			return; // (we've already handled the death)
		} else {
			if (deadChar.getStringAttribute("soldier_group_name") != "hostage") {
				_log("** SND: Non-hostage character " + deadChar.getStringAttribute("name") + " (id: " + deadChar.getIntAttribute("id") + ") was killed, but isn't being processed in hostage_tracker.as", 1);
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
