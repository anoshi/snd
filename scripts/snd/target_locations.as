#include "tracker.as"
#include "log.as"
#include "helpers.as"

class TargetLocations : Tracker {
	// --------------------------------------------
	// helper tracker used to designate bomb sites and hostage start locations at
	// random from several present in layer(x).(target|hostage)Locations -->
	// (target|hostage)Locations' sub-layers of objects.svg
	protected GameModeSND@ m_metagame;
	protected string m_stageType;	// Bomb Defuse: 'de' | Hostage Rescue: 'hr'
	protected array<Vector3> m_allPositions;
	protected array<Vector3> targetLocations;
	protected bool m_started = false;

	// --------------------------------------------
	TargetLocations(GameModeSND@ metagame, string stageType, array<Vector3> availablePositions) {
		@m_metagame = @metagame;
		m_stageType = stageType;
		m_allPositions = availablePositions;
		if (m_allPositions.length() == 0) {
			_log("** SND: WARNING, TargetLocations called with 0 available positions", -1);
		}
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting TargetLocations tracker", 1);
		chooseLocations();
		m_started = true;
	}

	// --------------------------------------------
	protected void chooseLocations() {
		_log("** SND: selecting " + (m_stageType == 'de' ? '2 bomb target' : '4 hostage start') + " locations from a possible " + m_allPositions.length(), 1);
		uint counter = 3395;
		uint numLocs = m_stageType == 'de' ? 2 : 4;
		// select target locations from the provided list
		for (uint i = 0; i < numLocs; ++i) {
			int index = rand(0, m_allPositions.length() - 1);
			Vector3 position = m_allPositions[index];
			m_allPositions.removeAt(index);
			// add markers to minimap, terrain and screen edges
			_log("** SND: adding target location marker " + (i+1), 1);
			for (uint j=0; j < 2; ++j) {
				string command = "<command class='set_marker' id='" + counter + "' atlas_index='" + (m_stageType == 'de' ? 8 + i : 2) + "' faction_id='" + j + "' text='" + (m_stageType == 'de' ? 'Bombsite ' : 'Hostage ') + (i+1) + "' position='" + position.toString() + "' range='" + (m_stageType == 'de' ? '0.0' : '0.0') + "' color='#FFFFFF' size='1.0' show_at_screen_edge='1' />";
				// atlas ref: textures/mapview_comms_marker.png
				m_metagame.getComms().send(command);
				++counter;
			}
			targetLocations.insertLast(position);
		}
		m_metagame.setTargetLocations(targetLocations);
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