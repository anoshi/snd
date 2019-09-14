#include "path://media/packages/vanilla/scripts"
#include "path://media/packages/minimodes/scripts"
#include "path://media/packages/snd/scripts"

#include "gamemode_snd.as"
//#include "snd_campaign.as"

// --------------------------------------------
void main(dictionary@ inputData) {
	XmlElement inputSettings(inputData);

	UserSettings settings;
	settings.fromXmlElement(inputSettings);
	_setupLog(inputSettings);

	UserSettings s;

	s.m_minimumPlayersToStart = 2;
	s.m_minimumPlayersToContinue = 2;
	s.m_timeBetweenSubstages = 20.0;

	s.m_tdmMaxTime = 900.0;
	s.m_tdmMaxScore = 5.0; // this is a "base" score, the actual max score is tdm_max_score * player_count, e.g. max_score = 3.0 * 10 = 30

	s.m_kothMaxTime = 900.0;
	s.m_kothDefenseTime = 180.0;

	s.m_thMaxTime = 900.0;
	s.m_thMaxScore = 3;

	s.m_startServerCommand = """
	<command class='start_server'
		server_name='Minimodes'
		server_port='1238'
		comment='PvP'
		url=''
		register_in_serverlist='1'
		mode='minimodes'
		persistency='match'
		max_players='24'>
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
