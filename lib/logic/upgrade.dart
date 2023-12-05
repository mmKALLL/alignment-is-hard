import 'dart:math';

import 'package:alignment_is_hard/logic/action_reducer.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/stack_list.dart';
import 'package:alignment_is_hard/logic/util.dart';
import 'package:alignment_is_hard/main.dart';

typedef GetUpgradeString = String Function(int l); // l means level; shortened to make the string interpolation more readable

class Upgrade {
  Upgrade(this.id, this.name, this._getDescription,
      {this.modifiers = const [],
      this.eventHandlers = const [],
      this.paramEventHandlers = const [],
      this.onLevelUp,
      this.maxLevel = 3,
      this.contractModifiers = const [],
      this.organizationModifiers = const [],
      this.alwaysAppear = false}) {
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
  final bool alwaysAppear; // Debug use only, can result in duplicates (see shuffleNextUpgrades)
}

enum ModifierType {
  add,
  multiply,
  function, // Applied at the end of adds/multiplies in arbitrary order
}

typedef ModifierFunction = double Function(double value, int l); // l = level
typedef CurriedModifier = double Function(double value);

class Modifier {
  Modifier(this.param, this.type, this.apply, [this.filter = returnTrue]);
  // final String sourceName;
  // final String sourceDescription;
  final Param param;
  final ModifierType type;
  final ModifierFunction apply;
  final bool Function() filter; // TODO: Unimplemented
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
  double value,
  int level,
);
typedef CurriedParamEventHandler = void Function(GameState gs, StackList<ActionEffect> effectStack, Param param, double value);

class ParamEventHandler {
  ParamEventHandler(this.trigger, this.apply);
  final Param trigger;
  final ParamEventHandlerFunction apply;
}

// ignore_for_file: constant_identifier_names
enum UpgradeId {
  RewardHacking,
  LethalityList,
  PoetryGenerator,
  CognitiveEmulation,
  Duplicator,
  SocialHacking,
  DebateCourse,

  // TODO: Untested upgrades below
  ResearchAdvisor,
  EngineeringAdvisor,
  SocialAdvisor,
  OpenLetter,
  InterpretabilityModel,

