import 'dart:math';

import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/logic/util.dart';
import 'package:alignment_is_hard/main.dart';

class Actions {
  Actions(this.gs);
  final GameState gs;

  Action pauseGame() => Action(
        'Pause',
        [
          ActionEffect(Param.gameSpeed, gs.gameSpeed == 0 ? gs.lastSelectedGameSpeed : 0),
        ],
      );
  Action changeSpeed(int multiplier) => Action(
        'Change game speed',
        [
          ActionEffect(Param.gameSpeed, multiplier),
        ],
      );

  Action influenceAlignmentAcceptance() => Action(
        'Influence public opinion',
        [
          ActionEffect(Param.alignmentAcceptance, (gs.influence / 10).round()),
          ActionEffect(Param.sp, -(10 - getUpgrade(UpgradeId.PoetryGenerator).level * 2)),
        ],
        Event('influenceAlignmentAcceptance'),
      );
  Action increaseInfluence() => Action(
        'Increase influence',
        [
          ActionEffect(Param.influence, 10),
          ActionEffect(Param.sp, -(5 - getUpgrade(UpgradeId.PoetryGenerator).level)),
        ],
        Event('increaseInfluence'),
      );
  static int nextResearchQuality = 100 + Random().nextInt(20);
  Action researchUpgrade() => Action(
        'Research an upgrade',
        [
          ActionEffect(Param.upgradeSelection, nextResearchQuality),
          // ActionEffect(Param.rp, -(3 + gs.upgrades.length))
          // ActionEffect(Param.rp, -(3 + totalUpgradeLevel()))
          ActionEffect(Param.rp, -3)
        ],
      );
  Action influenceOrganizationAlignmentDisposition(orgIndex) => Action(
        'Influence organization alignment disposition',
        [
          ActionEffect(Param.organizationAlignmentDisposition, (orgIndex)),
          ActionEffect(Param.rp, -Constants.organizationAlignmentDispositionRpUse),
        ],
        Event('influenceOrganizationAlignmentDisposition'),
      );

  Action hireHuman() => Action(
        'Hire a new human',
        [
          ActionEffect(Param.freeHumans, 1),
          ActionEffect(Param.sp, -(gs.getTotalHumans() * (1 - getUpgrade(UpgradeId.PoetryGenerator).level * 0.2)).round()),
        ],
        Event('hireHuman'),
      );

  final Action addHumanToRp = Action(
    'Add human to RP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.rpWorkers, 1),
      // if (gs.health < healthIllnessThreshold) ActionEffect('health', 2),
      // if (gs.happiness < 25) ActionEffect('happiness', 1)
    ],
  );
  final Action removeHumanFromRp = Action(
    'Remove human from RP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.rpWorkers, -1),
    ],
  );
  final Action addHumanToEp = Action(
    'Add human to EP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.epWorkers, 1),
    ],
  );
  final Action removeHumanFromEp = Action(
    'Remove human from EP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.epWorkers, -1),
    ],
  );
  final Action addHumanToSp = Action(
    'Add human to SP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.spWorkers, 1),
    ],
  );
  final Action removeHumanFromSp = Action(
    'Remove human from SP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.spWorkers, -1),
    ],
  );

  Action gotoScreen(int screen, String name) => Action(
        'Go to $name',
        [ActionEffect(Param.currentScreen, screen)],
      );
  final Action gotoHumanAllocationScreen = Action(
    'Allocate humans',
    [ActionEffect(Param.currentScreen, Screen.humanAllocation)],
  );
  final Action gotoGameScreen = Action(
    'Return',
    [ActionEffect(Param.currentScreen, Screen.ingame), ActionEffect(Param.gameSpeed, 1)],
  );
  final Action gotoGameOver = Action(
    'Lose the game (debug)',
    [ActionEffect(Param.currentScreen, Screen.gameOver), ActionEffect(Param.gameSpeed, 0)],
  );
  final Action gotoGameWin = Action(
    'Win the game (debug)',
    [ActionEffect(Param.currentScreen, Screen.victory), ActionEffect(Param.gameSpeed, 0)],
  );

  contractAccept(index) => Action('Accept contract', [ActionEffect(Param.contractAccept, index)], Event('contractAccept'));
  contractSuccess(index) => Action('Contract success', [ActionEffect(Param.contractSuccess, index)], Event('contractSuccess'));
  contractFailure(index) => Action('Contract failure', [ActionEffect(Param.contractFailure, index)], Event('contractFailure'));
  contractClaimed(index) => Action('Claim contract', [ActionEffect(Param.contractClaimed, index)], Event('contractClaimed'));

  final refreshContracts = Action('Refresh contracts', [ActionEffect(Param.refreshContracts, 1), ActionEffect(Param.sp, -1)]);
}

class ActionEffect {
  ActionEffect(this.paramEffected, this.value, [this.description]);
  final Param paramEffected;
  final int value;
  final String? description;

  @override
  String toString() {
    return '${paramToLabel(paramEffected)} ${value > 0 ? '+${value.round()}' : '${value.round()}'}';
  }
}

class Action {
  Action(this.name, this.effects, [this.event]);
  final String name;
  final List<ActionEffect> effects;
  final Event? event;
}

