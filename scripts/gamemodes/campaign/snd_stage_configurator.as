// gamemode specific
#include "faction_config.as"
#include "stage_configurator.as"
#include "snd_stage.as"

// ------------------------------------------------------------------------------------------------
class SNDStageConfigurator : StageConfigurator {
	protected GameModeInvasion@ m_metagame;
	protected MapRotatorInvasion@ m_mapRotator;

	// ------------------------------------------------------------------------------------------------
	SNDStageConfigurator(GameModeInvasion@ metagame, MapRotatorInvasion@ mapRotator) {
		@m_metagame = @metagame;
		@m_mapRotator = mapRotator;
		mapRotator.setConfigurator(this);
	}

	// ------------------------------------------------------------------------------------------------
	void setup() {
		setupFactionConfigs();
		setupNormalStages();
		setupWorld();
	}

	// ------------------------------------------------------------------------------------------------
	const array<FactionConfig@>@ getAvailableFactionConfigs() const {
		array<FactionConfig@> availableFactionConfigs;

		availableFactionConfigs.push_back(FactionConfig(-1, "counter_terrorist.xml", "Counter Terrorists", "0.1 0.1 0.4", "counter_terrorist.xml"));
		availableFactionConfigs.push_back(FactionConfig(-1, "terrorist.xml", "Terrorists", "0.4 0.3 0.1", "terrorist.xml"));
		return availableFactionConfigs;
	}

	// ------------------------------------------------------------------------------------------------
	protected void setupFactionConfigs() {
		array<FactionConfig@> availableFactionConfigs = getAvailableFactionConfigs(); // copy for mutability

		const UserSettings@ settings = m_metagame.getUserSettings();
		// First, add player faction
		{
			_log("faction choice: " + settings.m_factionChoice, 1);
			FactionConfig@ userChosenFaction = availableFactionConfigs[settings.m_factionChoice];
			_log("player faction: " + userChosenFaction.m_file, 1);

			int index = int(getFactionConfigs().size()); // is 0
			userChosenFaction.m_index = index;
			m_mapRotator.addFactionConfig(userChosenFaction);
			availableFactionConfigs.erase(settings.m_factionChoice);
		}
		// next add the snd faction
		while (availableFactionConfigs.size() > 0) {
			int index = int(getFactionConfigs().size());

			int availableIndex = rand(0, availableFactionConfigs.size() - 1);
			FactionConfig@ faction = availableFactionConfigs[availableIndex];

			_log("setting " + faction.m_name + " as index " + index, 1);

			faction.m_index = index;
			m_mapRotator.addFactionConfig(faction);

			availableFactionConfigs.erase(availableIndex);
		}
		// finally, add neutral faction
		{
			int index = getFactionConfigs().size();
			m_mapRotator.addFactionConfig(FactionConfig(index, "neutral.xml", "Neutral", "0 0 0"));
		}

		_log("total faction configs " + getFactionConfigs().size(), 1);
	}

	// --------------------------------------------
	protected void setupWorld() {
		SNDWorld world(m_metagame);

		dictionary mapIdToRegionIndex;
		mapIdToRegionIndex.set("map8", 0);
		mapIdToRegionIndex.set("map3", 1);
		mapIdToRegionIndex.set("map13", 2);
		mapIdToRegionIndex.set("map6", 3);
		mapIdToRegionIndex.set("map2", 4);
		mapIdToRegionIndex.set("map5", 5);
		mapIdToRegionIndex.set("map9", 6);
		mapIdToRegionIndex.set("map11", 7);
		mapIdToRegionIndex.set("map10", 8);

		world.init(mapIdToRegionIndex);

		m_mapRotator.setWorld(world);
	}

	// ------------------------------------------------------------------------------------------------
	protected void addStage(Stage@ stage) {
		m_mapRotator.addStage(stage);
	}

	// ------------------------------------------------------------------------------------------------
	protected void setupNormalStages() {
		addStage(setupStage1());
	}

	// --------------------------------------------
	protected SNDStage@ createStage() const {
		return SNDStage(m_metagame.getUserSettings());
	}

	// --------------------------------------------
	const array<FactionConfig@>@ getFactionConfigs() const {
		return m_mapRotator.getFactionConfigs();
	}

	// ------------------------------------------------------------------------------------------------
	Stage@ setupCompletedStage(Stage@ inputStage) {
		// currently not in use in invasion
		return null;
	}

	// ------------------------------------------------------------------------------------------------
	protected Stage@ setupStage1() {
		_log("** SND: SNDStageConfigurator::setupStage1 running", 1);
		Stage@ stage = createStage();
		stage.m_mapInfo.m_name = "SND M1A1";
		stage.m_mapInfo.m_path = "media/packages/snd/maps/snd";
		stage.m_mapInfo.m_id = "map1";

		stage.addTracker(PeacefulLastBase(m_metagame, 0));

		stage.m_maxSoldiers = 1;
		stage.m_playerAiCompensation = 1;
		stage.m_playerAiReduction = 0;

		{
			Faction f(getFactionConfigs()[0], createFellowCommanderAiCommand(0, 0.0, 0.0, false));
			f.m_overCapacity = 0;             // spawn this many more units at start than capacity offset
			f.m_capacityOffset = 0;           // reserve this many units of maxSoldiers for this faction
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}

		{
			Faction f(getFactionConfigs()[1], createCommanderAiCommand(1,0,0,true));
			f.m_overCapacity = 0;
			f.m_capacityMultiplier = 0.0001;
			f.m_bases = 1;
			stage.m_factions.insertLast(f);
		}

		stage.m_primaryObjective = "capture";

		return stage;
	}
}

// generated by atlas.exe
#include "world_init.as"
#include "world_marker.as"

// ------------------------------------------------------------------------------------------------
class SNDWorld : World {
	SNDWorld(Metagame@ metagame) {
		super(metagame);
	}

	// ----------------------------------------------------------------------------
	protected Marker getMarker(string key) const {
		return getWorldMarker(key);
	}

	// ----------------------------------------------------------------------------
	protected string getPosition(string key) const {
		return getWorldPosition(key);
	}

	// ------------------------------------------------------------------------------------------------
	protected string getInitCommand() const {
		return getWorldInitCommand();
	}
}
