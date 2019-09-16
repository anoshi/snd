#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
class BombTracker : Tracker {
	protected GameModeSND@ m_metagame;
	protected string m_itemKey = "";
	protected string m_itemName = "";
	protected int m_factionId = 0;

	// --------------------------------------------
	BombTracker(GameModeSND@ metagame, string itemKey, string itemName, int factionId = 0) {
		@m_metagame = @metagame;
		m_itemKey = itemKey;
		m_itemName = itemName;
		m_factionId = factionId;
	}

	// --------------------------------------------
	void start() {
		_log("starting BombTracker tracker", 1);
	}

	// ----------------------------------------------------
	protected void handleItemDropEvent(const XmlElement@ event) {
		int playerId = event.getIntAttribute("player_id");

		if (event.getStringAttribute("item_key") == m_itemKey &&
			// player events only
			playerId >= 0) {

			int container = event.getIntAttribute("target_container_type_id");

			const XmlElement@ info = getPlayerInfo(m_metagame, playerId);

			string name = "";
			if (info !is null) {
				name = info.getStringAttribute("name");
			}

			dictionary a = {{"%player_name", name}, {"%item_name", m_itemName}};
			sendFactionMessageKey(m_metagame, -1, "bomb dropped in container " + container, a);
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
			return true;
	}

}