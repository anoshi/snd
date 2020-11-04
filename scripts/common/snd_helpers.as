// Distance between two points P(x1, y1) and Q(x2, y2) is given by:
//  d(P, Q) = sqrt((x2 − x1)^2 + (y2 − y1)^2)
// --------------------------------------------
float getPositionDistance2D(const Vector3@ pos1, const Vector3@ pos2) {
	float result = sqrt( pow(pos2[0] - pos1[0], 2) + pow(pos2[2] - pos1[2], 2) );
	_log("** SND: 2D distance check result = " + result, 1);
	return result;
}

// --------------------------------------------
bool checkRange2D(const Vector3@ pos1, const Vector3@ pos2, float range) {
	float length = getPositionDistance2D(pos1, pos2);
	return length <= range;
}

// --------------------------------------------
void playSoundAtLocation(const Metagame@ metagame, string filename, int factionId, const Vector3@ position, float volume=1.0) {
	XmlElement command("command");
	command.setStringAttribute("class", "play_sound");
	command.setStringAttribute("filename", filename);
	command.setIntAttribute("faction_id", factionId);
	command.setFloatAttribute("volume", volume);
	command.setStringAttribute("position", position.toString());
	metagame.getComms().send(command);
}
