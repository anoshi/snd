// --------------------------------------------
class Match {
	protected GameModeSND@ m_metagame;

	// default match settings, overridden on a per-map basis by map_rotator_snd_all.as
	int m_maxSoldiers = 0;
	float m_soldierCapacityVariance = 0.30;
	string m_soldierCapacityModel = "constant";
	float m_defenseWinTime = -1.0;
	string m_defenseWinTimeMode = "hold_bases";
	int m_playerAiCompensation = 0;
	int m_playerAiReduction = 5;
	string m_baseCaptureSystem = "any";

	array<Faction@> m_factions;

	float m_aiAccuracy = 0.94;

	float m_xpMultiplier = 1.0;
	float m_rpMultiplier = 1.0;

	// --------------------------------------------
	Match(GameModeSND@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	const XmlElement@ getStartGameCommand(GameModeSND@ metagame) const {
		XmlElement command("command");
		command.setStringAttribute("class", "start_game");
		command.setStringAttribute("savegame", "_default");
		command.setIntAttribute("vehicles", 1);
		command.setIntAttribute("max_soldiers", m_maxSoldiers);
		command.setFloatAttribute("soldier_capacity_variance", m_soldierCapacityVariance);
		command.setStringAttribute("soldier_capacity_model", m_soldierCapacityModel);
		command.setFloatAttribute("player_ai_compensation", m_playerAiCompensation);
		command.setFloatAttribute("player_ai_reduction", m_playerAiReduction);
		command.setFloatAttribute("xp_multiplier", m_xpMultiplier);
		command.setFloatAttribute("rp_multiplier", m_rpMultiplier);
		command.setFloatAttribute("initial_xp", m_metagame.getUserSettings().m_initialXp);
		command.setIntAttribute("initial_rp", m_metagame.getUserSettings().m_initialRp);
		command.setIntAttribute("max_rp", m_metagame.getUserSettings().m_maxRp);
		command.setStringAttribute("base_capture_system", m_baseCaptureSystem);
		command.setBoolAttribute("friendly_fire", true); // may want to go user-specified
		command.setBoolAttribute("clear_profiles_at_start", true);
		command.setBoolAttribute("fov", true);
        command.setBoolAttribute("ensure_alive_local_player_for_save", false);
		command.setBoolAttribute("allow_spawn_point_selection", false);

		if (m_defenseWinTime >= 0) {
			command.setFloatAttribute("defense_win_time", m_defenseWinTime);
			command.setStringAttribute("defense_win_time_mode", m_defenseWinTimeMode);
		}

		for (uint i = 0; i < m_factions.size(); ++i) {
			Faction@ f = m_factions[i];
			XmlElement faction("faction");

			faction.setFloatAttribute("capacity_offset", 0);
			faction.setFloatAttribute("initial_over_capacity", 0);
			faction.setFloatAttribute("capacity_multiplier", 0.0001);

			faction.setFloatAttribute("ai_accuracy", m_aiAccuracy);

			if (i == 0 && f.m_ownedBases.size() > 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_ownedBases.size());
			} else if (f.m_bases >= 0) {
				faction.setIntAttribute("initial_occupied_bases", f.m_bases);
			}

			faction.setBoolAttribute("lose_without_bases", false);

			command.appendChild(faction);
		}

		{
			XmlElement player("local_player");
			player.setIntAttribute("faction_id", m_metagame.getUserSettings().m_factionChoice);
			player.setStringAttribute("username", m_metagame.getUserSettings().m_username);
			command.appendChild(player);
		}

		return command;
	}

	// --------------------------------------------
   	void start() {
		_log("** SND: Match::start");

		m_metagame.setFactions(m_factions);

		// start game
		const XmlElement@ startGameCommand = getStartGameCommand(m_metagame);
		m_metagame.getComms().send(startGameCommand);
	}
}
