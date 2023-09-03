import 'dart:math';

import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/stack_list.dart';

// ignore: constant_identifier_names
enum UpgradeId { RewardHacking, LethalityList, PoetryGenerator, CognitiveEmulation }

typedef GetUpgradeString = String Function(int level);

class Upgrade {
  Upgrade(this.id, this.name, this._getDescription,
      {this.modifiers = const [],
      this.eventHandlers = const [],
      this.paramEventHandlers = const [],
      this.onLevelUp,
      this.maxLevel = 3,
      this.contractModifiers = const [],
      this.organizationModifiers = const []});
  final UpgradeId id;
  final String name;
  final GetUpgradeString _getDescription;
  String description = '';
  void Function(GameState gs, int level)?
      onLevelUp; // function with side effects, used to immediately add resources etc. Should create an Effect and call action reducer by convention
  List<Modifier> modifiers = []; // mods that affect resource gain
  List<ParamEventHandler> paramEventHandlers = []; // handlers that can stack more effects when a parameter's value has been changed
  List<ActionEventHandler> eventHandlers = []; // handlers that can perform additional reductions when actions are taken
  List<Modifier> contractModifiers = []; // mods that affect contract generation
  List<Modifier> organizationModifiers = []; // mods that affect organization generation

  bool owned = false;
  int level = 0;
  final int maxLevel;
}

enum ModifierType {
  add,
  multiply,
  function, // Applied at the end of adds/multiplies in arbitrary order
}

typedef ModifierFunction = double Function(double value, int level);

class Modifier {
  Modifier(this.param, this.type, this.apply);
  // final String sourceName;
  // final String sourceDescription;
  final Param param;
  final ModifierType type;
  final ModifierFunction apply;
}

typedef ActionEventHandlerFunction = void Function(GameState gs, StackList<ActionEffect> effectStack, EventId eventId, int level);

class ActionEventHandler {
  ActionEventHandler(this.trigger, this.apply);
  final EventId trigger;
  final ActionEventHandlerFunction apply;
}

typedef ParamEventHandlerFunction = void Function(GameState gs, StackList<ActionEffect> effectStack, Param param, num value, int level);

class ParamEventHandler {
  ParamEventHandler(this.trigger, this.apply);
  final Param trigger;
  final ParamEventHandlerFunction apply;
}

List<Upgrade> initialUpgrades = [
  Upgrade(UpgradeId.RewardHacking, 'Reward Hacking', (l) => '${l * 10}% chance to get an extra point when receiving RP/EP/SP',
      paramEventHandlers: [
        ParamEventHandler(Param.rp, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.1 * level) effectStack.push(ActionEffect(Param.rp, 1));
        }),
        ParamEventHandler(Param.ep, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.1 * level) effectStack.push(ActionEffect(Param.ep, 1));
        }),
        ParamEventHandler(Param.sp, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.1 * level) effectStack.push(ActionEffect(Param.sp, 1));
        }),
      ]),
  Upgrade(UpgradeId.LethalityList, 'Lethal List', (l) => 'Alignment contracts provide ${l * 25}% more money', contractModifiers: [
    Modifier(Param.money, ModifierType.multiply, (value, level) => value * (1 + 0.25 * level)),
  ]),
  Upgrade(
    UpgradeId.PoetryGenerator,
    'Poetry Generator',
    (l) => 'SP actions are ${l * 20}% cheaper',
    modifiers: [
      Modifier(Param.sp, ModifierType.multiply, (value, level) => value >= 0 ? value : value * (1 - 0.2 * level)),
    ],
  ),
  Upgrade(UpgradeId.CognitiveEmulation, 'Cognitive Emulation', (l) => 'Cost of humans assigned to RP is reduced by ${l * 30}%',
      eventHandlers: [
        ActionEventHandler(EventId.dayChange, (gs, effectStack, eventId, level) {
          effectStack.push(ActionEffect(Param.money, (gs.rpWorkers * gs.wagePerHumanPerDay * 0.3 * level).floor()));
        }),
      ]),
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
  final availableUpgrades = staticUpgrades.where((upgrade) => !upgrade.owned && upgrade.level < upgrade.maxLevel).toList();
  availableUpgrades.shuffle(); // in-place operation
  return availableUpgrades.length >= 3 ? availableUpgrades.sublist(0, 3) : availableUpgrades;
}

List<Upgrade> getUpgradeSelectionOptions() {
  return nextUpgrades;
}

void selectUpgrade(GameState gs, Upgrade upgrade) {
  upgrade.owned = true;
  upgrade.level += 1;
  upgrade.description = upgrade._getDescription(upgrade.level);

  pushUpgradeModifiersToGameState(gs, upgrade);

  upgrade.onLevelUp?.call(gs, upgrade.level);
  nextUpgrades = shuffleNextUpgrades();
}

void pushUpgradeModifiersToGameState(GameState gs, Upgrade upgrade) {
  for (var modifier in upgrade.modifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        gs.addModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.multiply:
        gs.multModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.function:
        gs.functionModifiers[modifier.param] = modifier.apply;
        break;
    }
  }

  for (var paramEventHandler in upgrade.paramEventHandlers) {
    gs.paramEventHandlers[paramEventHandler.trigger] = paramEventHandler.apply;
  }

  for (var eventHandler in upgrade.eventHandlers) {
    gs.eventHandlers[eventHandler.trigger] = eventHandler.apply;
  }

  for (var modifier in upgrade.contractModifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        gs.contractAddModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.multiply:
        gs.contractMultModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.function:
        gs.contractFunctionModifiers[modifier.param] = modifier.apply;
        break;
    }
  }

  for (var modifier in upgrade.organizationModifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        gs.organizationAddModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.multiply:
        gs.organizationMultModifiers[modifier.param] = modifier.apply;
        break;
      case ModifierType.function:
        gs.organizationFunctionModifiers[modifier.param] = modifier.apply;
        break;
    }
  }
}
