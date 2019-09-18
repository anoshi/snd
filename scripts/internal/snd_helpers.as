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
	_log("** CABAL: Checking character inventory", 1);
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

// -----------------------------
void addBombToBackpack(const Metagame@ metagame, int charId) {
	// assign / override equipment to player character
	_log("** SND: Adding bomb to backpack of player (id: " + charId + ")", 1);
    string addBombCmd = "<command class='update_inventory' character_id='" + charId + "' container_type_class='backpack'><item class='weapon' key='bomb_resource.weapon' /></command>";
	metagame.getComms().send(addBombCmd);
}

/////////////////////////////////
// ----- END SND HELPERS ----- //
/////////////////////////////////