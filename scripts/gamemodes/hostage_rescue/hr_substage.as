#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "game_timer.as"
#include "stage_snd.as"

#include "player_tracker.as"
#include "hostage_tracker.as"
#include "hitbox_handler.as"
#include "target_locations.as"

// --------------------------------------------
class HostageRescue : SubStage {
	protected PlayerTracker@ m_playerTracker;
	protected TargetLocations@ m_targetLocations;
	protected HostageTracker@ m_hostageTracker;
	protected HitboxHandler@ m_hitboxHandler;

	protected string m_targetsLayerName = "";

	protected GameTimer@ m_gameTimer;

	// --------------------------------------------
	HostageRescue(Stage@ stage, float maxTime, string targetsLayerName = "hostageLocations", array<int> competingFactionIds = array<int>(0, 1), int protectorFactionId = 2) {
		super(stage);

		m_name = "snd";
		m_displayName = "Search and Destroy";

		// the trackers get added into active tracking at SubStage::start()
		@m_gameTimer = GameTimer(m_metagame, maxTime);

		// should this be instantiated in SubStage (and only referenced here) in order to allow persistent player stats?
		// maybe not, yet... trying a save/load concept at end / start of each round.
		@m_playerTracker = PlayerTracker(m_metagame, this);
		addTracker(m_playerTracker);

		m_targetsLayerName = targetsLayerName;
	}

	// --------------------------------------------
	void startMatch() {
		if (m_gameTimer !is null) {
			// if GameTimer is used, some match settings must be set accordingly before starting the match
			m_gameTimer.prepareMatch(m_match);
		}

		{
			// retrieve all target locations (bombs, hostage spawns) in this map as 'positions'.
			array<Vector3> positions;
			array<const XmlElement@> nodes = getGenericNodes(m_metagame, m_targetsLayerName, "hostage_start");
			if (nodes !is null) {
				_log("** SND: Found " + nodes.length() + " possible hostage start locations:", 1);
				for (uint i = 0; i < nodes.length(); i++) {
					const XmlElement@ node = nodes[i];
					Vector3 pos = stringToVector3(node.getStringAttribute("position"));;
					_log("\t" + i + ": " + pos.toString());
					positions.insertLast(pos);
				}
			} else {
				_log("** SND: WARNING, no objects tagged as hostage_start within layer[1-3]." + m_targetsLayerName + " layers of objects.svg", 1);
			}

			// choose hostage spawn locations from numerous possibilities and mark on map for all to see
			@m_targetLocations = TargetLocations(m_metagame, "hr", positions);
			addTracker(m_targetLocations);

			// track the hostages
			@m_hostageTracker = HostageTracker(m_metagame);
			addTracker(m_hostageTracker);

			// prepare hostages and extraction points
			@m_hitboxHandler = HitboxHandler(m_metagame, "hr");
			addTracker(m_hitboxHandler);
		}

		SubStage::startMatch();
		// start match clears in-game score hud; reset player scores after it
		m_playerTracker.reset();

		if (m_gameTimer !is null) {
			m_gameTimer.start(-1);
		}
	}

	// --------------------------------------------
	array<Faction@> getFactions() {
		return m_match.m_factions;
	}

	// --------------------------------------------
	// GameTimer uses in-game defense win timer, which reports match end here
	protected void handleMatchEndEvent(const XmlElement@ event) {
		// TagName=match_result
		// TagName=win_condition
		// faction_id=-1
		// type=map_capture

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