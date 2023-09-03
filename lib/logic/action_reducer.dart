import 'dart:math';

import 'package:alignment_is_hard/logic/action_validator.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/logic/weighted.dart';
import 'package:alignment_is_hard/main.dart';

reduceActionEffects(GameState gs, List<ActionEffect> effects, EventId eventId) {
  // Don't allow the action to go through if any effects have insufficient resources
  if (effects.any((effect) => !validateActionResourceSufficiency(gs, effect))) {
    return;
  }

  // FIXME: Create a stack of effects and apply them one by one, along with any mods from game state. Finally call all the event handlers triggered by the event id

  for (var effect in effects) {
    switch (effect.paramEffected) {
      case Param.currentScreen:
        gs.currentScreen = effect.value;
        if (effect.value != Screen.ingame) gs.gameSpeed = 0;
        if (effect.value == Screen.ingame) gs.gameSpeed = gs.lastSelectedGameSpeed;
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
        gs.gameSpeed = effect.value;
        if (effect.value != 0) gs.lastSelectedGameSpeed = effect.value;
        break;

      case Param.money:
        gs.money += effect.value;
        break;
      case Param.trust:
        gs.trust += effect.value;
        break;
      case Param.alignmentAcceptance:
        gs.alignmentAcceptance += effect.value;
        break;
      case Param.asiOutcome:
        gs.asiOutcome += effect.value;
        break;
      case Param.influence:
        gs.influence += effect.value;
        break;
      case Param.freeHumans:
        gs.freeHumans += effect.value;
        break;
      case Param.rpWorkers:
        gs.rpWorkers += effect.value;
        break;
      case Param.epWorkers:
        gs.epWorkers += effect.value;
        break;
      case Param.spWorkers:
        gs.spWorkers += effect.value;
        break;
      case Param.rp:
        gs.rp += effect.value;
        if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
          gs.rp += 1;
        }
        break;
      case Param.ep:
        gs.ep += effect.value;
        if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
          gs.ep += 1;
        }
        break;
      case Param.sp:
        gs.sp += effect.value;
        if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
          gs.sp += 1;
        }
        break;

      // Upgrades, contracts, etc
      case Param.contractAccept:
        gs.contracts[effect.value].started = true;
        gs.contracts[effect.value].daysSinceStarting = 0;
        gs.contracts = updateContractStatus(gs, 0);
        reduceActionEffects(gs, gs.contracts[effect.value].onAccept, EventId.contractAccept);
        break;
      case Param.contractSuccess:
        gs.contracts[effect.value].succeeded = true;
        break;
      case Param.contractFailure:
        gs.contracts[effect.value].failed = true;
        break;
      case Param.refreshContracts:
        gs.contracts = gs.contracts.map((Contract c) => c.started ? c : getRandomContract(gs)).toList();
        break;

      case Param.contractClaimed:
        final contract = gs.contracts[effect.value];
        if (!(contract.succeeded || contract.failed)) break;
        if (contract.succeeded) {
          // Remove the resources promised by the contract before getting the rewards
          gs.finishedAlignmentContracts += contract.isAlignmentContract ? 1 : 0;
          reduceActionEffects(gs, contract.requirements, EventId.internalStateChange);
        }
        final action = contract.succeeded ? contract.onSuccess : contract.onFailure;
        final eventId = contract.succeeded ? EventId.contractSuccess : EventId.contractFailure;
        reduceActionEffects(gs, action, eventId);
        gs.contracts[effect.value] = getRandomContract(gs);
        gs.contracts = updateContractStatus(gs, 0);
        break;

      case Param.organizationAlignmentDisposition:
        gs.organizations[effect.value].alignmentDisposition += Constants.organizationAlignmentDispositionGain;
        break;
    }
  }

  checkWinConditions(gs);
}

reduceTimeStep(GameState gs, int timeUsed) {
  if (gs.gameSpeed == 0) return;
  gs.turn += timeUsed;

  gs.money += gs.passiveMoneyGain;
  gs.money -= gs.getTotalWorkers() * gs.wagePerHumanPerDay;
  gs.money += gs.rpWorkers * getUpgrade(UpgradeId.CognitiveEmulation).level * 0.3;

  gs.rpProgress += gs.rpWorkers;
  gs.epProgress += gs.epWorkers;
  gs.spProgress += gs.spWorkers;
  if (gs.toNextRP() <= 0) {
    gs.rpProgress -= gs.progressPerLevel;
    gs.rp += 1;
    gs.totalRp += 1;
    if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
      gs.rp += 1;
      gs.totalRp += 1;
    }
  }
  if (gs.toNextEP() <= 0) {
    gs.epProgress -= gs.progressPerLevel;
    gs.ep += 1;
    gs.totalEp += 1;
    if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
      gs.ep += 1;
      gs.totalEp += 1;
    }
  }
  if (gs.toNextSP() <= 0) {
    gs.spProgress -= gs.progressPerLevel;
    gs.sp += 1;
    gs.totalSp += 1;
    if (Random().nextInt(10) < getUpgrade(UpgradeId.RewardHacking).level) {
      gs.sp += 1;
      gs.totalSp += 1;
    }
  }

  gs.contracts = updateContractStatus(gs, timeUsed);
  gs.organizations = updateOrganizationStatus(gs, timeUsed);
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
