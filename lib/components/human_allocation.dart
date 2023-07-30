import 'package:alignment_is_hard/components/resource_display.dart';
import 'package:alignment_is_hard/components/action_buttons.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class HumanAllocation extends StatelessWidget {
  const HumanAllocation({
    required this.gs,
    this.handleAction,
    Key? key,
  }) : super(key: key);

  final GameState gs;
  final Function? handleAction;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NumericDisplay(name: 'free humans', value: gs.freeHumans, isPercentage: false),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResourceMeter(paramToLabel(Param.rp), gs.rp, GameColors.energyColor),
                ResourceMeter('Progress', gs.rpProgress, GameColors.energyColor, true),
                if (handleAction != null)
                  AllocationButtons(gs, gs.rpWorkers, handleAction!, actions.addHumanToRp, actions.removeHumanFromRp),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResourceMeter('EP', gs.ep, GameColors.energyColor),
                ResourceMeter('Progress', gs.epProgress, GameColors.energyColor, true),
                if (handleAction != null)
                  AllocationButtons(gs, gs.epWorkers, handleAction!, actions.addHumanToEp, actions.removeHumanFromEp),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResourceMeter('SP', gs.sp, GameColors.energyColor),
                ResourceMeter('Progress', gs.spProgress, GameColors.energyColor, true),
                if (handleAction != null)
                  AllocationButtons(gs, gs.spWorkers, handleAction!, actions.addHumanToSp, actions.removeHumanFromSp),
              ],
            ),
            if (handleAction != null) ActionButton(gs, handleAction!, actions.hireHuman(), Icons.currency_exchange_sharp),
          ],
        ));
  }
}
