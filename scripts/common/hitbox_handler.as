// internal
#include "tracker.as"
#include "helpers.as"
#include "log.as"
#include "announce_task.as"
#include "query_helpers.as"
// --------------------------------------------

// This tracker monitors specific characterIds for collision with / presence within trigger areas ('hitboxes' in RWR)
// and takes action appropriate for the game type that is being played

// --------------------------------------------
class HitboxHandler : Tracker {
	protected GameModeSND@ m_metagame;
	protected array<const XmlElement@> m_triggerAreas;
	protected array<string> m_trackedTriggerAreas;

	array<int> m_trackedCharIds;

	// ----------------------------------------------------
	HitboxHandler(GameModeSND@ metagame, array<int> trackedCharIds) {
		@m_metagame = @metagame;
		m_trackedCharIds = trackedCharIds;
		m_trackedTriggerAreas = determineTriggerAreasList();
		trackCharacters(trackedCharIds);
	}

	/////////////////////////
	// Setup Trigger Areas //
	/////////////////////////
	// ----------------------------------------------------
	protected void determineTriggerAreasList() {
		array<const XmlElement@> list;
		_log("** SND hitbox_handler: determineTriggerAreasList", 1);

    	list = getTriggerAreas(m_metagame);
		// go through the list and only leave the ones in we're interested in, 'hitbox_trigger_*'
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ triggerAreaNode = list[i];
			string id = triggerAreaNode.getStringAttribute("id");
			bool ruleOut = false;
			if (id.findFirst("hitbox_trigger_") < 0) {
				ruleOut = true;
				if (ruleOut) {
					_log("** SND hitbox_handler determineTriggerAreasList: ruling out " + id, 1);
					list.erase(i);
					i--;
				} else {
					_log("** SND hitbox_handler determineTriggerAreasList: including " + id, 1);
				}
			}
		_log("** SND: " + list.size() + " trigger areas found");
		}