  TrustedAdvisor,
  PassiveIncome,
  DataScraping,
  WarningSigns,
  SocialEngineering,
  FakeNews,
  MoneyLaundering,
  StrategicAlignment,
}

// NOTE: Event handlers are allowed to push effects on the stack, but NOT call reduceActionEffects directly. Calling it directly would bypass the symmetric event trigger infinite recursion prevention (i.e. actionEventHandlerCounts and maxCallStack).
List<Upgrade> initialUpgrades = [
  Upgrade(UpgradeId.RewardHacking, 'Reward Hacking', (l) => '${l * 8}% chance to get an extra point when receiving RP/EP/SP',
      maxLevel: 5,
      paramEventHandlers: [
        // NOTE: This allows the RP/EP/SP param handlers to be self-recursive. Thus with 20%+ chance it's common to see 3 or 4 points being gained at once.
        ParamEventHandler(Param.rp, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.08 * level) effectStack.push(ActionEffect(Param.rp, 1));
        }),
        ParamEventHandler(Param.ep, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.08 * level) effectStack.push(ActionEffect(Param.ep, 1));
        }),
        ParamEventHandler(Param.sp, (gs, effectStack, param, value, level) {
          if (Random().nextDouble() <= 0.08 * level) effectStack.push(ActionEffect(Param.sp, 1));
        }),
      ]),
  Upgrade(
    UpgradeId.Duplicator,
    'Duplicator',
    (l) => 'Whenever you gain an EP, 25% chance to gain an RP',
    maxLevel: 2,
    paramEventHandlers: [
      ParamEventHandler(Param.ep, (gs, effectStack, param, value, l) {
        if (Random().nextDouble() < 0.25 * l) effectStack.push(ActionEffect(Param.rp, 1));
      })
    ],
  ),
  Upgrade(UpgradeId.SocialHacking, 'Social Hacking', (l) => 'Whenever you gain an SP, 25% chance to gain an EP',
      maxLevel: 2,
      paramEventHandlers: [
        ParamEventHandler(Param.sp, (gs, effectStack, param, value, l) {
          if (Random().nextDouble() < 0.25 * l) effectStack.push(ActionEffect(Param.ep, 1));
        })
      ]),
  Upgrade(UpgradeId.DebateCourse, 'Debate Course', (l) => 'Whenever you gain an RP, 25% chance to gain an SP',
      maxLevel: 2,
      paramEventHandlers: [
        ParamEventHandler(Param.rp, (gs, effectStack, param, value, l) {
          if (Random().nextDouble() < 0.25 * l) effectStack.push(ActionEffect(Param.sp, 1));
        })
      ]),
  // TODO: Originally this was only for alignment contracts, but filtering is not yet implemented
  // TODO: This affects all sources of money gain on contracts, but should only impact the onAccept effects
  Upgrade(UpgradeId.LethalityList, 'List of Lethalities', (l) => 'Contracts provide ${l * 10}k more money', contractModifiers: [
    Modifier(
      Param.money,
      ModifierType.add,
      (value, level) => value > 0 ? value + (10 * level) : value,
    ),
  ]),
  Upgrade(
    UpgradeId.PoetryGenerator,
    'Poetry Generator',
    (l) => 'SP actions are ${l * 20}% cheaper',
    modifiers: [
      // TODO: should use onLevelUp instead to modify the price of SP actions in game state. The current effect unintentedly affects e.g. contract failures
      Modifier(Param.sp, ModifierType.multiply, (value, level) => value >= 0 ? value : (value * (1 - 0.2 * level))),
    ],
  ),
  Upgrade(UpgradeId.CognitiveEmulation, 'Cognitive Emulation', (l) => 'Cost of humans assigned to RP is reduced by ${l * 50}%',
      maxLevel: 1,
      eventHandlers: [
        ActionEventHandler(EventId.dayChange, (gs, effectStack, eventId, level) {
          effectStack.push(ActionEffect(Param.money, (gs.rpWorkers * gs.wagePerHumanPerDay * 0.5 * level)));
        }),
      ]),
  Upgrade(
    UpgradeId.ResearchAdvisor,
    'Research Advisor',
    (l) => 'RP generation is ${l * 20}% faster',
    modifiers: [Modifier(Param.rpProgress, ModifierType.multiply, (value, l) => value >= 0 ? value * (1 + 0.2 * l) : value)],
  ),
  Upgrade(
    UpgradeId.EngineeringAdvisor,
    'Engineering Advisor',
    (l) => 'EP generation is ${l * 20}% faster',
    modifiers: [Modifier(Param.epProgress, ModifierType.multiply, (value, l) => value >= 0 ? value * (1 + 0.2 * l) : value)],
  ),
  Upgrade(
    UpgradeId.SocialAdvisor,
    'Social Advisor',
    (l) => 'SP generation is ${l * 20}% faster',
    modifiers: [Modifier(Param.spProgress, ModifierType.multiply, (value, l) => value >= 0 ? value * (1 + 0.2 * l) : value)],
  ),
  Upgrade(
    UpgradeId.OpenLetter,
    'Open Letter',
    (l) => 'Gain 10 influence',
    maxLevel: 2,
    onLevelUp: (gs, level) => reduceActionEffects(gs, [ActionEffect(Param.influence, 10)]),
  ),
  Upgrade(
    UpgradeId.InterpretabilityModel,
    'Interpretability Model',
    (l) => 'Trust rewards/penalties on contracts are increased by ${l * 50}%',
    maxLevel: 2,
    contractModifiers: [Modifier(Param.trust, ModifierType.multiply, (value, l) => value * (1 + 0.5 * l))],
  ),
  Upgrade(
    UpgradeId.TrustedAdvisor,
    'Trusted Advisor',
    (l) => 'Trust rewards on contracts are increased by ${l * 3}',
    // TODO: Could be reworded by using contract finish event handler; "whenever you complete a contract, gain 2 trust"
    contractModifiers: [Modifier(Param.trust, ModifierType.add, (value, l) => value + l * 3)],
  ),
  Upgrade(
    UpgradeId.PassiveIncome,
    'Passive Income',
    (l) => 'Gain ${1 * l}k money per day',
    eventHandlers: [
      ActionEventHandler(EventId.dayChange, (gs, effectStack, eventId, l) {
        effectStack.push(ActionEffect(Param.money, 1 * l));
      })
    ],
  ),
  Upgrade(UpgradeId.DataScraping, 'Data Scraping', (l) => 'Contract auto-refresh time is reduced by 36%',
      onLevelUp: (gs, l) => gs.contractCycle = (gs.contractCycle * 0.6324).round(),
      maxLevel: 2), // Two levels: 40% of original length (= 144 days)
  Upgrade(UpgradeId.WarningSigns, 'Warning Signs', (l) => 'Organizations take ${l * 18}% longer to appear',
      onLevelUp: (gs, l) => gs.organizationCycle *= (gs.organizationCycle * 1.18).round()),
  Upgrade(
    UpgradeId.SocialEngineering,
    'Social Engineering',
    (l) => 'Influence rewards on contracts are increased by ${l * 6}',
    contractModifiers: [Modifier(Param.influence, ModifierType.add, (value, l) => value + l * 6)],
  ),
  Upgrade(
    UpgradeId.StrategicAlignment,
    'Strategic Alignment',
    (l) => 'Alignment acceptance rewards on contracts are increased by ${l * 1}',
    contractModifiers: [Modifier(Param.alignmentAcceptance, ModifierType.add, (value, l) => value + l * 1)],
  ),
  Upgrade(
    UpgradeId.FakeNews,
    'Fake News',
    (l) => 'Gain 20 influence, but lose 20 trust',
    maxLevel: 2,
    onLevelUp: (gs, l) => reduceActionEffects(gs, [ActionEffect(Param.influence, 20), ActionEffect(Param.trust, -20)]),
  ),
  Upgrade(
    UpgradeId.MoneyLaundering,
    'Money Laundering',
    (l) => 'Gain ${2 * l}k money per day, but lose 20 trust',
    maxLevel: 1,
    onLevelUp: (gs, l) => reduceActionEffects(gs, [ActionEffect(Param.trust, -20)]),
    eventHandlers: [
      ActionEventHandler(EventId.dayChange, (gs, effectStack, eventId, l) {
        effectStack.push(ActionEffect(Param.money, 2 * l));
      })
    ],
  ),
];

