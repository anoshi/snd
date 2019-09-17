#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "game_timer.as"
#include "score_tracker.as"
#include "stage_snd.as"

#include "bomb_tracker.as"
#include "bomb_carry_marker.as"
#include "target_locations.as"
//#include "vehicle_spawner.as"
//#include "vehicle_hint_manager.as"
//#include "spawner.as"

// --------------------------------------------
class SNDSubStage : SubStage {
	protected TargetLocations@ m_targetLocations;
	protected ScoreTracker@ m_scoreTracker;
	protected string m_targetsLayerName = "";

	protected GameTimer@ m_gameTimer;

	// --------------------------------------------
	SNDSubStage(Stage@ stage, float maxTime, string targetsLayerName = "targetLocations", array<int> competingFactionIds = array<int>(0, 1), int protectorFactionId = 2) {
		super(stage);

		m_name = "snd";
		m_displayName = "Search and Destroy";

		// the trackers get added into active tracking at SubStage::start()
		@m_gameTimer = GameTimer(m_metagame, maxTime);

		// only include the first two factions for score tracking; yup, it's hardcoded, feel free to expand
		dictionary scoreTracking;
		for (uint i = 0; i < competingFactionIds.length(); ++i) {
			scoreTracking[formatInt(competingFactionIds[i])] = true;
		}
		@m_scoreTracker = ScoreTracker(m_metagame, this, 100, scoreTracking);
		addTracker(m_scoreTracker);

		m_targetsLayerName = targetsLayerName;

		addTracker(BombTracker(m_metagame, "bomb.projectile", "BOMB", 0));
		addTracker(BombCarryMarker(m_metagame, "bomb.projectile"));
	}

	// --------------------------------------------
	void startMatch() {
		if (m_gameTimer !is null) {
			// if GameTimer is used, some match settings must be set accordingly before starting the match
			m_gameTimer.prepareMatch(m_match);
		}

		{
			array<Vector3> positions;

			array<const XmlElement@> nodes = getGenericNodes(m_metagame, m_targetsLayerName, "bomb_target");
			if (nodes !is null) {
				_log("** SND: bomb target locations " + nodes.length());
				for (uint i = 0; i < nodes.length(); i++) {
					const XmlElement@ node = nodes[i];
					Vector3 pos = stringToVector3(node.getStringAttribute("position"));;
					_log("position " + pos.toString());
					positions.insertLast(pos);
				}
			} else {
				_log("WARNING, no crates found with " + m_targetsLayerName);
			}

			// choose 2x bomb target locations from numerous possibilities and mark on map for all to see
			@m_targetLocations = TargetLocations(m_metagame, positions);
			addTracker(m_targetLocations);

			// give someone the bomb
				// record which team has the bomb for this round. Other team are on disarm or attrition duty

			// track the bomb
				// alert all when bomb is correctly deployed within one of the target locations
				// alert team with bomb when bomb is dropped
				// alert all when bomb explodes (bombers win, disarmers lose --> cycle map)
				// alert all when bomb defused (disarmers win, bombers lose --> cycle map)

			// track alive players
				// alert when one side all dead (other side wins, all dead side loses --> cycle map)

		}

		SubStage::startMatch();

		// start match by default clears in-game score hud; reset score tracker after it
		m_scoreTracker.reset();

		if (m_gameTimer !is null) {
			m_gameTimer.start(-1);
		}
	}

	// --------------------------------------------
	array<Faction@> getFactions() {
		return m_match.m_factions;
	}

	// --------------------------------------------
	void onItemDelivery(int factionId, string factionName, int playerId, string playerName) {
		m_scoreTracker.addScore(factionId);

		if (m_gameTimer !is null) {
			// GameTimer controls who wins if time runs out, refresh it each time score changes
			m_gameTimer.setWinningTeam(m_scoreTracker.getWinningTeam());
		}

		// reset timer to spawn the next immediately
		// only reset the timer if it was running in the first place
		//if (m_vehicleSpawner.getRespawnTimer() > 0.0) {
		// 	m_vehicleSpawner.setRespawnTimer(0.0);
		// }
	}

    // ----------------------------------------------------
	// ScoreTracker informs here when max score has been reached
	void maxScoreReached(int winner) {
		_log("max score reached");

		if (m_gameTimer !is null) {
			m_gameTimer.cancel();
		}

		setWinner(winner);
		end();
	}

	// --------------------------------------------
	// GameTimer uses in-game defense win timer, which reports match end here
	protected void handleMatchEndEvent(const XmlElement@ event) {
		int winner = -1;
		array<const XmlElement@> elements = event.getElementsByTagName("win_condition");
		if (elements.length() >= 1) {
			const XmlElement@ winCondition = elements[0];
			// can be -1 if so set by GameTimer
			winner = winCondition.getIntAttribute("faction_id");
		} else {
			_log("couldn't find win_condition tag");
		}

		setWinner(winner);

		array<Faction@> factions = getFactions();
		string factionName = "";
		if (winner >= 0) {
			factionName = factions[winner].getName();
		}

		end();
	}

}