#include "tracker.as"
#include "log.as"
#include "helpers.as"

////////////////////////////
// Score tracking methods //
////////////////////////////
// 2 points for a bomb plant.
// 2 points if that bomb explodes. (Terrorist Only)
// 2 points for a kill, 3 when bomb planted
// 3 points for a kill when defending the bomb (Terrorist Only)
// 1 point when bomb detonates and you are alive
// 1 point when the bomb is defused and you are alive
// 1 point for an assist.
// 2 points for defusing a bomb. (Counter-Terrorist Only)
// 2 points for rescuing a hostage. (Counter-Terrorist Only)
// -1 point for killing a teammate.
// -1 point for committing suicide.

class ScoreTracker : Tracker {
	protected GameModeSND@ m_metagame;
    protected array<int> factionScores;

    // ----------------------------------------------------
	ScoreTracker(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	void reset() {
		factionScores = array<int>(0);
		array<Faction@> factions = m_metagame.getFactions();
		for (uint id = 0; id < factions.length(); ++id) {
			Faction@ faction = factions[id];
			factionScores.insertLast(0);
			string value = "0";
			string color = faction.m_config.m_color;
			string command = "<command class='update_score_display' id='" + id + "' text='" + value + "' color='" + color + "' />";
			m_metagame.getComms().send(command);
		}
	}

	// ----------------------------------------------------
	void addScore(int factionId, int score) {
		factionScores[factionId] += score;
		int value = factionScores[factionId];
		string command = "<command class='update_score_display' id='" + factionId + "' text='" + value + "' />";
		m_metagame.getComms().send(command);
		scoreChanged();
	}

	// ----------------------------------------------------
	protected void scoreChanged() {
		int score;
		for (uint i = 0; i < factionScores.length(); ++i) {
			score = factionScores[i];
		}

		string text = "";
		array<Faction@> factions = m_metagame.getFactions();
		for (uint i = 0; i < factions.length(); ++i) {
			Faction@ faction = factions[i];
			if (i != 0) {
				text += ", ";
			}
			text += faction.m_config.m_name + ": " + factionScores[i];
		}
		sendFactionMessage(m_metagame, -1, text);
	}

	// ----------------------------------------------------
	array<int> getScores() {
		return factionScores;
	}

	// ----------------------------------------------------
	string getScoresAsString() {
		string text = "";
		for (uint i = 0; i < factionScores.length(); ++i) {
			text += factionScores[i];
			if (i != factionScores.length() - 1) {
				text += " - ";
			}
		}
		return text;
	}
}
