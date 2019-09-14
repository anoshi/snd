#include "gamemode_invasion.as"
#include "snd_stage_configurator.as"
#include "snd_map_rotator.as"

// --------------------------------------------
class SND : GameModeInvasion {

	// --------------------------------------------
	SND(SNDUserSettings@ settings) {
		super(settings);
	}

	// --------------------------------------------
	void init() {
		GameModeInvasion::init();

		if (!getAdminManager().isAdmin(getUserSettings().m_username)) {
			getAdminManager().addAdmin(getUserSettings().m_username);
		}
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		SNDMapRotator mapRotatorInvasion(this);
		SNDStageConfigurator configurator(this, mapRotatorInvasion);
		@m_mapRotator = @mapRotatorInvasion;
	}

	// --------------------------------------------
	void save() {
		// save metagame status now:
		_log("** SND: SND::save() saving metagame", 1);

		XmlElement commandRoot("command");
		commandRoot.setStringAttribute("class", "save_data");

		XmlElement root("saved_metagame");

		m_mapRotator.save(root);
		// append user-settings
		XmlElement@ settings = m_userSettings.toXmlElement("settings");
		root.appendChild(settings);
		// append campaign data
		m_resourceLifecycleHandler.save(root);
		// append all to root element
		commandRoot.appendChild(root);

		getComms().send(commandRoot);
		_log("** SND: finished saving campaign settings and data", 1);
	}

	// --------------------------------------------
	void load() {
		// load metagame status now:
		_log("** SND: SND::load() loading metagame", 1);

		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"} } }));
		const XmlElement@ doc = getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			// read user-settings too, have them around separately..
			const XmlElement@ settings = root.getFirstElementByTagName("settings");
			if (settings !is null) {
				m_userSettings.fromXmlElement(settings);
				m_userSettings.m_continue = true;
			}

			m_userSettings.print();

			// load saved campaign data
			m_resourceLifecycleHandler.load(root);

			m_mapRotator.init();
			m_mapRotator.load(root);
			_log("loaded", 1);
		} else {
			_log("load failed");
			m_mapRotator.init();
		}
	}
}
