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
	_log("** SND: Checking character inventory", 1);
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