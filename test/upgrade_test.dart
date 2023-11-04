import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:test/test.dart';

void main() {
  group('Poetry Generator', () {
    test('SP cost should be decreased by 20% per level', () {
      final gs = GameState();
      final actions = Actions(gs);
      expect(actions.influenceAlignmentAcceptance().effects.last.paramEffected, Param.sp);
      expect(actions.influenceAlignmentAcceptance().effects.last.value, -10);

      // TODO: need to actually do the action and its reducer to find out the difference in SP. Just looking at the action is no enough
      selectUpgrade(gs, staticUpgrades.firstWhere((u) => u.id == UpgradeId.PoetryGenerator));
      expect(actions.influenceAlignmentAcceptance().effects.last.value, -8); // Decrease by 20%

      selectUpgrade(gs, staticUpgrades.firstWhere((u) => u.id == UpgradeId.PoetryGenerator));
      expect(actions.influenceAlignmentAcceptance().effects.last.value, -6); // Decrease by another 20%
    });
  });
}
