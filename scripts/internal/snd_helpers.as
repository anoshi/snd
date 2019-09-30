// internal
#include "comms.as"
#include "metagame.as"
#include "resource.as"

/////////////////////////////////
// -----   SND HELPERS   ----- //
// ----- GLOBAL  METHODS ----- //
/////////////////////////////////

// -----------------------------
const XmlElement@ getPlayerInventory(const Metagame@ metagame, int characterId) {
	_log("** SND: Inspecting character " + characterId + "'s inventory", 1);
	XmlElement@ query = XmlElement(
		makeQuery(metagame, array<dictionary> = {
			dictionary = {
				{"TagName", "data"},
				{"class", "character"},
				{"id", characterId},
				{"include_equipment", 1}
			}
		})
	);
	const XmlElement@ doc = metagame.getComms().query(query);
	return doc.getFirstElementByTagName("character"); //.getElementsByTagName("item")
}

array<int> getFactionPlayerCharacterIds(Metagame@ metagame, uint faction) {
	array<int> playerCharIds;
	array<const XmlElement@> players = getPlayers(metagame);
	for (uint i = 0; i < players.size(); ++i) {
		const XmlElement@ player = players[i];
		uint factionId = player.getIntAttribute("faction_id");
		if (factionId == faction) {
			playerCharIds.insertLast(player.getIntAttribute("character_id"));
		}
	}
	return playerCharIds;
}

//////////////////////////////////////////////
// can't code. Make it public
// --------------------------------------------
array<Vector3> targetLocations; // per-round locations where bombs can be placed
void setTargetLocations(array<Vector3> v3array) {
	targetLocations = v3array;
}

// --------------------------------------------
array<Vector3> getTargetLocations() {
	return targetLocations;
}

/////////////////////////////////
// ----- END SND HELPERS ----- //
/////////////////////////////////