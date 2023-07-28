import 'package:alignment_is_hard/components/resource_display.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:flutter/material.dart' hide Action, Actions;

PreferredSize buildTopBar(BuildContext context, GameState gs) {
  final appbarSize = Size(MediaQuery.of(context).size.width, 48);
  return PreferredSize(
      preferredSize: appbarSize,
      child: Container(
          height: appbarSize.height,
          color: GameColors.mainColor,
          child: Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,

            children: [
              Text('Money: ${gs.money}'),
              Text('Alignment acceptance: ${gs.alignmentAcceptance}'),
              TimeDisplay(gs.turn, gs.getYear()),
              Text('Game speed: ${gs.gameSpeed}x')
            ], // TODO: Add icons and numbers to main app bar
          )));
}