class Event {
  Event(this.name);
  final String name;
}

class ListenableEvent {
  ListenableEvent(this.event, this.handlers);
  final Event event;
  final List<Function> handlers;
}

effectListToString(List<ActionEffect> effects) => effects.map((e) => e.toString()).join(', ');

reduceActionEffects(GameState gs, List<ActionEffect> effects) {
  // Don't allow the action to go through if any effects have insufficient resources
  if (effects.any((effect) => !validateActionResourceSufficiency(gs, effect))) {
    return;
  }

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
        gs.contracts = mapContractStatus(gs, 0);
        reduceActionEffects(gs, gs.contracts[effect.value].onAccept);
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
          gs.finishedAlignmentContracts += contract.isAlignmentContract ? 1 : 0;
          reduceActionEffects(gs, contract.requirements);
        }
        final action = contract.succeeded ? contract.onSuccess : contract.onFailure;
        reduceActionEffects(gs, action);
        gs.contracts[effect.value] = getRandomContract(gs);
        gs.contracts = mapContractStatus(gs, 0);
        break;

      case Param.organizationAlignmentDisposition:
        gs.organizations[effect.value].alignmentDisposition += Constants.organizationAlignmentDispositionGain;
        break;
    }
  }

  checkWinConditions(gs);
}

validateActionResourceSufficiency(GameState gs, ActionEffect effect) {
// First check things that don't target a specific resource
  final value = effect.value;
  switch (effect.paramEffected) {
    case Param.contractAccept:
      return gs.contracts[value].started == false;
    case Param.contractSuccess:
      return gs.contracts[value].started == true && gs.contracts[value].succeeded == false;
    case Param.contractFailure:
      return gs.contracts[value].started == true && gs.contracts[value].failed == false;
    case Param.refreshContracts:
      return gs.contracts.any((c) => !c.started);
    case Param.contractClaimed:
      return gs.contracts[value].started == true && (gs.contracts[value].succeeded || gs.contracts[value].failed);
    case Param.organizationAlignmentDisposition:
      return gs.organizations[value].active &&
          gs.organizations[value].alignmentDisposition < 60 - Constants.organizationAlignmentDispositionGain;
    case Param.upgradeSelection:
      return canUpgrade();
    default:
      break;
  }

  // All resources can always be added to. Negative amounts are validated
  if (effect.value >= 0) {
    switch (effect.paramEffected) {
      case Param.rpWorkers:
        return gs.freeHumans >= effect.value;
      case Param.epWorkers:
        return gs.freeHumans >= effect.value;
      case Param.spWorkers:
        return gs.freeHumans >= effect.value;
      default:
        return true;
    }
  }
  final amount = effect.value.abs();
  switch (effect.paramEffected) {
    case Param.currentScreen:
      return gs.currentScreen >= amount;
    case Param.resetGame:
    case Param.upgradeSelection:
    case Param.gameSpeed:
      return true;

    case Param.money:
      return gs.money >= amount;
    case Param.trust:
      return gs.trust >= amount;
    case Param.alignmentAcceptance:
      return gs.alignmentAcceptance >= amount;
    case Param.influence:
      return gs.influence >= amount;

    case Param.rp:
      return gs.rp >= amount;
    case Param.ep:
      return gs.ep >= amount;
    case Param.sp:
      return gs.sp >= amount;
    case Param.rpWorkers:
      return gs.rpWorkers >= amount;
    case Param.epWorkers:
      return gs.epWorkers >= amount;
    case Param.spWorkers:
      return gs.spWorkers >= amount;
    case Param.freeHumans:
      return gs.freeHumans >= amount;

    case Param.contractAccept:
    case Param.contractSuccess:
    case Param.contractFailure:
    case Param.refreshContracts:
    case Param.contractClaimed:
    case Param.organizationAlignmentDisposition:
      return true;

    // No default switch case acts as an assertNever; you get warnings if a case is not handled.
  }
}

reduceTimeStep(GameState gs, int timeUsed) {
  if (gs.gameSpeed == 0) return;
  gs.turn += timeUsed;

  gs.money += gs.passiveMoneyGain;
  gs.money -= gs.getTotalWorkers();
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

  gs.contracts = mapContractStatus(gs, timeUsed);
  gs.organizations = mapOrganizationStatus(gs, timeUsed);
  checkWinConditions(gs);
}

List<Contract> mapContractStatus(GameState gs, int timeUsed) {
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

List<Organization> mapOrganizationStatus(GameState gs, int timeUsed) {
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

  final feature = pickWeighted(eligibleFeatures);
  feature.level += 1;
  gs.alignmentAcceptance += feature.level <= 1
      ? 0
      : isAlignmentBreakthrough
          ? 1
          : -1;
  gs.asiOutcome += sign * feature.level;

  int featureIndex = o.features.indexWhere((element) => element.name == feature.name);
  o.features[featureIndex] = feature;
  if (feature.level == featureMaxLevel && eligibleFeatures.length == 1) {
    setOrganizationInactive(o);
  }
  // TODO - handle this in a more robust way, currently breakthroughs circumvent the entire action effect reducer
  // TODO - launch an event on breakthrough
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
