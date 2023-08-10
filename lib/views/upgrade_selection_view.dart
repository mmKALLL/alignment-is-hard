import 'package:alignment_is_hard/components/action_buttons.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/main.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class UpgradeSelectionView extends StatelessWidget {
  const UpgradeSelectionView(this.gs, this.handleAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    final List<Upgrade> upgradeSelection = getUpgradeSelectionOptions();
    final List<Widget> upgradeWidgets =
        upgradeSelection.map((upgrade) => UpgradeWidget(upgradeSelection.indexOf(upgrade), gs, upgrade, handleAction)).toList();
    return Center(
        child: Column(
      children: [
        const Text('Choose an upgrade!'),
        Row(
          children: upgradeWidgets,
        ),
        TextButton(
            style: Constants.roundedTextButtonStyle,
            onPressed: () {
              nextUpgrades = shuffleNextUpgrades();
              handleAction(actions.gotoGameScreen);
            },
            child: const Text('Skip upgrade'))
      ],
    ));
  }
}

class UpgradeWidget extends StatelessWidget {
  const UpgradeWidget(this.index, this.gs, this.upgrade, this.handleAction, {Key? key}) : super(key: key);

  final int index;
  final GameState gs;
  final Upgrade upgrade;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    return Container(
        padding: const EdgeInsets.all(4),
        width: 200,
        height: 300,
        child: Card(
            clipBehavior: Clip.hardEdge,
            color: Colors.grey.shade300,
            child: InkWell(
                splashColor: Colors.blue.withAlpha(30),
                onTap: () {
                  upgrade.onSelect();
                  handleAction(actions.gotoGameScreen);
                },
                child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Text(upgrade.name),
                      paddedGameScreenDivider,
                      Text('(Level ${upgrade.level}/${upgrade.maxLevel})'),
                      paddedGameScreenDivider,
                      Text(upgrade.description),
                    ])))));
  }
}
