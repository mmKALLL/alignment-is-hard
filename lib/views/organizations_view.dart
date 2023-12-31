import 'dart:math';

import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/util.dart';
import 'package:alignment_is_hard/main.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class OrganizationsView extends StatelessWidget {
  const OrganizationsView(this.gs, this.handleAction, [key]) : super(key: key);

  final GameState gs;
  final Function handleAction;

  @override
  Widget build(BuildContext context) {
    final List<Organization> organizations = gs.organizations;
    final List<Widget> organizationWidgets = organizations
        .map((organization) => OrganizationWidget(organizations.indexOf(organization), gs, organization, handleAction))
        .toList();
    return Center(
        child: Column(
      children: [
        Text('Organizations - next in ${gs.organizationCycle - (gs.turn % gs.organizationCycle)} days'),
        Text(
            'Tap to change attitude by ${Constants.organizationAlignmentDispositionGain} for ${Constants.organizationAlignmentDispositionSpUse} SP'),
        ...organizationWidgets,
      ],
    ));
  }
}

class OrganizationWidget extends StatelessWidget {
  const OrganizationWidget(this.index, this.gs, this.organization, this.handleAction, {Key? key}) : super(key: key);

  final int index;
  final GameState gs;
  final Organization organization;
  final Function handleAction;

  get color => null;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);
    final int ad = organization.alignmentDisposition.toInt();
    return Container(
        padding: const EdgeInsets.all(4),
        width: MediaQuery.of(context).size.width - 8,
        height: 88,
        child: Card(
            // clipBehavior is necessary because, without it, the InkWell's animation
            // will extend beyond the rounded edges of the [Card] (see https://github.com/flutter/flutter/issues/109776)
            // This comes with a small performance cost, and you should not set [clipBehavior]
            // unless you need it.
            clipBehavior: Clip.hardEdge,
            color: Color.fromRGBO(210 + min(45, ad < 0 ? -ad : 0), 220 + min(35, ad > 0 ? ad : 0), 220, 1),
            child: InkWell(
                splashColor: Colors.blue.withAlpha(30),
                onTap: () {
                  handleAction(actions.influenceOrganizationAlignmentDisposition(index));
                },
                child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '${organization.name} (attitude ${withPlusSign(ad)}, ${organization.turnsSinceLastBreakthrough}/${organization.breakthroughInterval}d to breakthrough)'),
                      const SizedBox(height: 8),
                      Wrap(
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: organization.features
                              .sublist(0, 4)
                              .map((feature) => FeatureDisplay(feature, organization.mainFocus == feature.name))
                              .toList()),
                      Wrap(
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: organization.features
                              .sublist(4, 8)
                              .map((feature) => FeatureDisplay(feature, organization.mainFocus == feature.name))
                              .toList()),
                    ])))));
  }
}

class FeatureDisplay extends StatelessWidget {
  const FeatureDisplay(this.feature, this.isMainFocus, [key]) : super(key: key);

  final Feature feature;
  final bool isMainFocus;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
        child: Row(children: [
      Container(
          width: 35,
          height: 16,
          margin: const EdgeInsets.only(right: 2),
          color: isMainFocus ? const Color.fromARGB(48, 94, 99, 255) : null,
          child: Text(getShortFeatureName(feature.name), style: const TextStyle(fontSize: 12))),
      // Boxes to indicate the level of each feature
      ...List.generate(
          featureMaxLevel,
          (index) => Container(
                width: 6, // Can try squeezing the app onto smaller screens by making these smaller and removing margin
                height: 10,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  color: index < feature.level
                      ? feature.isAlignmentFeature
                          ? Colors.green
                          : Colors.red
                      : Colors.white12,
                ),
              )),
    ]));
  }
}
