import 'dart:math';

import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/main.dart';

class Action {
  Action(this.name, this.effects, this.eventId);
  final String name;
  final List<ActionEffect> effects;
  final EventId eventId;
}

enum EventId {
  // Game screen and main state related
  pauseGame,
  changeSpeed,
  gotoScreen,
  gotoHumanAllocationScreen,
  gotoGameScreen,
  gotoGameOver,
  gotoGameWin,
  resetGame,

  // RP actions
  researchUpgrade,

  // EP / contract related actions
  contractAccept,
  contractSuccess,
  contractFailure,
  contractClaimed,
  refreshContracts,

  // SP actions
  influenceAlignmentAcceptance,
  increaseInfluence,
  influenceOrganizationAlignmentDisposition,
  hireHuman,

  // Human allocation
  addHumanToRp,
  removeHumanFromRp,
  addHumanToEp,
  removeHumanFromEp,
  addHumanToSp,
  removeHumanFromSp,

  // Game state related
  dayChange,
  yearChange,
  organizationBreakthrough,
  internalStateChange, // Should not be listened to in most cases
}

class Actions {
  Actions(this.gs);
  final GameState gs;

  Action pauseGame() => Action(
      'Pause',
      [
        ActionEffect(Param.gameSpeed, gs.gameSpeed == 0 ? gs.lastSelectedGameSpeed : 0),
      ],
      EventId.pauseGame);
  Action changeSpeed(int multiplier) => Action(
      'Change game speed',
      [
        ActionEffect(Param.gameSpeed, multiplier),
      ],
      EventId.changeSpeed);
  Action resetGame = Action('Try again!', [ActionEffect(Param.resetGame, 0)], EventId.resetGame);

  Action influenceAlignmentAcceptance() => Action(
        'Influence public opinion',
        [ActionEffect(Param.alignmentAcceptance, gs.influence / 10), ActionEffect(Param.sp, -10)],
        EventId.influenceAlignmentAcceptance,
      );
  Action increaseInfluence() => Action(
        'Increase influence',
        [
          ActionEffect(Param.influence, 10),
          ActionEffect(Param.sp, -5),
        ],
        EventId.increaseInfluence,
      );
  static double nextResearchQuality = 100.0 + Random().nextInt(20);
  Action researchUpgrade() => Action(
        'Research an upgrade',
        [
          ActionEffect(Param.upgradeSelection, nextResearchQuality),
          // ActionEffect(Param.rp, -(3 + gs.upgrades.length))
          // ActionEffect(Param.rp, -(3 + totalUpgradeLevel()))
          ActionEffect(Param.rp, -4)
        ],
        EventId.researchUpgrade,
      );
  Action influenceOrganizationAlignmentDisposition(orgIndex) => Action(
        'Influence organization alignment disposition',
        [
          ActionEffect(Param.organizationAlignmentDisposition, (orgIndex)),
          ActionEffect(Param.sp, -Constants.organizationAlignmentDispositionSpUse),
        ],
        EventId.influenceOrganizationAlignmentDisposition,
      );

  Action hireHuman() => Action(
        'Hire a new human',
        [
          ActionEffect(Param.freeHumans, 1),
          ActionEffect(Param.sp, -gs.getTotalHumans()),
        ],
        EventId.hireHuman,
      );

  final Action addHumanToRp = Action(
    'Add human to RP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.rpWorkers, 1),
    ],
    EventId.addHumanToRp,
  );
  final Action removeHumanFromRp = Action(
    'Remove human from RP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.rpWorkers, -1),
    ],
    EventId.removeHumanFromRp,
  );
  final Action addHumanToEp = Action(
    'Add human to EP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.epWorkers, 1),
    ],
    EventId.addHumanToEp,
  );
  final Action removeHumanFromEp = Action(
    'Remove human from EP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.epWorkers, -1),
    ],
    EventId.removeHumanFromEp,
  );
  final Action addHumanToSp = Action(
    'Add human to SP',
    [
      ActionEffect(Param.freeHumans, -1),
      ActionEffect(Param.spWorkers, 1),
    ],
    EventId.addHumanToSp,
  );
  final Action removeHumanFromSp = Action(
    'Remove human from SP',
    [
      ActionEffect(Param.freeHumans, 1),
      ActionEffect(Param.spWorkers, -1),
    ],
    EventId.removeHumanFromSp,
  );

  Action gotoScreen(int screen, String name) => Action('Go to $name', [ActionEffect(Param.currentScreen, screen)], EventId.gotoScreen);
  final Action gotoHumanAllocationScreen =
      Action('Allocate humans', [ActionEffect(Param.currentScreen, Screen.humanAllocation)], EventId.gotoHumanAllocationScreen);
  final Action gotoGameScreen = Action('Return', [ActionEffect(Param.currentScreen, Screen.ingame)], EventId.gotoGameScreen);
  final Action gotoGameOver = Action('Lose the game (debug)',
      [ActionEffect(Param.currentScreen, Screen.gameOver), ActionEffect(Param.gameSpeed, 0)], EventId.gotoGameOver);
  final Action gotoGameWin = Action(
      'Win the game (debug)', [ActionEffect(Param.currentScreen, Screen.victory), ActionEffect(Param.gameSpeed, 0)], EventId.gotoGameWin);

  contractAccept(index) => Action('Accept contract', [ActionEffect(Param.contractAccept, index)], EventId.contractAccept);
  contractSuccess(index) => Action('Contract success', [ActionEffect(Param.contractSuccess, index)], EventId.contractSuccess);
  contractFailure(index) => Action('Contract failure', [ActionEffect(Param.contractFailure, index)], EventId.contractFailure);
  contractClaimed(index) => Action('Claim contract', [ActionEffect(Param.contractClaimed, index)], EventId.contractClaimed);

  final refreshContracts =
      Action('Refresh contracts', [ActionEffect(Param.refreshContracts, 1), ActionEffect(Param.sp, -1)], EventId.refreshContracts);
}

// TODO: Rename to "Effect" and move to action_reducer.dart
class ActionEffect {
  ActionEffect(this.paramEffected, this.value, [this.description]);
  final Param paramEffected;
  final num value;
  final String? description;

  @override
  String toString() {
    return '${paramToLabel(paramEffected)} ${value > 0 ? '+${value.round()}' : '${value.round()}'}${paramEffected == Param.money ? 'k' : paramEffected == Param.gameSpeed ? 'x' : ''}';
  }
}
