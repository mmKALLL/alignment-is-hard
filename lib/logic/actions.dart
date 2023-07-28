import 'dart:math';

import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/logic/game_state.dart';

class Actions {
  Actions(this.gs);
  final GameState gs;

  late Action addHumanToRp = Action(
    'Add human to RP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.rpWorkers, 1),
      // if (gs.health < healthIllnessThreshold) ActionEffect('health', 2),
      // if (gs.happiness < 25) ActionEffect('happiness', 1)
    ],
  );
  late Action removeHumanFromRp = Action(
    'Remove human from RP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.rpWorkers, -1),
    ],
  );
  late Action addHumanToEp = Action(
    'Add human to EP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.epWorkers, 1),
    ],
  );
  late Action removeHumanFromEp = Action(
    'Remove human from EP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.epWorkers, -1),
    ],
  );
  late Action addHumanToSp = Action(
    'Add human to SP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.spWorkers, 1),
    ],
  );
  late Action removeHumanFromSp = Action(
    'Remove human from SP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.spWorkers, -1),
    ],
  );

  gotoScreen(int screen, String name) => Action(
        'Go to $name',
        [ActionEffect(Param.currentScreen, screen)],
      );
  late Action gotoUpgradeScreen = Action(
    'Purchase upgrades',
    [ActionEffect(Param.currentScreen, Screen.upgrades)],
  );
  late Action gotoHumanAllocationScreen = Action(
    'Allocate humans',
    [ActionEffect(Param.currentScreen, Screen.humanAllocation)],
  );
  late Action gotoGameScreen = Action(
    'Return',
    [ActionEffect(Param.currentScreen, Screen.ingame), ActionEffect(Param.gameSpeed, 1)],
  );
  late Action gotoGameOver = Action(
    'Lose the game (debug)',
    [ActionEffect(Param.currentScreen, Screen.gameOver), ActionEffect(Param.gameSpeed, 1)],
  );
  late Action gotoGameWin = Action(
    'Win the game (debug)',
    [ActionEffect(Param.currentScreen, Screen.victory), ActionEffect(Param.gameSpeed, 1)],
  );

  contractAccept(index) => Action('Accept contract', [ActionEffect(Param.contractAccept, index)], Event('contractAccept'));
  contractSuccess(index) => Action('Contract success', [ActionEffect(Param.contractSuccess, index)], Event('contractSuccess'));
  contractFailure(index) => Action('Contract failure', [ActionEffect(Param.contractFailure, index)], Event('contractFailure'));

  // UPGRADE ACTIONS

  late Action structureLevelUpgrade = Action(
    'Get 5% more influence (Lv. ${gs.upgrades.influenceLevel})',
    [ActionEffect(Param.money, -pow(gs.upgrades.influenceLevel + 1, 1.8).round() * 30), ActionEffect(Param.influence, 5)],
  );
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
  int timeUsed = 0;

  if (effects[0].paramEffected == Param.resetGame) {
    gs.currentScreen = Screen.ingame;
    gs = GameState();
    return;
  }

  for (var effect in effects) {
    switch (effect.paramEffected) {
      case Param.currentScreen:
        gs.currentScreen = effect.value;
        if (effect.value != Screen.ingame) gs.gameSpeed = 0;
        break;
      case Param.resetGame:
        break;
      case Param.upgradeSelection:
        gs.gameSpeed = 0;
        gs.currentScreen = Screen.upgradeSelection;
        gs.upgradesToSelect = []; // TODO: Add upgrade selection mechanism
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
        break;
      case Param.ep:
        gs.ep += effect.value;
        break;
      case Param.sp:
        gs.sp += effect.value;
        break;

      // Upgrades, contracts, etc
      case Param.contractAccept:
        gs.contracts[effect.value].started = true;
        gs.contracts[effect.value].daysSinceStarting = 0;
        gs = reduceActionEffects(gs, gs.contracts[effect.value].onAccept);
        break;
      case Param.contractSuccess:
        gs.contracts[effect.value].completed = true;
        gs = reduceActionEffects(gs, gs.contracts[effect.value].onSuccess);
        gs.contracts[effect.value] = getRandomContract(gs);
        break;
      case Param.contractFailure:
        gs.contracts[effect.value].completed = true;
        gs = reduceActionEffects(gs, gs.contracts[effect.value].onFailure);
        gs.contracts[effect.value] = getRandomContract(gs);
        break;
    }
  }

  // Turn taken
  if (timeUsed > 0) {
    return reduceTimeStep(gs, timeUsed);
  }

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

validateActionResourceSufficiency(GameState gs, ActionEffect effect) {
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
      return true;
    case Param.upgradeSelection:
      return true;
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
      return gs.contracts[amount].started == false;
    case Param.contractSuccess:
      return gs.contracts[amount].started == true && gs.contracts[amount].completed == false;
    case Param.contractFailure:
      return gs.contracts[amount].started == true && gs.contracts[amount].completed == false;
    // No default switch case acts as an assertNever; you get warnings if a case is not handled. Handling all of them causes the below return to be unreachable.
  }
  return true;
}

reduceTimeStep(GameState gs, int timeUsed) {
  if (gs.gameSpeed == 0) return;
  gs.turn += timeUsed;

  gs.money += gs.passiveMoneyGain;
  gs.money -= gs.getTotalWorkers() * 10 + gs.freeHumans;

  gs.rpProgress += gs.rpWorkers;
  gs.epProgress += gs.epWorkers;
  gs.spProgress += gs.spWorkers;
  if (gs.toNextRP() <= 0) {
    gs.rpProgress -= gs.progressPerLevel;
    gs.rp += 1;
    gs.totalRp += 1;
  }
  if (gs.toNextEP() <= 0) {
    gs.epProgress -= gs.progressPerLevel;
    gs.ep += 1;
    gs.totalEp += 1;
  }
  if (gs.toNextSP() <= 0) {
    gs.spProgress -= gs.progressPerLevel;
    gs.sp += 1;
    gs.totalSp += 1;
  }

  // gs.contracts.map((e) => {
  //   if (e.started && !e.completed) {e.daysSinceStarting += timeUsed}
  //  return e
  //  });
}
