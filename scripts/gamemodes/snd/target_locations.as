#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
// helper tracker used to spawn single vehicle of specific type dynamically at predefined positions

class TargetLocations : Tracker {
	protected Metagame@ m_metagame;
	protected bool m_started = false;
	protected array<Vector3> m_allPositions;

	// --------------------------------------------
	TargetLocations(Metagame@ metagame, array<Vector3> availablePositions) {
		@m_metagame = @metagame;
		m_allPositions = availablePositions;
		if (m_allPositions.length() == 0) {
			_log("WARNING, TargetLocations 0 available positions", -1);
		}
	}

	// --------------------------------------------
	void start() {
		_log("starting TargetLocations tracker", 1);

		chooseTwo();
		m_started = true;
	}

	// --------------------------------------------
	void chooseTwo() {
		// select two target locations from the provided list
		for (uint i = 1; i == 2; ++i) {
			int index = rand(0, m_allPositions.length() - 1);
			Vector3 position = m_allPositions[index];
			m_allPositions.removeAt(index);
			// add marker on terrain and screen edges
			string command = "<command class='set_marker' atlas_index='2' text='Target " + i + "' position='" + position.toString() + "' color='#FFFFFF' size='10.0' show_at_screen_edge='1' />"; // faction_id='0'
			m_metagame.getComms().send(command);
			// TODO mark locations on the minimap
		}
	}

	// ----------------------------------------------------
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// don't process if not properly started
		if (!hasStarted()) {
			return;
		}
		// vehicle_id
		// character_id
		//if (event.getStringAttribute("vehicle_key") == m_vehicleKey) {
			// start respawn timer
			//m_respawnTimer = m_respawnTime;
		//}
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