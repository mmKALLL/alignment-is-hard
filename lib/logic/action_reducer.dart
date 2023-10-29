import 'dart:math';

import 'package:alignment_is_hard/logic/action_validator.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/stack_list.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/logic/weighted.dart';
import 'package:alignment_is_hard/main.dart';

reduceActionEffects(GameState gs, List<ActionEffect> effects, [EventId eventId = EventId.internalStateChange]) {
  // Don't allow the action to go through if any effects have insufficient resources
  if (effects.any((effect) => !validateActionResourceSufficiency(gs, effect))) {
    return;
  }

  // Keep track of triggered event handlers to prevent infinite loops. No handler may fire more than a specified number of times. Don't change the list of handlers within gs during reduceActionEffects
  Map<Param, int> paramEventHandlerCounts = {};
  Map<EventId, int> actionEventHandlerCounts = {};
  const maxCallStack = 5;

  // Create a stack of effects and apply them one by one, along with any mods from game state
  StackList<ActionEffect> effectStack = StackList(effects);

  // First we handle any event handlers, so that they have an opportunity to push additional effects to the stack. However, events only get handled once; the reduction doesn't generate additional events.
  final actionEventHandlers = gs.eventHandlers[eventId] ?? [];
  for (var handler in actionEventHandlers) {
    actionEventHandlerCounts[eventId] = (actionEventHandlerCounts[eventId] ?? 0) + 1;
    if (actionEventHandlerCounts[eventId]! <= maxCallStack) {
      handler(gs, effectStack, eventId);
    }
  }

  while (effectStack.isNotEmpty) {
    final effect = effectStack.pop();
    if (effect == null) continue;

    final effectValue = applyParamModifiers(effect, gs.addModifiers, gs.multModifiers, gs.functionModifiers);

    // Apply the effect to the game state
    applyParamUpdate(gs, effect.paramEffected, effectValue);

    // Call any further handlers that resulted from the param / event being modified
    final paramEventHandlers = gs.paramEventHandlers[effect.paramEffected] ?? [];
    for (var handler in paramEventHandlers) {
      paramEventHandlerCounts[effect.paramEffected] = (paramEventHandlerCounts[effect.paramEffected] ?? 0) + 1;
      if (paramEventHandlerCounts[effect.paramEffected]! <= maxCallStack) {
        handler(gs, effectStack, effect.paramEffected, effectValue);
      }
    }
  }

  checkWinConditions(gs);
}

int applyParamModifiers(ActionEffect effect, Map<Param, List<CurriedModifier>> addModifiers,
    Map<Param, List<CurriedModifier>> multModifiers, Map<Param, List<CurriedModifier>> functionModifiers) {
  double value = effect.value.toDouble();

  // Apply any mods to the effect
  for (CurriedModifier modifier in addModifiers[effect.paramEffected] ?? []) {
    value = modifier(value);
  }

  for (CurriedModifier modifier in multModifiers[effect.paramEffected] ?? []) {
    value = modifier(value);
  }

  for (CurriedModifier modifier in functionModifiers[effect.paramEffected] ?? []) {
    value = modifier(value);
  }

  int truncatedValue = value.toInt();
  return truncatedValue;
}

applyParamUpdate(GameState gs, Param paramEffected, int value) {
  switch (paramEffected) {
    case Param.currentScreen:
      gs.currentScreen = value;
      if (value != Screen.ingame) gs.gameSpeed = 0;
      if (value == Screen.ingame) gs.gameSpeed = gs.lastSelectedGameSpeed;
      break;
    case Param.resetGame:
      break;
    case Param.upgradeSelection:
      // The value in this case is rarity, usually in range [100,250]
      gs.gameSpeed = 0;
      gs.currentScreen = Screen.upgradeSelection;
      gs.upgradesToSelect = getUpgradeSelectionOptions();
      Actions.nextResearchQuality = 100 + Random().nextInt(gs.upgrades.length * 15 + 20);
      break;
    case Param.gameSpeed:
      gs.gameSpeed = value;
      if (value != 0) gs.lastSelectedGameSpeed = value;
      break;
    case Param.day:
      gs.turn += value;
      break;

    case Param.money:
      gs.money += value;
      break;
    case Param.trust:
      gs.trust += value;
      break;
    case Param.alignmentAcceptance:
      gs.alignmentAcceptance += value;
      break;
    case Param.asiOutcome:
      gs.asiOutcome += value;
      break;
    case Param.influence:
      gs.influence += value;
      break;
    case Param.freeHumans:
      gs.freeHumans += value;
      break;
    case Param.rpWorkers:
      gs.rpWorkers += value;
      break;
    case Param.epWorkers:
      gs.epWorkers += value;
      break;
    case Param.spWorkers:
      gs.spWorkers += value;
      break;
    case Param.rpProgress:
      gs.rpProgress += value;
      break;
    case Param.epProgress:
      gs.epProgress += value;
      break;
    case Param.spProgress:
      gs.spProgress += value;
      break;
    case Param.rp:
      gs.rp += value;
      gs.totalRp += value;
      break;
    case Param.ep:
      gs.ep += value;
      gs.totalEp += value;
      break;
    case Param.sp:
      gs.sp += value;
      gs.totalSp += value;
      break;

    // Upgrades, contracts, etc
    case Param.contractAccept:
      gs.contracts[value].started = true;
      gs.contracts[value].daysSinceStarting = 0;
      gs.contracts = updateContractStatus(gs, 0);
      reduceActionEffects(gs, gs.contracts[value].onAccept, EventId.contractAccept);
      break;
    case Param.contractSuccess:
      gs.contracts[value].succeeded = true;
      break;
    case Param.contractFailure:
      gs.contracts[value].failed = true;
      break;
    case Param.refreshContracts:
      gs.contracts = gs.contracts.map((Contract c) => c.started ? c : getRandomContract(gs)).toList();
      break;

    case Param.contractClaimed:
      final contract = gs.contracts[value];
      if (!(contract.succeeded || contract.failed)) break;
      if (contract.succeeded) {
        // Remove the resources promised by the contract before getting the rewards
        gs.finishedAlignmentContracts += contract.isAlignmentContract ? 1 : 0;
        reduceActionEffects(gs, contract.requirements, EventId.internalStateChange);
      }
      final action = contract.succeeded ? contract.onSuccess : contract.onFailure;
      final eventId = contract.succeeded ? EventId.contractSuccess : EventId.contractFailure;
      reduceActionEffects(gs, action, eventId);
      gs.contracts[value] = getRandomContract(gs);
      gs.contracts = updateContractStatus(gs, 0);
      break;

    case Param.organizationAlignmentDisposition:
      gs.organizations[value].alignmentDisposition += Constants.organizationAlignmentDispositionGain;
      break;
  }
}

