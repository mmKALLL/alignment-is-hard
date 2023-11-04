import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/main.dart';

bool validateActionResourceSufficiency(GameState gs, ActionEffect effect) {
  final value = effect.value;
  final valueInt = value.toInt(); // Needed for indexed array access

// First check things that don't target a specific resource
  switch (effect.paramEffected) {
    case Param.contractAccept:
      return gs.contracts[valueInt].started == false;
    case Param.contractSuccess:
      return gs.contracts[valueInt].started == true && gs.contracts[valueInt].succeeded == false;
    case Param.contractFailure:
      return gs.contracts[valueInt].started == true && gs.contracts[valueInt].failed == false;
    case Param.refreshContracts:
      return gs.contracts.any((c) => !c.started);
    case Param.contractClaimed:
      return gs.contracts[valueInt].started == true && (gs.contracts[valueInt].succeeded || gs.contracts[valueInt].failed);
    case Param.organizationAlignmentDisposition:
      return gs.organizations[valueInt].active &&
          gs.organizations[valueInt].alignmentDisposition < 60 - Constants.organizationAlignmentDispositionGain;
    case Param.upgradeSelection:
      return canUpgrade();
    default:
      break;
  }

  // All resources can always be added to. First check if effects of increase are legal
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

  // Then validate resource sufficiency for negative effects
  final amount = effect.value.abs();
  switch (effect.paramEffected) {
    case Param.currentScreen:
      return gs.currentScreen >= amount;
    case Param.resetGame:
    case Param.upgradeSelection:
    case Param.gameSpeed:
    case Param.day:
      return true;

    case Param.money:
      return gs.money >= amount;
    case Param.trust:
      return gs.trust >= amount;
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
    case Param.rpProgress:
      return gs.rpProgress >= amount;
    case Param.epProgress:
      return gs.epProgress >= amount;
    case Param.spProgress:
      return gs.spProgress >= amount;

    case Param.alignmentAcceptance:
    case Param.asiOutcome:
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
