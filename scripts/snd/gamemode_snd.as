#include "metagame.as"
#include "log.as"
#include "map_rotator_snd_all.as"

// --------------------------------------------
class GameModeSND : Metagame {
	protected UserSettings@ m_userSettings;
	protected MapRotator@ m_mapRotator;

	//protected MapInfo@ m_mapInfo; // already exists in Metagame class
	protected array<Faction@> m_factions;

	array<Vector3> targetLocations;  // per-round locations where bombs can be placed or hostages start
	array<Vector3> extractionPoints; // per-round locations that units must reach in order to escape

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
	void setTargetLocations(array<Vector3> v3array) {
		targetLocations = v3array;
	}

	// --------------------------------------------
	array<Vector3> getTargetLocations() {
		return targetLocations;
	}

	// --------------------------------------------
	void setExtractionPoints(array<Vector3> v3array) {
		extractionPoints = v3array;
	}

	// --------------------------------------------
	array<Vector3> getExtractionPoints() {
		return extractionPoints;
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