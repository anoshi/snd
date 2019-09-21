#include "metagame.as"
#include "log.as"
#include "map_rotator_snd_all.as"

// --------------------------------------------
class UserSettings {
	array<string> m_overlayPaths;

	int m_minimumPlayersToStart = 2;
	int m_minimumPlayersToContinue = 2;
	int m_maxPlayers = 10;

	float m_timeBetweenSubstages = 30.0;

	// search and destroy mode
	float m_sndMaxTime = 600.0;
	int m_sndMaxScore = 5;

	// koth mode
	float m_kothMaxTime = 900.0;
	float m_kothDefenseTime = 180.0;

	float m_quickmatchMaxTime = 3600.0;

	string m_startServerCommand = "";

	// --------------------------------------------
	UserSettings() {
		m_overlayPaths.insertLast("media/packages/snd");
	}

	// --------------------------------------------
	void print() const {
		_log(" * minimum players to start: " + m_minimumPlayersToStart);
		_log(" * minimum players to continue: " + m_minimumPlayersToContinue);
		_log(" * time between substages: " + m_timeBetweenSubstages);

		_log(" * snd max time: " + m_sndMaxTime);
		_log(" * snd max score: " + m_sndMaxScore);

		// _log(" * koth max time: " + m_kothMaxTime);
		// _log(" * koth max defense time: " + m_kothDefenseTime);

	}
}

// --------------------------------------------
class GameModeSND : Metagame {
	protected UserSettings@ m_userSettings;
	protected MapRotator@ m_mapRotator;

	//protected MapInfo@ m_mapInfo; // already exists in Metagame class
	protected array<Faction@> m_factions;

	protected string m_tournamentName = "";

	// --------------------------------------------
	GameModeSND(UserSettings@ settings) {
		super(settings.m_startServerCommand);
		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		Metagame::init();

		// trigger map change right now
		setupMapRotator();
		m_mapRotator.init();
		m_mapRotator.startRotation();
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		@m_mapRotator =  MapRotatorSNDAll(this);
	}

	// --------------------------------------------
	// MapRotator calls here when a battle has started
	void postBeginMatch() {
		Metagame::postBeginMatch();

		// add tracker for match end to switch to next
		addTracker(m_mapRotator);

	}

	// --------------------------------------------
	string getTournamentName() {
		return m_tournamentName;
	}

	// --------------------------------------------
	bool isTournamentOngoing() {
		return m_tournamentName != "";
	}

	// --------------------------------------------
	void startTournament(string name) {
		m_tournamentName = name;
	}

	// --------------------------------------------
	void endTournament() {
		m_tournamentName = "";
	}

	// TODO:
	// - consider providing this stuff by default, it's always needed

	// --------------------------------------------
	// map rotator feeds in data about current situation here
	void setFactions(array<Faction@> factions) {
		m_factions = factions;
	}

	// --------------------------------------------
	// map rotator feeds in data about current situation here
	void setMapInfo(MapInfo@ info) {
		m_mapInfo = info;
	}

	// --------------------------------------------
	array<Faction@> getFactions() {
		return m_factions;
	}

	// --------------------------------------------
	// pos is array of 3 elements, x,y,z
	string getRegion(Vector3@ pos) {
		return Metagame::getRegion(pos);
	}
}