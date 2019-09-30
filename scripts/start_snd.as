#include "path://media/packages/vanilla/scripts"
#include "path://media/packages/snd/scripts"

#include "gamemode_snd.as"

// --------------------------------------------
void main(dictionary@ inputData) {
	XmlElement inputSettings(inputData);

	UserSettings settings;
	//settings.fromXmlElement(inputSettings);
	_setupLog(inputSettings);

	settings.m_minimumPlayersToStart = 2; //1;
	settings.m_minimumPlayersToContinue = 2; //1;
	settings.m_timeBetweenSubstages = 20.0;

	settings.m_sndMaxTime = 600.0;

	settings.m_kothMaxTime = 900.0;
	settings.m_kothDefenseTime = 180.0;

	settings.m_startServerCommand = """
	<command class='start_server'
		server_name='Search and Destroy'
		server_port='1234'
		comment='PvP'
		url=''
		register_in_serverlist='1'
		mode='snd'
		persistency='match'
		max_players='10'>
		<client_faction id="0" />
		<client_faction id="1" />
	</command>
	""";

	settings.print();

	GameModeSND metagame(settings);

	metagame.init();
	metagame.run();
	metagame.uninit();

	_log("** SND: ending execution");
}