incrementParam(GameState gs, Param param, [int value = 1, EventId event = EventId.internalStateChange]) {
  return reduceActionEffects(gs, [ActionEffect(param, 1)], event);
}

reduceTimeStep(GameState gs) {
  if (gs.gameSpeed == 0) return;

  reduceActionEffects(
      gs,
      [
        ActionEffect(Param.day, 1),
        ActionEffect(Param.money, gs.passiveMoneyGain),
        ActionEffect(Param.money, (-gs.getTotalWorkers() * gs.wagePerHumanPerDay).round()),
        ActionEffect(Param.rpProgress, gs.rpWorkers),
        ActionEffect(Param.epProgress, gs.epWorkers),
        ActionEffect(Param.spProgress, gs.spWorkers),
      ],
      EventId.dayChange);

  if (gs.toNextRP() <= 0) {
    gs.rpProgress -= gs.progressPerLevel;
    incrementParam(gs, Param.rp);
  }
  if (gs.toNextEP() <= 0) {
    gs.epProgress -= gs.progressPerLevel;
    incrementParam(gs, Param.ep);
  }
  if (gs.toNextSP() <= 0) {
    gs.spProgress -= gs.progressPerLevel;
    incrementParam(gs, Param.sp);
  }

  gs.contracts = updateContractStatus(gs, 1);
  gs.organizations = updateOrganizationStatus(gs, 1);
  checkWinConditions(gs);
}

List<Contract> updateContractStatus(GameState gs, int timeUsed) {
  return gs.contracts.map((c) {
    if (c.started) {
      if (!(c.failed)) c.daysSinceStarting += timeUsed;
      if (c.daysSinceStarting >= c.deadline) c.failed = true;

      // Mark contracts as successful (= ready for collection) if their requirements are met. Even if a contract is successful at one point, its status may change after changes in the game state
      if (!c.failed && c.requirements.every((e) => validateActionResourceSufficiency(gs, e))) {
        c.succeeded = true;
      } else {
        c.succeeded = false;
      }
    } else {
      if (gs.turn % gs.contractCycle == 0) {
        return getRandomContract(gs);
      }
    }
    return c;
  }).toList();
}

List<Organization> updateOrganizationStatus(GameState gs, int timeUsed) {
  return gs.organizations.map((o) {
    if (!o.active) return o;
    o.turnsSinceLastBreakthrough += timeUsed;
    if (o.turnsSinceLastBreakthrough >= o.breakthroughInterval) {
      handleBreakthrough(gs, o);
    }
    return o;
  }).toList();
}

void handleBreakthrough(GameState gs, Organization o) {
  o.turnsSinceLastBreakthrough -= o.breakthroughInterval;
  int alignmentBreakthroughChance = gs.alignmentAcceptance + o.alignmentDisposition;
  bool isAlignmentBreakthrough = Random().nextInt(100) < alignmentBreakthroughChance;
  int sign = isAlignmentBreakthrough ? 1 : -1;

  List<Feature> eligibleFeatures =
      o.features.where((f) => f.isAlignmentFeature == isAlignmentBreakthrough && f.level < featureMaxLevel).toList();
  if (eligibleFeatures.isEmpty) {
    setOrganizationInactive(o);
    return;
  }

  // Select and update a feature within the organization; internal state change
  final feature = pickWeighted(eligibleFeatures);
  feature.level += 1;

  int featureIndex = o.features.indexWhere((element) => element.name == feature.name);
  o.features[featureIndex] = feature;
  if (feature.level == featureMaxLevel && eligibleFeatures.length == 1) {
    setOrganizationInactive(o);
  }

  // Update game state based on the feature level
  final alignmentAcceptanceChange = feature.level <= 1
      ? 0
      : isAlignmentBreakthrough
          ? 1
          : -1;
  final asiOutcomeChange = sign * feature.level;

  reduceActionEffects(
      gs,
      [ActionEffect(Param.alignmentAcceptance, alignmentAcceptanceChange), ActionEffect(Param.asiOutcome, asiOutcomeChange)],
      EventId.organizationBreakthrough);
}

Organization setOrganizationInactive(Organization o) {
  o.active = false;
  o.turnsSinceLastBreakthrough = 0;
  return o;
}

void checkWinConditions(GameState gs) {
  if (gs.isGameOver()) {
    gs.currentScreen = Screen.gameOver;
    gs.gameSpeed = 0;
    return;
  }

  if (gs.isGameWon()) {
    gs.currentScreen = Screen.victory;
    gs.gameSpeed = 0;
    return;
  }
}