List<Upgrade> staticUpgrades = [...initialUpgrades];
void resetUpgrades() {
  staticUpgrades = [...initialUpgrades];
  nextUpgrades = shuffleNextUpgrades();
  for (Upgrade upgrade in staticUpgrades) {
    upgrade.owned = false;
    upgrade.level = 0;
    upgrade.description = upgrade._getDescription(1);
  }
}

// Upgrade getUpgrade(UpgradeId id) => staticUpgrades.firstWhere((upgrade) => upgrade.id == id); // Was only needed for hardcoded effects defined elsewhere, kept for future use

List<Upgrade> nextUpgrades = shuffleNextUpgrades();

bool canUpgrade() => nextUpgrades.isNotEmpty;
int totalUpgradeLevel() => staticUpgrades.fold(0, (total, upgrade) => total + upgrade.level);

List<Upgrade> shuffleNextUpgrades() {
  final List<Upgrade> availableUpgrades = staticUpgrades
      .where((upgrade) =>
          // Upgrade level-ups are currently included; can disable by prepending !upgrade.owned &&
          upgrade.level < upgrade.maxLevel)
      .toList();
  final List<Upgrade> alwaysAppearUpgrades = Constants.isDebug ? availableUpgrades.where((upgrade) => upgrade.alwaysAppear).toList() : [];
  availableUpgrades.shuffle(); // in-place operation
  return [
    ...(alwaysAppearUpgrades.length > 4 ? alwaysAppearUpgrades.sublist(0, 4) : alwaysAppearUpgrades),
    ...(availableUpgrades.length > 4 ? availableUpgrades.sublist(0, max(0, 4 - alwaysAppearUpgrades.length)) : availableUpgrades)
  ];
}

List<Upgrade> getUpgradeSelectionOptions() {
  return nextUpgrades;
}

void selectUpgrade(GameState gs, Upgrade upgrade) {
  upgrade.owned = true;
  upgrade.level += 1;
  upgrade.description = upgrade._getDescription(upgrade.level + 1); // This is the "preview" of the next level

  if (upgrade.level == 1) {
    pushUpgradeModifiersToGameState(gs, upgrade);
  }

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
  handlerMap[handler.trigger]!.add((GameState gs, StackList<ActionEffect> effectStack, Param param, double value) {
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
