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
	protected string m_stageType;					// Assassination: 'as'; Hostage Rescue: 'hr'

	protected array<const XmlElement@> m_triggerAreas;
	protected array<string> m_trackedTriggerAreas;
	protected array<int> m_trackedCharIds;

	protected bool m_started = false;

	protected float TRACKED_CHAR_CHECK_TIME = 5.0; 	// how often to check the list of tracked characters
	protected float nextCheck = 5.0;				// countdown timer start value (allow some time to get ready for tracking)

	// ----------------------------------------------------
	HitboxHandler(GameModeSND@ metagame, string stageType) {
		@m_metagame = @metagame;
		m_stageType = stageType;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting HitboxHandler tracker", 1);
		m_trackedTriggerAreas.clear();
		determineTriggerAreasList();
		m_started = true;
	}

	/////////////////////////
	// Setup Trigger Areas //
	/////////////////////////
	// ----------------------------------------------------
	protected void determineTriggerAreasList() {
		array<const XmlElement@> list;
		_log("** SND: hitbox_handler: determineTriggerAreasList", 1);

    	list = getTriggerAreas(m_metagame);
		// go through the list and only leave the ones in we're interested in, 'hitbox_trigger_<m_stageType>'
		string wanted = "hitbox_trigger_" + m_stageType;
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ triggerAreaNode = list[i];
			string id = triggerAreaNode.getStringAttribute("id");
			bool ruleOut = id.findFirst(wanted) < 0 ? true : false; // couldn't find the string (stored in wanted) in the triggerAreaNode id
			if (ruleOut) {
				// this should be improved to also rule out the trigger / exit areas near the enemy (Terrorist, generally) base
				_log("** SND: hitbox_handler determineTriggerAreasList: ruling out " + id, 1);
				list.erase(i);
				i--;
			} else {
				_log("** SND: hitbox_handler determineTriggerAreasList: including " + id, 1);
				m_trackedTriggerAreas.insertLast(id);
			}
		}
		_log("** SND: " + list.size() + " trigger areas active this level");
		m_triggerAreas = list;
		markTriggerAreas();
	}

	// ----------------------------------------------------
	protected array<const XmlElement@>@ getTriggerAreas(const GameModeSND@ metagame) {
		// returns all hitbox_trigger_* objects, regardless of game type
		_log("** SND: getTriggerAreas running in hitbox_handler.as", 1);
		XmlElement@ query = XmlElement(
			makeQuery(metagame, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "hitboxes"} }
			})
		);
		const XmlElement@ doc = metagame.getComms().query(query);
		array<const XmlElement@> triggerList = doc.getElementsByTagName("hitbox");

		for (uint i = 0; i < triggerList.size(); ++i) {
			const XmlElement@ hitboxNode = triggerList[i];
			string id = hitboxNode.getStringAttribute("id");
			if (startsWith(id, ("hitbox_trigger_" + m_stageType))) {
				_log("\t ** SND: including " + id, 1);
			} else {
				_log("\t ** SND: excluding " + id, 1);
				triggerList.erase(i);
				i--;
			}
		}
		if (m_stageType == 'as' || m_stageType == 'hr') {
			// Players cannot use extraction point near their start base in these game modes. Rule out.
			const XmlElement@ ctBase = getStartingBase(m_metagame, 0);
			float shortestDistance = 1024.0;
			uint closestTrigger;
			for (uint i = 0; i < triggerList.size(); ++i) {
				const XmlElement@ hitboxNode = triggerList[i];
				float thisDistance = getPositionDistance(stringToVector3(hitboxNode.getStringAttribute("position")), stringToVector3(ctBase.getStringAttribute("position")));
				_log("** SND: " + hitboxNode.getStringAttribute("id") + " is roughly " + int(thisDistance) + " units away from CT base: " + ctBase.getStringAttribute("id") , 1);
				if (thisDistance < shortestDistance) {
					shortestDistance = thisDistance;
					closestTrigger = i;
				}
			}
			_log("\t ** SND: Removing " + triggerList[closestTrigger].getStringAttribute("id"), 1);
			triggerList.erase(closestTrigger);
		}
		_log("** SND: " + triggerList.size() + " trigger area(s) applicable to this map", 1);
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
		bool showAtScreenEdge = true;
		string text = m_stageType == 'hr' ? 'Hostage Extraction Point' : 'VIP Extraction Point';
		string color = "#E0E0E0";
		float size = 1.0; // this is the size of the icon on the map overlay.
		float range = 0.0; // this is the size of the ring (visual queue) around the hitbox/trigger area
		int offset = 2050;
		array<Faction@> allFactions = m_metagame.getFactions();
		for (uint f = 0; f < allFactions.length(); ++f) {
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ triggerAreaNode = list[i];
				string id = triggerAreaNode.getStringAttribute("id");
				string position = triggerAreaNode.getStringAttribute("position");
				string command = "<command class='set_marker' id='" + offset + "' faction_id='" + f + "' atlas_index='" + (m_stageType == 'hr' ? 1 : 3) + "' text='" + text + "' position='" + position + "' color='" + color + "' size='" + size + "' show_at_screen_edge='" + (showAtScreenEdge?1:0) + "' range='" + range + "' />";
				m_metagame.getComms().send(command);
				offset++;
			}
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
	protected void trackCharacter(int charId) {
		_log("** SND: Activating Hitbox tracking for character id:" + charId, 1);
		m_trackedCharIds.insertLast(charId);
		// remove any existing associations (char : hitbox)
		clearTriggerAreaAssociations(m_metagame, "character", charId, m_trackedTriggerAreas);
		// get current Trigger Areas list and associate charId with each trigger area in the list
		const array<const XmlElement@> list = getTriggerAreasList();
		if (list !is null) {
			associateTriggerAreas(m_metagame, list, "character", charId, m_trackedTriggerAreas);
		}
	}

	// ----------------------------------------------------
	protected void clearTriggerAreaAssociations(const GameModeSND@ metagame, string instanceType, int instanceId, array<string>@ trackedTriggerAreas) {
		if (instanceId < 0) return;

		// disassociate character 'instanceId' with each 'trackedTriggerAreas'
		for (uint i = 0; i < trackedTriggerAreas.size(); ++i) {
			string id = trackedTriggerAreas[i];
			string command = "<command class='remove_hitbox_check' instance_type='" + instanceType + "' instance_id='" + instanceId + "' id='" + id + "'/>";
			metagame.getComms().send(command);
		}
		trackedTriggerAreas.clear();
	}

	// -------------------------------------------------------
	protected void associateTriggerAreas(const GameModeSND@ metagame, const array<const XmlElement@>@ extractionList, string instanceType, int instanceId, array<string>@ trackedTriggerAreas) {
		array<string> addIds;
		_log("** SND: FEEDING associateTriggerAreasEx instanceType: " + instanceType + ", instanceId: " + instanceId, 1);
		associateTriggerAreasEx(metagame, extractionList, instanceType, instanceId, trackedTriggerAreas, addIds);
	}

	// -------------------------------------------------------
	protected void associateTriggerAreasEx(const GameModeSND@ metagame, const array<const XmlElement@>@ extractionList, string instanceType, int instanceId, array<string>@ trackedTriggerAreas, array<string>@ addIds) {
		_log("** ASSOCIATING TRIGGER AREAS", 1);
		if (instanceId < 0) return;

		// check against already associated triggerAreas
		// and determine which need to be added or removed
		for (uint i = 0; i < trackedTriggerAreas.size(); ++i) {
			_log("** SND: trackedTriggerAreas " + i + ": " + trackedTriggerAreas[i], 1);
		}

		// prepare to remove all triggerAreas
		array<string> removeIds = trackedTriggerAreas;

		for (uint i = 0; i < extractionList.size(); ++i) {
			const XmlElement@ exitArea = extractionList[i];
			string exitAreaId = exitArea.getStringAttribute("id");

			int index = removeIds.find(exitAreaId);
			if (index >= 0) {
				// already tracked and still needed
				// remove from ids to remove
				removeIds.erase(index);
			} else {
				// not yet tracked, needs to be added
				addIds.push_back(exitAreaId);
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
		// TagName=hitbox_event
		// hitbox_id=hitbox_trigger_hr_exit-1-9-7
		// instance_id=4
		// instance_type=character

		_log("** SND hitbox event triggered. Running in hitbox_handler.as", 1);
		// variablise returned handleHitboxEvent event attributes:
		string hitboxId = event.getStringAttribute("hitbox_id");
		string instanceType = event.getStringAttribute("instance_type");
		int instanceId = event.getIntAttribute("instance_id");

		// is it a trigger area hitbox? If not, this is not the handler you are looking for...
		if (!startsWith(hitboxId, "hitbox_trigger_")) {
			return;
		}

		// we can split this out based on the hitboxId (hitbox_trigger_<stageType>_exit...) if desired. below works for 2 game modes.

		// // get details about the hitbox that has been entered
		// const array<const XmlElement@> list = getTriggerAreasList();
		// for (uint i = 0; i < list.size(); ++i) {
		// 	_log("** SND looping through triggerAreasList. Looking for " + hitboxId, 1);
		// 	const XmlElement@ thisArea = list[i];
		// 	if (thisArea.getStringAttribute("id") == hitboxId) {
		// 		_log("** SND trigger area found! " + hitboxId + " has position: " + thisArea.getStringAttribute("position"), 1);
		// 	}
		// }

		// in Hostage Rescue and Assassination, we only track the delivery of character instance types
		if (instanceType == "character") {
		// confirm it's a character who is being tracked for hitbox collisions via trackCharacter(int id);
			if (m_trackedCharIds.find(instanceId) > -1) {
				_log("** SND: tracked character " + instanceId + " within trigger area: " + hitboxId, 1);
				sendFactionMessage(m_metagame, -1, m_stageType == 'hr' ? 'A hostage has been rescued!' : 'VIP has escaped!');
				// increment rescued count
				m_metagame.addNumExtracted(1);
				// clear hitbox checking, stop tracking character
				clearTriggerAreaAssociations(m_metagame, "character", instanceId, m_trackedTriggerAreas);
				m_metagame.removeTrackedCharId(instanceId);
				m_trackedCharIds.removeAt(m_trackedCharIds.find(instanceId));
				_log("** SND: stopped tracking character id: " + instanceId, 1);
				array<Faction@> allFactions = m_metagame.getFactions();
				for (uint f = 0; f < allFactions.length(); ++f) {
					playSound(m_metagame, m_stageType == 'hr' ? 'rescued.wav' : '', f);
				}
				// reward CT - if more than one CT (player) near extraction, split reward. Can't tell who dropped the hostages off.
				// get and store the hostage's position
				const XmlElement@ escapee = getCharacterInfo(m_metagame, instanceId);
				Vector3 v3pos = stringToVector3(escapee.getStringAttribute("position"));
				// get all CT units near this position (may include hostage and player characters)
				array<const XmlElement@> nearCTs = getCharactersNearPosition(m_metagame, v3pos, 0, 15.0);
				_log("** SND: " + nearCTs.length() + " characters near rescued unit", 1);
				for (uint ct = 0; ct < nearCTs.length(); ++ct) {
					// the characterId
					int ctId = nearCTs[ct].getIntAttribute("id");
					// the character info XML block, which records the player ID
					const XmlElement@ ctInfo = getCharacterInfo(m_metagame, ctId);
					if (ctInfo.getStringAttribute("soldier_group_name") != 'default') {
						nearCTs.erase(ct);
						_log("** SND: character ID: " + ctId + " is not a player. Removed from list", 1);
						ct--;
					}
				}
				_log("** SND: " + nearCTs.length() + " CT player(s) near rescued unit", 1);
				for (uint i = 0; i < nearCTs.length(); ++ i) {
					int ctId = nearCTs[i].getIntAttribute("id");
					_log("** SND: rewarding characterID: " + ctId + " RP: " + (1000 / nearCTs.length()), 1);
					string rewardHostageRescuer = "<command class='rp_reward' character_id='" + ctId + "' reward='" + (1000 / nearCTs.length()) + "'></command>";
					m_metagame.getComms().send(rewardHostageRescuer);
				}
				// TODOs:
				// remove hostage from play
				// kill (ignore character kill/die if id not in tracked chars) then make disappear by applying invisivest?
				// requires death sounds to be disabled for hostages!
				// have an invincible 4-man vehicle sitting at the extraction point, inviting the AI to take refuge?
				// meh, ignore for now
			}
		}
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

		nextCheck -= time;

		if (nextCheck <= 0.0) {
			array<int> ids = m_metagame.getTrackedCharIds();
			for (uint i = 0; i < ids.size(); ++i) {
				if (m_trackedCharIds.find(ids[i]) == -1) {
					trackCharacter(ids[i]); // adds the id to m_trackedCharIds
				}
			}
			nextCheck = TRACKED_CHAR_CHECK_TIME;
		}
	}
	// ----------------------------------------------------
}
