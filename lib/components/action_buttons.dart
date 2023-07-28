import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class ActionButton extends StatelessWidget {
  const ActionButton(this.gs, this.handleAction, this.action, [this.iconData, key]) : super(key: key);

  final GameState gs;
  final Function handleAction;
  final Action action;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    final effectText =
        [Param.currentScreen, Param.resetGame].contains(action.effects[0].paramEffected) ? null : '(${effectListToString(action.effects)})';
    final labelText = Text(action.name.replaceAll('-', ' '));
    const buttonColor = GameColors.actionButtonColor;
    return ListTile(
      enabled: action.effects.every((effect) => validateActionResourceSufficiency(gs, effect)),
      minVerticalPadding: effectText == null ? 22 : 1,
      title: labelText,
      onTap: () {
        handleAction(action);
      },
      leading: CircleAvatar(
        maxRadius: 20,
        backgroundColor: buttonColor,
        child: Icon(iconData, color: GameColors.actionButtonIconColor),
      ),
    );

    //  iconData != null
    //     ? ElevatedButton.icon(
    //         style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
    //         icon: Icon(iconData),
    //         onPressed: () {
    //           handleAction(actionData);
    //         },
    //         label: labelText)
    //     : ElevatedButton(
    //         style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
    //         onPressed: () {
    //           handleAction(actionData);
    //         },
    //         child: labelText);
  }
}

class IconActionButton extends StatelessWidget {
  const IconActionButton(this.gs, this.handleAction, this.actionData, [this.iconData, this.filled, this.color, key]) : super(key: key);

  final GameState gs;
  final Function handleAction;
  final Action actionData;
  final IconData? iconData;
  final Color? color;
  final bool? filled;

  static const double buttonSize = 32.0;
  static const double iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? GameColors.actionButtonColor;
    const iconColor = GameColors.actionButtonIconColor;
    final enabled = actionData.effects.every((effect) => validateActionResourceSufficiency(gs, effect));
    return FilledButton(
        onPressed: enabled
            ? () {
                handleAction(actionData);
              }
            : null,
        style: ButtonStyle(
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.all(0)),
          backgroundColor: (filled == true) ? MaterialStateProperty.all<Color>(enabled ? buttonColor : GameColors.disabledColor) : null,
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
          minimumSize: MaterialStateProperty.all(const Size(buttonSize, buttonSize)),
          maximumSize: MaterialStateProperty.all(const Size(buttonSize, buttonSize)),
        ),
        child: Icon(
          size: 16,
          iconData,
          color: iconColor,
        ));

    // padding: const EdgeInsets.all(8),

    //  iconData != null
    //     ? ElevatedButton.icon(
    //         style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
    //         icon: Icon(iconData),
    //         onPressed: () {
    //           handleAction(actionData);
    //         },
    //         label: labelText)
    //     : ElevatedButton(
    //         style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
    //         onPressed: () {
    //           handleAction(actionData);
    //         },
    //         child: labelText);
  }
}

const gameScreenDivider = Divider(height: 4, color: Colors.black26);
const paddedGameScreenDivider = Padding(padding: EdgeInsets.only(top: 4, bottom: 4), child: Divider(height: 4, color: Colors.black26));

class GameScreenActionButtons extends StatelessWidget {
  const GameScreenActionButtons(this.gs, this.handleAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    var actions = Actions(gs);

    return ActionButtonList(
      [
        ActionButton(gs, handleAction, actions.gotoUpgradeScreen, Icons.trending_up_sharp),
        gameScreenDivider,
        ActionButton(gs, handleAction, actions.gotoScreen(Screen.contracts, 'contracts'), Icons.trending_up_sharp),
        gameScreenDivider,
        ActionButton(gs, handleAction, actions.hireHuman(), Icons.currency_exchange_sharp),
        gameScreenDivider,
        ActionButton(gs, handleAction, actions.influenceAlignmentAcceptance(), Icons.currency_exchange_sharp),
        gameScreenDivider,
        ActionButton(gs, handleAction, actions.gotoGameOver, Icons.currency_exchange_sharp),
        gameScreenDivider,
        ActionButton(gs, handleAction, actions.gotoGameWin, Icons.currency_exchange_sharp),
      ],
    );
  }
}

class UpgradeScreenActionButtons extends StatelessWidget {
  const UpgradeScreenActionButtons(this.gs, this.handleAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    var actions = Actions(gs);
    return ActionButtonList(
      [
        ActionButton(gs, handleAction, actions.structureLevelUpgrade, Icons.build_sharp),
        gameScreenDivider,
      ],
    );
  }
}

class AllocationButtons extends StatelessWidget {
  const AllocationButtons(this.gs, this.label, this.handleAction, this.plusAction, this.minusAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;
  final Action plusAction;
  final Action minusAction;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconActionButton(gs, handleAction, minusAction, Icons.exposure_minus_1_rounded, true, Colors.redAccent),
        Text(label),
        IconActionButton(gs, handleAction, plusAction, Icons.plus_one_sharp, true, Colors.green),
      ]
          .map((widget) => Padding(
                padding: const EdgeInsets.all(4),
                child: widget,
              ))
          .toList(),
    );
  }
}

class ActionButtonList extends StatelessWidget {
  const ActionButtonList(this.widgets, [key]) : super(key: key);

  final List<Widget> widgets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(spacing: 20, runSpacing: -9, children: widgets),
    );
  }
}