		m_triggerAreas = list;
		markTriggerAreas(); // show the centre point of each trigger area with a mark and also on map
	}

	// ----------------------------------------------------
	protected array<const XmlElement@>@ getTriggerAreas(const GameModeSND@ metagame) {
		_log("** SND getTriggerAreas running in hitbox_handler.as", 1);
		XmlElement@ query = XmlElement(
			makeQuery(metagame, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "hitboxes"} } }));
		const XmlElement@ doc = metagame.getComms().query(query);
		array<const XmlElement@> triggerList = doc.getElementsByTagName("hitbox");

		for (uint i = 0; i < triggerList.size(); ++i) {
			const XmlElement@ hitboxNode = triggerList[i];
			string id = hitboxNode.getStringAttribute("id");
			if (startsWith(id, "hitbox_trigger")) {
				_log("\t including " + id, 1);
			} else {
				triggerList.erase(i);
				i--;
			}
		}
		_log("** SND: " + triggerList.size() + " trigger areas found", 1);
		return triggerList;
	}

	// ----------------------------------------------------
	protected const array<const XmlElement@>@ getTriggerAreasList() const {
		return m_triggerAreas;
	}

	// ----------------------------------------------------
	protected void markTriggerAreas() {
		const array<const XmlElement@> list = getTriggerAreasList();
		if (list is null) return;
		// only show trigger area markers for testing purposes at this time
        bool showAtScreenEdge = true;

		int offset = 2050;
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ triggerAreaNode = list[i];
			string id = triggerAreaNode.getStringAttribute("id");
			string text = "a trigger area";
			float size = 1.0;
			string color = "#E0E0E0";
			string position = triggerAreaNode.getStringAttribute("position");
			string command = "<command class='set_marker' id='" + offset + "' faction_id='0' atlas_index='1' text='" + text + "' position='" + position + "' color='" + color + "' size='" + size + "' show_at_screen_edge='" + (showAtScreenEdge?1:0) + "' />";
			m_metagame.getComms().send(command);

			offset++;
		}
	}

	// ----------------------------------------------------
	protected void unmarkTriggerAreas() {
		const array<const XmlElement@> list = getTriggerAreasList();
		if (list !is null) return;

		int offset = 2050;
		for (uint i = 0; i < list.size(); ++i) {
			string command = "<command class='set_marker' id='" + offset + "' enabled='0' />";
			m_metagame.getComms().send(command);
			offset++;
		}
	}

	///////////////////////////////////////////////
	// Setup Character to Trigger Area tracking  //
	///////////////////////////////////////////////
	// ----------------------------------------------------
	void trackCharacters(array<int> charIds) {
		for (uint i = 0; i < charIds.length(); ++i) {
			_log("** SND: Activating Hitbox tracking for character id: " + id, 1);
			// remove any existing associations (char : hitbox)
			clearTriggerAreaAssociations(m_metagame, "character", id, m_trackedTriggerAreas);
			// get current Trigger Areas list and associate charId with each trigger area in the list
			const array<const XmlElement@> list = getTriggerAreasList();
			if (list !is null) {
				associateTriggerAreas(m_metagame, list, "character", id, m_trackedTriggerAreas);
			}
		}
	}

	// ----------------------------------------------------
	void clearTriggerAreaAssociations(const GameModeSND@ metagame, string instanceType, int instanceId, array<string>@ trackedTriggerAreas) {
		if (instanceId < 0) return;

		// disassociate character 'instanceId' with each 'trackedTriggerAreas'
		for (uint i = 0; i < trackedTriggerAreas.size(); ++i) {
			string id = trackedTriggerAreas[i];
			string command = "<command class='remove_hitbox_check' id='" + id + "' instance_type='" + instanceType + "' instance_id='" + instanceId + "' />";
			metagame.getComms().send(command);
		}
		trackedTriggerAreas.clear();
	}

	// -------------------------------------------------------
	void associateTriggerAreas(const GameModeSND@ metagame, const array<const XmlElement@>@ extractionList, string instanceType, int instanceId, array<string>@ trackedTriggerAreas) {
		array<string> addIds;
		_log("** SND: FEEDING associateTriggerAreasEx instanceType: " + instanceType + ", instanceId: " + instanceId, 1);
		associateTriggerAreasEx(metagame, extractionList, instanceType, instanceId, trackedTriggerAreas, addIds);
	}

	// -------------------------------------------------------
	void associateTriggerAreasEx(const GameModeSND@ metagame, const array<const XmlElement@>@ extractionList, string instanceType, int instanceId, array<string>@ trackedTriggerAreas, array<string>@ addIds) {
		_log("** ASSOCIATING TRIGGER AREAS", 1);
		if (instanceId < 0) return;

		// check against already associated triggerAreas
		// and determine which need to be added or removed
		_log("** SND: trackedTriggerAreas contains: ", 1);
		for (uint i = 0; i < trackedTriggerAreas.size(); ++i) {
			_log("** trackedTriggerAreas " + i + ": " + trackedTriggerAreas[i], 1);
		}

		// prepare to remove all triggerAreas
		array<string> removeIds = trackedTriggerAreas;

		for (uint i = 0; i < extractionList.size(); ++i) {
			const XmlElement@ armory = extractionList[i];
			string armoryId = armory.getStringAttribute("id");

			int index = removeIds.find(armoryId);
			if (index >= 0) {
				// already tracked and still needed
				// remove from ids to remove
				removeIds.erase(index);
			} else {
				// not yet tracked, needs to be added
				addIds.push_back(armoryId);
			}
		}

		for (uint i = 0; i < removeIds.size(); ++i) {
			string id = removeIds[i];
			string command = "<command class='remove_hitbox_check' id='" + id + "' instance_type='" + instanceType + "' instance_id='" + instanceId + "' />";
			metagame.getComms().send(command);
			_log("** REMOVED instanceType: " + instanceType + ", instanceId: " + instanceId + " from trackedTriggerAreas." ,1);
			trackedTriggerAreas.erase(trackedTriggerAreas.find(id));
		}

		for (uint i = 0; i < addIds.size(); ++i) {
			string id = addIds[i];
			string command = "<command class='add_hitbox_check' id='" + id + "' instance_type='" + instanceType + "' instance_id='" + instanceId + "' />";
			metagame.getComms().send(command);
			_log("** ADDED instanceType: " + instanceType + ", instanceId: " + instanceId + " to trackedTriggerAreas." ,1);
			trackedTriggerAreas.push_back(id);
		}
	}

	////////////////////////////////////////
	// Character in Trigger Area Handling //
	////////////////////////////////////////
	// ----------------------------------------------------
	protected void handleHitboxEvent(const XmlElement@ event) {
		_log("** SND hitbox event triggered. Running in hitbox_handler.as", 1);
		// variablise returned handleHitboxEvent event attributes:
		string hitboxId = event.getStringAttribute("hitbox_id");
		string instanceType = event.getStringAttribute("instance_type");
		int instanceId = event.getIntAttribute("instance_id");
		string sPos = ""; // stores the xyz coords of the hitbox
		Vector3 v3Pos; // stores same as a Vector3

		// is it a trigger area hitbox? If not, this is not the handler you are looking for...
		if (!startsWith(hitboxId, "hitbox_trigger_")) {
			return;
		}

		// get details about the hitbox that has been entered
		const array<const XmlElement@> list = getTriggerAreasList();
		for (uint i = 0; i < list.size(); ++i) {
			_log("** SND looping through triggerAreasList. Looking for " + hitboxId, 1);
			const XmlElement@ thisArea = list[i];
			if (thisArea.getStringAttribute("id") == hitboxId) {
				_log("** SND trigger area found! " + hitboxId + " has position: " + thisArea.getStringAttribute("position"), 1);
				sPos = thisArea.getStringAttribute("position");
				v3Pos = stringToVector3(sPos);
			}
		}

		// in Hostage Rescue and Assassination, we only track the delivery of character instance types
		if (instanceType == "character") {
		// confirm it's a character who is being tracked for hitbox collisions via setupCharacterForTracking(int id);
			if (m_trackedCharIds.find(instanceId)) {
				_log("** tracked character " + instanceId + " within trigger area: " + hitboxId, 1);
			else if (startsWith(hitboxId, "hitbox_trigger_repairbay")) {
				_log("hitbox is a repair bay. Starting repairs", 1);
				array<const XmlElement@> repVehicle = getVehiclesNearPosition(m_metagame, v3Pos, 0, 7.00f);
				// note terminal, mounted weapon, fires healing stream at vehicle.
			}
			else if (startsWith(hitboxId, "hitbox_trigger_trap")) {
				_log("hitbox is a trap. Running deterrent routines...", 1);
				// Player has entered an area that is tracked by an enemy device.
				// Add a particle effect like a flashing red light on the detecting device

				// Spawn some baddies || commander alert to enemy faction ||  some other dastardly act.
			}
			// when we're done handling the event, we may want to clear hitbox checking
			// (I don't think we want to clear these until the end of each map)
			//clearTriggerAreaAssociations(m_metagame, "character", m_playerCharacterId, m_trackedTriggerAreas);
		}
	}

	// --------------------------------------------
	/*
	// --------------------------------------------
	void init() {
	}
	// --------------------------------------------
	void start() {
	}
	*/
	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}
	// --------------------------------------------
	bool hasStarted() const {
		// always on
		return true;
	}
	// --------------------------------------------
	void update(float time) {
	}
	// ----------------------------------------------------
}
