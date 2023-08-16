import 'package:alignment_is_hard/logic/actions.dart';

// ignore: constant_identifier_names
enum UpgradeId { RewardHacking, LethalityList, PoetryGenerator, CognitiveEmulation }

class Upgrade {
  Upgrade(this.id, this.name, this.description, this.maxLevel);

  final UpgradeId id;
  final String name;
  final String description;

  // bool owned = false;
  int level = 0;
  int maxLevel;
  onSelect() {
    level += 1;
    nextUpgrades = shuffleNextUpgrades();
  }
}

// TODO - Right now the effects of these are handled with hardcoded conditional logic in the action reducers. However, that's fine for the prototype; we will get type errors after removing upgrade level during the implementation of the event-based effect reducer.
List<Upgrade> initialUpgrades = [
  Upgrade(UpgradeId.RewardHacking, 'Reward Hacking', '10% chance per level to get an extra point when receiving RP/EP/SP', 10),
  Upgrade(UpgradeId.LethalityList, 'Lethal List', 'Alignment contracts provide 25% more money per level', 4),
  Upgrade(UpgradeId.PoetryGenerator, 'Poetry Generator', 'SP actions are 20% cheaper per level', 4),
  Upgrade(UpgradeId.CognitiveEmulation, 'Cognitive Emulation', 'Cost of humans assigned to RP is reduced by 30% per level', 3),
];
List<Upgrade> staticUpgrades = [...initialUpgrades];
void resetUpgrades() {
  staticUpgrades = [...initialUpgrades];
  nextUpgrades = shuffleNextUpgrades();
}

Upgrade getUpgrade(UpgradeId id) => staticUpgrades.firstWhere((upgrade) => upgrade.id == id);

List<Upgrade> nextUpgrades = shuffleNextUpgrades();

bool canUpgrade() => nextUpgrades.isNotEmpty;
int totalUpgradeLevel() => staticUpgrades.fold(0, (total, upgrade) => total + upgrade.level);

shuffleNextUpgrades() {
  final availableUpgrades = staticUpgrades.where((upgrade) => upgrade.level < upgrade.maxLevel).toList();
  availableUpgrades.shuffle(); // in-place operation
  return availableUpgrades.length >= 2 ? availableUpgrades.sublist(0, 2) : availableUpgrades;
}

List<Upgrade> getUpgradeSelectionOptions() {
  return nextUpgrades; // TODO: placeholder until we have actual upgrade logic
}
