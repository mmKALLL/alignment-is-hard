import 'package:alignment_is_hard/components/resource_display.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:flutter/material.dart' hide Action, Actions;
import 'package:intl/intl.dart';

PreferredSize buildTopBar(BuildContext context, GameState gs) {
  final appbarSize = Size(MediaQuery.of(context).size.width, 48);
  final List<List<Widget>> childRows = [
    [
      getMoneyDisplay(gs),
      Text('Alignment acceptance: ${gs.alignmentAcceptance.toInt()}'),
    ],
    [Text('ASI outcome: ${gs.asiOutcome.toInt()}'), TimeDisplay(gs.turn, gs.getYear()), Text('Game speed: ${gs.gameSpeed}x')]
  ];

  return PreferredSize(
      preferredSize: appbarSize,
      child: Container(
          height: appbarSize.height,
          color: GameColors.mainColor,
          child: Column(
              children: childRows
                  .map((rowChildren) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Wrap(
                              spacing: 20,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: rowChildren,
                            )
                          ],
                        ),
                      ))
                  .toList())));
}

getMoneyDisplay(GameState gs) {
  return Text('Money: \$${NumberFormat.decimalPattern().format((gs.money * 1000).toInt()).toString()}');
}
