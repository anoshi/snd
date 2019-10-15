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
	protected string m_stageType;	// Assassination: 'as' | Hostage Rescue: 'hr'

	protected array<const XmlElement@> m_triggerAreas;
	protected array<string> m_trackedTriggerAreas;
	protected array<int> m_trackedCharIds;

	protected bool m_started = false;

	protected float TRACKED_CHAR_CHECK_TIME = 5.0; 	// how often to check the list of tracked characters
	protected float nextCheck = 0.0;				// countdown timer

	// ----------------------------------------------------
	HitboxHandler(GameModeSND@ metagame, string stageType) {
		@m_metagame = @metagame;
		m_stageType = stageType;
	}

	// --------------------------------------------
	void start() {
		_log("** SND: starting HitboxHandler tracker", 1);
		determineTriggerAreasList();
		m_started = true;
	}

	/////////////////////////
	// Setup Trigger Areas //
	/////////////////////////
	// ----------------------------------------------------
	protected void determineTriggerAreasList() {
		array<const XmlElement@> list;
		_log("** SND hitbox_handler: determineTriggerAreasList", 1);

    	list = getTriggerAreas(m_metagame);
		// go through the list and only leave the ones in we're interested in, 'hitbox_trigger_<m_stageType>'
		string wanted = "hitbox_trigger_" + m_stageType;
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ triggerAreaNode = list[i];
			string id = triggerAreaNode.getStringAttribute("id");
			bool ruleOut = false;
			if (id.findFirst(wanted) < 0) { // couldn't find the string (stored in wanted) in the triggerAreaNode id
				ruleOut = true;
				if (ruleOut) {
					_log("** SND hitbox_handler determineTriggerAreasList: ruling out " + id, 1);
					list.erase(i);
					i--;
				} else {
					_log("** SND hitbox_handler determineTriggerAreasList: including " + id, 1);
				}
			}
		}
		_log("** SND: " + list.size() + " trigger areas found");
		m_triggerAreas = list;
		markTriggerAreas(); // show the centre point of each trigger area with a mark and also on map
	}

	// ----------------------------------------------------
	protected array<const XmlElement@>@ getTriggerAreas(const GameModeSND@ metagame) {
		// returns all hitbox_trigger_* objects, regardless of game type
		_log("** SND getTriggerAreas running in hitbox_handler.as", 1);
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
			if (startsWith(id, "hitbox_trigger")) {
				_log("\t ** SND: including " + id, 1);
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
			string text = m_stageType == 'hr' ? 'Hostage Extraction Point' : 'VIP Extraction Point';
			float size = 1.0; // this is the size on the map overlay.
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
			string command = "<command class='remove_hitbox_check' id='" + id + "' instance_type='" + instanceType + "' instance_id='" + instanceId + "' />";
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
				array<Faction@> allFactions = m_metagame.getFactions();
				for (uint f = 0; f < allFactions.length(); ++f) {
					playSound(m_metagame, m_stageType == 'hr' ? 'rescued.wav' : '', f);
				}
				// reward CT - if more than one CT near extraction, split reward. Can't tell who dropped the hostages off.
				const XmlElement@ escapee = getCharacterInfo(m_metagame, instanceId);
				Vector3 v3pos = stringToVector3(escapee.getStringAttribute("position"));
				array<const XmlElement@> nearCTs = getCharactersNearPosition(m_metagame, v3pos, 0, 8.0);
				for (uint ct = 0; ct < nearCTs.length(); ++ct) {
					int ctId = nearCTs[ct].getIntAttribute("id");
					const XmlElement@ ctInfo = getCharacterInfo(m_metagame, ctId);
					int ctPId = ctInfo.getIntAttribute("player_id");
					if (ctPId < 0) {
						nearCTs.removeAt(ct);
						continue;
					}
				}
				for (uint i = 0; i < nearCTs.length(); ++ i) {
					int ctId = nearCTs[i].getIntAttribute("id");
					string rewardHostageRescuer = "<command class='rp_reward' character_id='" + ctId + "' reward='" + (1000 / nearCTs.length()) + "'></command>";
					m_metagame.getComms().send(rewardHostageRescuer);
				}
				// remove hostage from play
				// kill then make disappear by applying invisivest?
				// have an invincible 4-man vehicle sitting at the extraction point, inviting the AI to take refuge?
				// meh, ignore for now
			}
		}
	}

	// --------------------------------------------
	/*
	// --------------------------------------------
	void init() {
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
