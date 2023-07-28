import 'package:intl/intl.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:flutter/material.dart' hide Action, Actions;

class ResourceDisplay extends StatelessWidget {
  const ResourceDisplay({
    required this.gs,
    this.handleAction,
    Key? key,
  }) : super(key: key);

  final GameState gs;
  final Function? handleAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TimeDisplay(gs.turn, gs.getYear()),
        const SizedBox(
          height: 8,
        ),
        Wrap(spacing: 20, runSpacing: 8, children: [
          NumericDisplay(name: 'money', value: gs.money, isPercentage: false),
          NumericDisplay(name: 'alignment acceptance', value: gs.alignmentAcceptance, isPercentage: true),
          NumericDisplay(name: 'trust', value: gs.trust, isPercentage: true),
          NumericDisplay(name: 'influence', value: gs.influence, isPercentage: true),
        ]),
      ],
    );
  }
}

class NumericDisplay extends StatelessWidget {
  const NumericDisplay({Key? key, required this.value, required this.name, required this.isPercentage}) : super(key: key);

  final num value;
  final String name;
  final bool isPercentage;

  @override
  Widget build(BuildContext context) {
    var textStyle = (name == 'free humans')
        ? null
        : (name == 'money' && value <= 500) || value <= 1
            ? TextStyle(backgroundColor: Colors.red.withOpacity(0.6))
            : value <= 4 || (name == 'money' && value <= 50)
                ? TextStyle(backgroundColor: Colors.yellow.withOpacity(0.6))
                : null;
    switch (name) {
      case 'money':
        return Text(
          'Money: \$${NumberFormat.decimalPattern().format(value * 100).toString()}',
          style: textStyle,
        );
      default:
        return Text('${capitalize(name)}: ${value.round()}${isPercentage ? '%' : ''}', style: textStyle);
    }
  }
}

capitalize(String name) {
  return name.substring(0, 1).toUpperCase() + name.substring(1);
}

class ResourceMeter extends StatelessWidget {
  const ResourceMeter(this.label, this.value, this.color, [key]) : super(key: key);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.labelLarge!;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          '$label: $value',
          style: style,
        ),
      ),
    );
  }
}

class TimeDisplay extends StatelessWidget {
  const TimeDisplay(this.day, this.year, [key]) : super(key: key);

  final int day;
  final int year;

  @override
  Widget build(BuildContext context) {
    return Text('Day ${day + 1}, year ${year + 2022}');
  }
}
