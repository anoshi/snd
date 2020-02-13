#include "tracker.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"
#include "snd_helpers.as"

// --------------------------------------------
class HostageTracker : Tracker {
	protected GameModeSND@ m_metagame;

	protected bool m_started = false;

	protected int numHostages;			// how many hostages are spawned this round
	protected int knownExtracted;		// how many extracted hostages this tracker is aware of
	protected int activeHostages; 		// when m_metagame.getTrackedCharIds().length() == 0, all hostages are accounted for
	array<Vector3> activeHostageStartPositions;
	array<int> activeHostageMarkers;	// horribly dodgy way to deal with an issue I introduced when dynamically altering the above array's contents
	array<string> joinWavs = {"getouttahere.wav", "illfollow.wav", "letsdoit.wav", "letsgo.wav", "letshurry.wav", "letsmove.wav", "okletsgo.wav", "youlead.wav"};

	protected float hostageCheckTimer = 20.0;	// initial delay at round start before starting hostage location checks
	protected float CHECK_IN_INTERVAL = 8.0; 	// how often to check proximity of hostages to start markers
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
		// disable CommanderAI / orders
		m_metagame.disableCommanderAI();
		m_metagame.setNumExtracted(0);
		knownExtracted = m_metagame.getNumExtracted();
		addHostages();
		m_metagame.setTrackPlayerDeaths(true);
		m_started = true;
	}

	///////////////////////
	// HOSTAGE LIFECYCLE //
	///////////////////////
	// --------------------------------------------
	protected void addHostages() {
		array<Vector3> hostageStartPositions = m_metagame.getTargetLocations();
		activeHostageStartPositions = hostageStartPositions; // maintained later in checkProximityToHostageMarkers
		_log("** SND: Spawning hostages", 1);
		for (uint i = 0; i < hostageStartPositions.length(); ++i) {
			// spawn a hostage (faction 0) at each location.
			string spawnCommand = "<command class='create_instance' instance_class='character' faction_id='0' position='" + hostageStartPositions[i].toString() + "' instance_key='hostage' /></command>";
			m_metagame.getComms().send(spawnCommand);
			// populate marker tracking array
			activeHostageMarkers.insertLast(i);
		}
		numHostages = hostageStartPositions.length();
		activeHostages = numHostages;
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
		_log("** SND: Hostage (id: " + hostageCharId + ") was killed!", 1);
		// stop tracking the hostage
		array<int> hostageIds = m_metagame.getTrackedCharIds();
		if (hostageIds.find(hostageCharId) < 0) { // no longer tracked?
			_log("** SND: untracked hostage killed, no action taken", 1);
			return;
		} else {
			// stop tracking the hostage
			m_metagame.removeTrackedCharId(hostageCharId);
			// penalise killer
			const XmlElement@ killer = event.getFirstElementByTagName("killer");
			if (killer !is null) {
				int pKillerId = killer.getIntAttribute("player_id");
				int killerCharId = killer.getIntAttribute("id");
				if (pKillerId >= 0) {
					string penaliseHostageKiller = "<command class='rp_reward' character_id='" + killerCharId + "' reward='-1200'></command>";
					m_metagame.getComms().send(penaliseHostageKiller);
					m_metagame.addRP(killerCharId, -1200);
					sendFactionMessage(m_metagame, -1, "A hostage has been executed!");
					m_metagame.addScore(killer.getIntAttribute("faction_id"), -1);
				}
				array<Faction@> allFactions = m_metagame.getFactions();
				for (uint i = 0; i < allFactions.length(); ++i) {
					playSound(m_metagame, "hosdown.wav", i);
				}
			}
			// all hostages accounted for?
			activeHostages -= 1;
			_log("** SND: handleCharacterKillEvent Active Hostages: " + activeHostages, 1);
			if (activeHostages <= 0) {
				if (m_metagame.getNumExtracted() > 2) {
					winRound(0);
				} else {
					winRound(1);
				}
			}
		}
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
		// ...
		// soldier_group_name=hostage

		sleep(2); // allow some time to pass in case handleCharacterKillEvent method is (still) handling the hostage's death;

		const XmlElement@ deadChar = event.getFirstElementByTagName("character");
		if (deadChar.getStringAttribute("soldier_group_name") == 'hostage') {
			int hostageCharId = deadChar.getIntAttribute("id");
			array<int> hostageIds = m_metagame.getTrackedCharIds();
			if (hostageIds.find(hostageCharId) < 0) { // no longer tracked?
				_log("** SND: hostage was killed. Not processed by handleCharacterDieEvent method");
				return;
			} else {
				sendFactionMessage(m_metagame, -1, "A Hostage has died");
				// stop tracking the hostage
				m_metagame.removeTrackedCharId(hostageCharId);
				// all hostages accounted for?
				activeHostages -= 1;
				_log("** SND: handleCharacterDieEvent Active Hostages: " + activeHostages, 1);
				if (activeHostages <= 0) {
					if (m_metagame.getNumExtracted() > 2) {
						winRound(0);
					} else {
						winRound(1);
					}
				}
			}
		}
	}

	// no longer at start location (died, joined squad, etc.) auto-run via udpate method
	// --------------------------------------------
	protected void checkProximityToHostageMarkers() {
		array<Faction@> allFactions = m_metagame.getFactions();

		for (uint i = 0; i < activeHostageStartPositions.length(); ++i) {
			bool keepMarker = false; // if we don't find a hostage near the marker, we will be removing the marker

			// get all faction 0 (CT) characters within 40 units of hostage start location
			array<const XmlElement@> chars = getCharactersNearPosition(m_metagame, activeHostageStartPositions[i], 0, 40.0f);
			for (uint j = 0; j < chars.length(); ++j) {
				const XmlElement@ aChar = getCharacterInfo(m_metagame, chars[j].getIntAttribute("id"));
				if (aChar.getStringAttribute("soldier_group_name") == "hostage") {
					keepMarker = true;
					break;
				}
			}
			if (keepMarker == false) {
				// remove relevant marker from view
				for (uint f = 0; f < allFactions.length(); ++f) {
					string hostageMarkerCmd = "<command class='set_marker' id='" + (3395 + (2 * activeHostageMarkers[i]) + f) + "' enabled='" + (keepMarker ? 1 : 0) + "' atlas_index='1' faction_id='" + f + "' show_in_game_view='0' show_in_map_view='0' show_at_screen_edge='0' />";
					m_metagame.getComms().send(hostageMarkerCmd);
				}
				activeHostageStartPositions.removeAt(i);
				activeHostageMarkers.removeAt(i);
				i--; // we just removed that element, moving everything else forward by one in the array.
				checkSquadSizes();
			}
		}
	}

	// joined (counter terrorist) squad
	// --------------------------------------------
	protected void checkSquadSizes() {
		array<int> ctIds = m_metagame.getFactionPlayerCharacterIds(0);
		for (uint i = 0; i < ctIds.length(); ++i) {
			const XmlElement@ ct = getCharacterInfo(m_metagame, ctIds[i]);
			if (ct.getIntAttribute("squad_size") > 0) { // actually want only if squad size has increased, but this will only play a sound to units who have a hostage anyway
				playSoundAtLocation(m_metagame, joinWavs[rand(0, joinWavs.length() -1)], 0, stringToVector3(ct.getStringAttribute("position")));
				// TODO: if we do implement this correctly, award 150 RP to the CT who picked up the hostage (once-off payment per hostage)
			}
		}
	}

	// escaped
	// --------------------------------------------
	protected void hostageEscaped(int num) {
		knownExtracted += num;
		activeHostages -= num; // activeHostages = m_metagame.getTrackedCharIds().length();
		_log("** SND: hostageEscaped Active Hostages: " + activeHostages, 1);
		int rescued = m_metagame.getNumExtracted();
		if (activeHostages <= 0) {
			_log("** SND: All Hostages rescued or killed. End round or go to attrition?", 1);
			array<int> ctIds = m_metagame.getFactionPlayerCharacterIds(0);
			for (uint j = 0; j < ctIds.length() ; ++j) {
				string hostageRescuedReward = "<command class='rp_reward' character_id='" + ctIds[j] + "' reward='" + (850 * rescued) + "'></command>";
				m_metagame.getComms().send(hostageRescuedReward);
				m_metagame.addRP(ctIds[j], (850 * rescued));
			}
			if (rescued > 2) {
				winRound(0);
			} else {
				// if all hostages are accounted for but not CT win by rescue
				// then use score to determine winner
				array<int> endScore = m_metagame.getScores();
				if (endScore[0] > endScore[1]) {
					// CT win
					winRound(0);
				} else {
					// T win
					winRound(1);
				}
			}
			}
	}

	// --------------------------------------------
	protected void winRound(uint faction, uint consecutive = 1) {

		// Winning by Team Elimination 3250 RP
		// Winning by Time Win (Hostage Rescue, T) 3000 RP

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
		hostageCheckTimer -= time;
		if (hostageCheckTimer <= 0.0) {
			if (m_metagame.getNumExtracted() > knownExtracted) {
				_log("** SND: a hostage has been extracted!", 1);
				hostageEscaped(m_metagame.getNumExtracted() - knownExtracted);
			}
			checkProximityToHostageMarkers();
			hostageCheckTimer = CHECK_IN_INTERVAL;
		}
	}
}
