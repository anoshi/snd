#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "game_timer.as"
#include "score_tracker.as"
#include "stage_snd.as"

#include "player_manager.as"
#include "vip_tracker.as"
#include "hitbox_handler.as"

// --------------------------------------------
class Assassination : SubStage {
	protected PlayerTracker@ m_playerTracker;
	protected VIPTracker@ m_vipTracker;
	protected HitboxHandler@ m_hitboxHandler;
	protected GameTimer@ m_gameTimer;
	protected ScoreTracker@ m_scoreTracker;

	// --------------------------------------------
	Assassination(Stage@ stage, float maxTime, array<int> competingFactionIds = array<int>(0, 1), int protectorFactionId = 2) {
		super(stage);

		m_name = "snd";
		m_displayName = "Search and Destroy";

		// the trackers get added into active tracking at SubStage::start()
		@m_gameTimer = GameTimer(m_metagame, maxTime);
	}

	// --------------------------------------------
	void startMatch() {
		if (m_gameTimer !is null) {
			// if GameTimer is used, some match settings must be set accordingly before starting the match
			m_gameTimer.prepareMatch(m_match);
		}

		// track Players
		@m_playerTracker = PlayerTracker(m_metagame);
		addTracker(m_playerTracker);

		// setup score tracking (does not persist between rounds / matches)
		@m_scoreTracker = ScoreTracker(m_metagame, this);
		addTracker(m_scoreTracker);

		// track the vip
		@m_vipTracker = VIPTracker(m_metagame);
		addTracker(m_vipTracker);

		// prepare vip and extraction points
		@m_hitboxHandler = HitboxHandler(m_metagame, "as");
		addTracker(m_hitboxHandler);

		SubStage::startMatch();
		// start match clears in-game score hud; reset player scores after it
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
			// can be -1 if so set by GameTimer - means clock has run out of time.
			// in CS (vip rescue game mode), Terrorists win if clock runs out.
			winner = winCondition.getIntAttribute("faction_id");
			if (winner == -1) {
				winner = 1; // terrorists
			}
		} else {
			_log("couldn't find win_condition tag");
		}

		setWinner(winner);

		array<Faction@> factions = getFactions();
		string factionName = "";
		if (winner >= 0) {
			factionName = factions[winner].getName();
		}
		m_playerTracker.save();
		m_metagame.save();
		end();
	}

}