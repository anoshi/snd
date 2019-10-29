#include "tracker.as"
#include "log.as"
#include "helpers.as"

////////////////////////////
// Score tracking methods //
////////////////////////////
// Bomb Defusal
// 2 points for a bomb plant. (Terrorist Only)
// 2 points if that bomb explodes. (Terrorist Only)
// 2 points for a kill, 3 when bomb planted
// 3 points for a kill when defending the bomb (Terrorist Only)
// 1 point when bomb detonate and you are alive
// 1 point when the bomb is defused and you are alive
// 1 point for an assist.
// 2 points for defusing a bomb. (Counter-Terrorist Only)
// 2 points for rescuing a hostage. (Counter-Terrorist Only)
// -1 point for killing a teammate.
// -1 point for committing suicide.

class ScoreTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected SubStage@ m_substage;
    protected array<int> playerScores;
	protected dictionary m_includedFactions;

    // ----------------------------------------------------
	ScoreTracker(GameModeSND@ metagame, SubStage@ substage, dictionary includedFactions = dictionary() ) {
		@m_metagame = @metagame;
		@m_substage = @substage;
		m_includedFactions = includedFactions;
	}

	// --------------------------------------------
	void reset() {
		playerScores = array<int>(0);
		for (uint id = 0; id < m_substage.m_match.m_factions.length(); ++id) {
			// if faction is neutral or its name is Bots, continue, do not display this faction's score
			Faction@ faction = m_substage.m_match.m_factions[id];

			playerScores.insertLast(0);

			string value = "0";
			string color = faction.m_config.m_color;
			string command = "<command class='update_score_display' id='" + id + "' text='" + value + "' color='" + color + "' />";
			m_metagame.getComms().send(command);
		}
	}

	// ----------------------------------------------------
	void addScore(int factionId, int score) {
		playerScores[factionId] += score;
		// update game's score display
		int value = playerScores[factionId];
		string command = "<command class='update_score_display' id='" + factionId + "' text='" + value + "' />";
		m_metagame.getComms().send(command);
		scoreChanged();
	}

	// ----------------------------------------------------
	protected void scoreChanged() {
		int score;
		for (uint i = 0; i < playerScores.length(); ++i) {
			score = playerScores[i];
		}

		string text = "";
		array<Faction@> factions = m_metagame.getFactions();
		for (uint i = 0; i < factions.length(); ++i) {
			Faction@ faction = factions[i];
			if (i != 0) {
				text += ", ";
			}
			text += faction.m_config.m_name + ": " + playerScores[i];
		}
		sendFactionMessage(m_metagame, -1, text);
	}

	// ----------------------------------------------------
	array<int> getScores() {
		return playerScores;
	}

	// ----------------------------------------------------
	string getScoresAsString() {
		string text = "";
		for (uint i = 0; i < playerScores.length(); ++i) {
			text += playerScores[i];
			if (i != playerScores.length() - 1) {
				text += " - ";
			}
		}

		return text;
	}
}
