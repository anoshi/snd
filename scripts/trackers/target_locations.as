#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
// helper tracker used to select two bomb sites at random from several present in 'targetLocations' layer of objects.svg

class TargetLocations : Tracker {
	protected Metagame@ m_metagame;
	protected bool m_started = false;
	protected array<Vector3> m_allPositions;
	protected array<Vector3> targetLocations;

	// --------------------------------------------
	TargetLocations(Metagame@ metagame, array<Vector3> availablePositions) {
		@m_metagame = @metagame;
		m_allPositions = availablePositions;
		if (m_allPositions.length() == 0) {
			_log("** SND: WARNING, TargetLocations 0 available positions", -1);
		}
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting TargetLocations tracker", 1);
		chooseTwo();
		m_started = true;
	}

	// --------------------------------------------
	protected void chooseTwo() {
		_log("** SND: selecting 2 bomb target locations from a possible " + m_allPositions.length(), 1);
		uint counter = 3395;
		// select two target locations from the provided list
		for (uint i = 0; i < 2; ++i) {
			int index = rand(0, m_allPositions.length() - 1);
			Vector3 position = m_allPositions[index];
			m_allPositions.removeAt(index);
			// add markers to minimap, terrain and screen edges
			_log("** SND: adding bomb target location marker " + (i+1), 1);
			for (uint j=0; j < 2; ++j) {
				string command = "<command class='set_marker' id='" + counter + "' atlas_index='" + (8 + i) + "' faction_id='" + j + "' text='Bombsite " + (i+1) + "' position='" + position.toString() + "' color='#FFFFFF' size='1.0' show_at_screen_edge='1' />";
				m_metagame.getComms().send(command);
				++counter;
			}
			targetLocations.insertLast(position);
		}
		setTargetLocations(targetLocations); // public method in snd_helpers.as
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

}