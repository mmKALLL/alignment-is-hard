import 'dart:math';

import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/stack_list.dart';

typedef GetUpgradeString = String Function(int level);

class Upgrade {
  Upgrade(this.id, this.name, this._getDescription,
      {this.modifiers = const [],
      this.eventHandlers = const [],
      this.paramEventHandlers = const [],
      this.onLevelUp,
      this.maxLevel = 3,
      this.contractModifiers = const [],
      this.organizationModifiers = const []}) {
    description = _getDescription(1);
  }
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
  int getLevel() => level;
  final int maxLevel;
}

enum ModifierType {
  add,
  multiply,
  function, // Applied at the end of adds/multiplies in arbitrary order
}

typedef ModifierFunction = double Function(double value, int level);
typedef CurriedModifier = double Function(double value);

class Modifier {
  Modifier(this.param, this.type, this.apply);
  // final String sourceName;
  // final String sourceDescription;
  final Param param;
  final ModifierType type;
  final ModifierFunction apply;
}

typedef ActionEventHandlerFunction = void Function(GameState gs, StackList<ActionEffect> effectStack, EventId eventId, int level);
typedef CurriedActionEventHandler = void Function(GameState gs, StackList<ActionEffect> effectStack, EventId eventId);

class ActionEventHandler {
  ActionEventHandler(this.trigger, this.apply);
  final EventId trigger;
  final ActionEventHandlerFunction apply;
}

typedef ParamEventHandlerFunction = void Function(
  GameState gs,
  StackList<ActionEffect> effectStack,
  Param param,
  int value,
  int level,
);
typedef CurriedParamEventHandler = void Function(GameState gs, StackList<ActionEffect> effectStack, Param param, int value);

class ParamEventHandler {
  ParamEventHandler(this.trigger, this.apply);
  final Param trigger;
  final ParamEventHandlerFunction apply;
}

// ignore: constant_identifier_names
enum UpgradeId { RewardHacking, LethalityList, PoetryGenerator, CognitiveEmulation, Duplicator, SocialHacking }

// NOTE: Event handlers are allowed to push effects on the stack, but NOT call reduceActionEffects directly. Calling it directly would bypass the symmetric event trigger infinite recursion prevention (i.e. actionEventHandlerCounts and maxCallStack).
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
  Upgrade(
    UpgradeId.Duplicator,
    'Duplicator',
    (l) => 'Gain an RP every time you gain an SP',
    maxLevel: 1,
    paramEventHandlers: [
      ParamEventHandler(Param.sp, (gs, effectStack, param, value, level) {
        effectStack.push(ActionEffect(Param.rp, 1));
      })
    ],
  ),
  Upgrade(UpgradeId.SocialHacking, 'Social Hacking', (l) => 'Gain an SP every time you gain an RP', maxLevel: 1, paramEventHandlers: [
    ParamEventHandler(Param.rp, (gs, effectStack, param, value, level) {
      effectStack.push(ActionEffect(Param.sp, 1));
    })
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

// FIXME: Remove hardcoded effects of upgrades, can check usage of this function. Needs a bit of consideration on how to e.g. show the decreased price of SP effects...
Upgrade getUpgrade(UpgradeId id) => staticUpgrades.firstWhere((upgrade) => upgrade.id == id);

List<Upgrade> nextUpgrades = shuffleNextUpgrades();

bool canUpgrade() => nextUpgrades.isNotEmpty;
int totalUpgradeLevel() => staticUpgrades.fold(0, (total, upgrade) => total + upgrade.level);

shuffleNextUpgrades() {
  final availableUpgrades = staticUpgrades
      .where((upgrade) =>
          // TODO: Should consider whether upgrade level-ups should be included or not; !upgrade.owned &&
          upgrade.level < upgrade.maxLevel)
      .toList();
  availableUpgrades.shuffle(); // in-place operation
  return availableUpgrades.length >= 3 ? availableUpgrades.sublist(0, 3) : availableUpgrades;
}

List<Upgrade> getUpgradeSelectionOptions() {
  return nextUpgrades;
}

void selectUpgrade(GameState gs, Upgrade upgrade) {
  upgrade.owned = true;
  upgrade.level += 1;
  upgrade.description = upgrade._getDescription(upgrade.level + 1); // This is the "preview" of the next level

  pushUpgradeModifiersToGameState(gs, upgrade);

  upgrade.onLevelUp?.call(gs, upgrade.level);
  nextUpgrades = shuffleNextUpgrades();
}

void pushUpgradeModifiersToGameState(GameState gs, Upgrade upgrade) {
  for (var modifier in upgrade.modifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        addModifierToGameState(gs.addModifiers, upgrade, modifier);
        break;
      case ModifierType.multiply:
        addModifierToGameState(gs.multModifiers, upgrade, modifier);
        break;
      case ModifierType.function:
        addModifierToGameState(gs.functionModifiers, upgrade, modifier);
        break;
    }
  }

  for (var paramEventHandler in upgrade.paramEventHandlers) {
    addParamEventHandlerToGameState(gs.paramEventHandlers, upgrade, paramEventHandler);
  }

  for (var eventHandler in upgrade.eventHandlers) {
    addActionEventHandlerToGameState(gs.eventHandlers, upgrade, eventHandler);
  }

  for (var modifier in upgrade.contractModifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        addModifierToGameState(gs.contractAddModifiers, upgrade, modifier);
        break;
      case ModifierType.multiply:
        addModifierToGameState(gs.contractMultModifiers, upgrade, modifier);
        break;
      case ModifierType.function:
        addModifierToGameState(gs.contractFunctionModifiers, upgrade, modifier);
        break;
    }
  }

  for (var modifier in upgrade.organizationModifiers) {
    switch (modifier.type) {
      case ModifierType.add:
        addModifierToGameState(gs.organizationAddModifiers, upgrade, modifier);
        break;
      case ModifierType.multiply:
        addModifierToGameState(gs.organizationMultModifiers, upgrade, modifier);
        break;
      case ModifierType.function:
        addModifierToGameState(gs.organizationFunctionModifiers, upgrade, modifier);
        break;
    }
  }
}

void addModifierToGameState(Map<Param, List<CurriedModifier>> modifierMap, Upgrade upgrade, Modifier modifier) {
  if (modifierMap[modifier.param] == null) {
    modifierMap[modifier.param] = [];
  }
  modifierMap[modifier.param]!.add((double value) {
    final level = upgrade.getLevel();
    return modifier.apply(value, level);
  });
}

void addParamEventHandlerToGameState(Map<Param, List<CurriedParamEventHandler>> handlerMap, Upgrade upgrade, ParamEventHandler handler) {
  if (handlerMap[handler.trigger] == null) {
    handlerMap[handler.trigger] = [];
  }
  handlerMap[handler.trigger]!.add((GameState gs, StackList<ActionEffect> effectStack, Param param, int value) {
    final level = upgrade.getLevel();
    return handler.apply(gs, effectStack, param, value, level);
  });
}

void addActionEventHandlerToGameState(
    Map<EventId, List<CurriedActionEventHandler>> handlerMap, Upgrade upgrade, ActionEventHandler handler) {
  if (handlerMap[handler.trigger] == null) {
    handlerMap[handler.trigger] = [];
  }
  handlerMap[handler.trigger]!.add((
    GameState gs,
    StackList<ActionEffect> effectStack,
    EventId eventId,
  ) {
    final level = upgrade.getLevel();
    return handler.apply(gs, effectStack, eventId, level);
  });
}
