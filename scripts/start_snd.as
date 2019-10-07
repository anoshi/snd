#include "path://media/packages/vanilla/scripts"
#include "path://media/packages/snd/scripts"

#include "user_settings_snd.as"
#include "gamemode_snd.as"

// --------------------------------------------
void main(dictionary@ inputData) {
	XmlElement inputSettings(inputData);

	UserSettings settings; // creates a UserSettings object named 'settings', with default values (as per user_settings_snd.as)
	_setupLog(inputSettings);
	settings.readSettings(inputSettings); // read contents ('inputData') of XmlElement 'inputSettings'
	// things like the player's username, savegame name, custom difficulty slider values, etc.

	// override some of the default user settings and add gamemode-specific settings we can query later.

	// if you want to run a dedicated server, uncomment below and fill out fields as necessary
	// settings.m_startServerCommand = """
	// <command class='start_server'
	// 	server_name='Search and Destroy'
	// 	server_port='1234'
	// 	comment='PvP'
	// 	url=''
	// 	register_in_serverlist='1'
	// 	mode='snd'
	// 	persistency='match'
	// 	max_players='10'>
	// 	<client_faction id="0" />
	// 	<client_faction id="1" />
	// </command>
	// """;

	settings.print();

	GameModeSND metagame(settings); // create a GameModeSND object named 'metagame', built from the settings we've set above

	metagame.init();
	metagame.run();
	metagame.uninit();

	_log("** SND: ending execution");
}
