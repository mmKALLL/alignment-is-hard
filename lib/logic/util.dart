import 'package:alignment_is_hard/logic/actions.dart';

effectListToString(List<ActionEffect> effects) => effects.map((e) => e.toString()).join(', ');

// Needed for constant function expressions when defining optional parameters. Anonymous functions are always re-instantiated in Dart...
void noop() {}
bool returnTrue() => true;

String withPlusSign(num value) => value > 0 ? '+$value' : '$value';
