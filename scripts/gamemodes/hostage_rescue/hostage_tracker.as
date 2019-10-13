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

	protected array<int> hostageEscorts;    // char or playerIds of CTs escorting hostages

	protected array<Vector3> hostageStartPositions; // xxx.xxx yyy.yyy zzz.zzz

	// extraction vars. May want to move out to own class when assassination mode is included
	protected array<const XmlElement@> m_extractionAreas;
	protected array<string> m_trackedExtractionAreas;

	// --------------------------------------------
	HostageTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting HostageTracker tracker", 1);
		string charSpawnTracker = "<command class='set_metagame_event' name='character_spawn' enabled='1' />";
		m_metagame.getComms().send(charSpawnTracker);
		string charKillTracker = "<command class='set_metagame_event' name='character_kill' enabled='1' />";
		m_metagame.getComms().send(charKillTracker);
		// track edge cases of hostage dying of natural causes, out of bounds, etc?
		//string charDieTracker = "<command class='set_metagame_event' name='character_die' enabled='1' />";
		//m_metagame.getComms().send(charDieTracker);
		addHostages();
		m_started = true;
	}

	///////////////////////
	// HOSTAGE LIFECYCLE //
	///////////////////////
	// --------------------------------------------
	protected void addHostages() {
		hostageIds.clear();
		hostageStartPositions = m_metagame.getTargetLocations();
		_log("** SND: Spawning hostages", 1);
		for (uint i = 0; i < hostageStartPositions.length(); ++i) {
			// spawn a hostage (faction 0) at each location.
			string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + hostageStartPositions[i].toString() + "' instance_key='hostage' /></command>";
			m_metagame.getComms().send(spawnCommand);
		}
	}

	// spawned
	protected void handleCharacterSpawnEvent(const XmlElement@ event) {
		hostageIds.insertLast(charId);
	}

	// killed
	protected void handleCharacterKillEvent(const XmlElement@ event) {
		// int deadGuy = hostageIds.find(targetId);
		// hostageIds.removeAt(deadGuy);
	}

	// otherwise died
	protected void handleCharacterSpawnEvent(const XmlElement@ event) {
		// if deadChar not in hostageIds, return (already handled the death)
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
