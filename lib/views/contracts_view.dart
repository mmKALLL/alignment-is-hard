import 'package:alignment_is_hard/components/action_buttons.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/contract.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class ContractsView extends StatelessWidget {
  const ContractsView(this.gs, this.handleAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    final List<Contract> contracts = gs.contracts;
    final List<Widget> contractWidgets =
        contracts.map((contract) => ContractWidget(contracts.indexOf(contract), gs, contract, handleAction)).toList();
    return Center(
        child: Column(
      children: [
        Text('Trust: ${gs.trust}%, ${(gs.turn % gs.contractCycle)}/${gs.contractCycle} days until new contracts.'),
        Text('Alignment contract win condition: ${gs.finishedAlignmentContracts}/${gs.alignmentContractsNeededToWin}'),
        Row(
          children: contractWidgets,
        ),
        ActionButton(gs, handleAction, actions.refreshContracts, Icons.add),
      ],
    ));
  }
}

class ContractWidget extends StatelessWidget {
  const ContractWidget(this.index, this.gs, this.contract, this.handleAction, {Key? key}) : super(key: key);

  final int index;
  final GameState gs;
  final Contract contract;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    return Container(
        padding: const EdgeInsets.all(8),
        width: 200,
        height: 300,
        child: Card(
            // clipBehavior is necessary because, without it, the InkWell's animation
            // will extend beyond the rounded edges of the [Card] (see https://github.com/flutter/flutter/issues/109776)
            // This comes with a small performance cost, and you should not set [clipBehavior]
            // unless you need it.
            clipBehavior: Clip.hardEdge,
            color: contract.failed
                ? Colors.red.shade200
                : contract.succeeded
                    ? Colors.green.shade200
                    : contract.started
                        ? Colors.blue.shade200
                        : Colors.grey.shade300,
            child: InkWell(
                splashColor: Colors.blue.withAlpha(30),
                onTap: () {
                  if (contract.succeeded || contract.failed) handleAction(actions.contractClaimed(index));
                  if (!contract.started) handleAction(actions.contractAccept(index));
                },
                child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Text(
                          '${contract.name} (${contract.isAlignmentContract ? 'A' : 'C'}, ${contract.deadline - contract.daysSinceStarting} days)'),
                      Text('Req: ${contract.requirementDescription}'),
                      paddedGameScreenDivider,
                      Text('On accept: ${contract.acceptDescription}'),
                      paddedGameScreenDivider,
                      Text('Success: ${contract.successDescription}'),
                      paddedGameScreenDivider,
                      Text('Failure: ${contract.failureDescription}')
                    ])))));
  }
}
