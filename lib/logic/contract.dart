import 'dart:math';

import 'package:alignment_is_hard/logic/action_reducer.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/logic/util.dart';
import 'package:alignment_is_hard/logic/weighted.dart';
// import 'package:flutter/material.dart' hide Action, Actions;

class Contract {
  Contract(
    this.name,
    this.acceptDescription,
    this.successDescription,
    this.failureDescription,
    this.requirementDescription,
    this.onAccept,
    this.onSuccess,
    this.onFailure,
    this.requirements,
    this.isAlignmentContract,
    this.rarity,
    this.difficulty,
    this.deadline,
  );

  final String name;
  final String acceptDescription;
  final String successDescription;
  final String failureDescription;
  final String requirementDescription;
  final List<ActionEffect> onAccept;
  final List<ActionEffect> onSuccess;
  final List<ActionEffect> onFailure;
  final List<ActionEffect> requirements;

  final bool isAlignmentContract;
  final int rarity; // 1-4
  final int difficulty; // 50-500, 100 is some kind of baseline
  final int deadline;

  int daysSinceStarting = 0;
  bool started = false;
  bool failed = false;
  bool succeeded = false;
}

Contract getRandomContract(GameState gs) {
  // Setup the base parameters that control complexity
  bool isAlignmentContract = Random().nextBool();
  int difficulty = 50 + Random().nextInt(gs.getYear() * 50 + 75);
  int deadline = 5 + Random().nextInt(200) + max(200 - difficulty, 0);
  difficulty += max((100 - deadline), 0);

  // Generate the variables needed for generating action effects
  difficultyWithVariance() => difficulty + Random().nextInt(20 + (difficulty / 5).floor());
  int acceptEffects = 1 + (difficultyWithVariance() / 250).floor();
  int successEffects = 0 + (difficultyWithVariance() / 125).floor();
  int failureEffects = 1 + (difficultyWithVariance() / 150).floor();

  // Generate action effects
  List<ActionEffect> onAccept = getAcceptEffects(difficulty, acceptEffects, isAlignmentContract, gs.trust);
  List<ActionEffect> onSuccess = [
    ActionEffect(Param.trust, ((isAlignmentContract ? 2 : 1) * (2 * difficulty / 100)).roundToDouble()),
    ...getSuccessEffects(difficulty, successEffects, isAlignmentContract, gs.trust)
  ];
  List<ActionEffect> onFailure = [
    ActionEffect(Param.trust, (-6 * (difficulty + 100) / 100).roundToDouble()),
    ...getFailureEffects(difficulty, failureEffects, isAlignmentContract, gs.trust)
  ];

  // Apply upgrades' contract modifiers from game state
  onAccept = onAccept.map((e) => applyContractModifiers(gs, e)).toList();
  onSuccess = onSuccess.map((e) => applyContractModifiers(gs, e)).toList();
  onFailure = onFailure.map((e) => applyContractModifiers(gs, e, true)).toList();

  // Requirements rise exponentially with difficulty
  final int totalRequirement = pow(((100 + difficulty) / 100), 1.7).round();
  final int alignmentRequirement = totalRequirement >= 2 && isAlignmentContract ? (totalRequirement * 0.64).round() : 0;
  final List<ActionEffect> requirements = [
    if (alignmentRequirement > 0) ActionEffect(Param.rp, -alignmentRequirement.toDouble()),
    ActionEffect(Param.ep, -(totalRequirement - alignmentRequirement).toDouble())
  ];

  final acceptDescription = effectListToString(onAccept);
  final successDescription = effectListToString(onSuccess);
  final failureDescription = effectListToString(onFailure);
  final requirementsDescription = effectListToString(requirements);

  final contract = Contract('contract', acceptDescription, successDescription, failureDescription, requirementsDescription, onAccept,
      onSuccess, onFailure, requirements, isAlignmentContract, 1, difficulty, deadline);

  return contract;
}

class WeightedEffect extends Weighted {
  WeightedEffect(weight, this.effect) {
    super.weight = weight;
  }

  final ActionEffect effect;
}

double getRandomValue(int base, int difficulty, [double difficultyFactor = 1]) {
  return base + ((difficulty * 0.85 + Random().nextInt((difficulty / 3).round())) * difficultyFactor).floorToDouble();
}

getContractMoneyValue(int difficulty, int totalEffects, bool isAlignmentContract, double trust) {
  // 50 / RP; 50 => 100, 100 => 200, ...
  // In general alignment contracts pay 70-110% of the cost of solving them, while capability contracts pay 150-220%
  double value = getRandomValue(40, difficulty, 1.5);
  return ((isAlignmentContract ? 0.9 : 2.05) *
          (totalEffects == 0
              ? 1.25
              : totalEffects == 1
                  ? 1
                  : totalEffects == 2
                      ? 0.4
                      : 0.25) *
          (trust / 100) *
          value)
      .round();
}

getAcceptEffects(int difficulty, int totalEffects, bool isAlignmentContract, double trust) {
  return [ActionEffect(Param.money, getContractMoneyValue(difficulty, totalEffects, isAlignmentContract, trust))];
}

getSuccessEffects(int difficulty, int totalEffects, bool isAlignmentContract, double trust) {
  if (totalEffects == 0) {
    return [];
  }

  List<WeightedEffect> alignmentEffectPool = [
    WeightedEffect(10, ActionEffect(Param.alignmentAcceptance, getRandomValue(1, difficulty, 0.02))),
    WeightedEffect(6, ActionEffect(Param.trust, getRandomValue(3, difficulty, 0.015))),
    WeightedEffect(difficulty > 300 ? 1 : 0, ActionEffect(Param.freeHumans, 1)),
    WeightedEffect(difficulty > 220 ? 1 : 0, ActionEffect(Param.upgradeSelection, getRandomValue(25, difficulty, 0.33))),
    WeightedEffect(1, ActionEffect(Param.rp, getRandomValue(1, difficulty, 0.005))),
    WeightedEffect(4, ActionEffect(Param.influence, getRandomValue(3, difficulty, 0.022))),
    WeightedEffect(
        1, ActionEffect(Param.money, (getContractMoneyValue(difficulty, totalEffects, isAlignmentContract, trust) * 0.25).round())),
    WeightedEffect(5, ActionEffect(Param.asiOutcome, getRandomValue(1, difficulty, 0.01))),
  ];

  List<WeightedEffect> capabilityEffectPool = [
    WeightedEffect(20, ActionEffect(Param.alignmentAcceptance, -getRandomValue(1, difficulty, 0.02))),
    WeightedEffect(
        3, ActionEffect(Param.money, (getContractMoneyValue(difficulty, totalEffects, isAlignmentContract, trust) * 0.2).round())),
    WeightedEffect(6, ActionEffect(Param.trust, getRandomValue(3, difficulty, 0.015))),
    WeightedEffect(2, ActionEffect(Param.influence, getRandomValue(3, difficulty, 0.022))),
    WeightedEffect(difficulty > 220 ? 1 : 0, ActionEffect(Param.freeHumans, 1)),
    WeightedEffect(difficulty > 300 ? 1 : 0, ActionEffect(Param.upgradeSelection, getRandomValue(25, difficulty, 0.33))),
    WeightedEffect(2, ActionEffect(Param.sp, getRandomValue(1, difficulty, 0.005))),
  ];

  final effectPool = isAlignmentContract ? alignmentEffectPool : capabilityEffectPool;

  return getEffectsFromPool(totalEffects, effectPool);
}

getFailureEffects(int difficulty, int totalEffects, bool isAlignmentContract, double trust) {
  if (totalEffects == 0) {
    return [];
  }

  List<WeightedEffect> alignmentEffectPool = [
    WeightedEffect(4, ActionEffect(Param.alignmentAcceptance, -getRandomValue(2, difficulty, 0.04))),
    WeightedEffect(2, ActionEffect(Param.trust, -getRandomValue(5, difficulty, 0.06))),
    // WeightedEffect(1, ActionEffect(Param.freeHumans, 1)),
    // WeightedEffect(1, ActionEffect(Param.upgradeSelection, getRandomValue(25, difficulty, 0.33))),
    WeightedEffect(3, ActionEffect(Param.sp, -getRandomValue(1, difficulty, 0.013))),
    WeightedEffect(3, ActionEffect(Param.influence, -getRandomValue(7, difficulty, 0.04))),
    WeightedEffect(
        2, ActionEffect(Param.money, -(getContractMoneyValue(difficulty, totalEffects, isAlignmentContract, trust) * 0.6).round())),
  ];

  List<WeightedEffect> capabilityEffectPool = [
    WeightedEffect(1, ActionEffect(Param.alignmentAcceptance, -getRandomValue(2, difficulty, 0.04))),
    WeightedEffect(4, ActionEffect(Param.trust, -getRandomValue(5, difficulty, 0.08))),
    // WeightedEffect(1, ActionEffect(Param.freeHumans, 1)),
    // WeightedEffect(1, ActionEffect(Param.upgradeSelection, getRandomValue(25, difficulty, 0.33))),
    WeightedEffect(2, ActionEffect(Param.sp, -getRandomValue(1, difficulty, 0.01))),
    WeightedEffect(3, ActionEffect(Param.influence, -getRandomValue(8, difficulty, 0.05))),
    WeightedEffect(
        4, ActionEffect(Param.money, -(getContractMoneyValue(difficulty, totalEffects, isAlignmentContract, trust) * 0.7).round())),
  ];

  final effectPool = isAlignmentContract ? alignmentEffectPool : capabilityEffectPool;

  return getEffectsFromPool(totalEffects, effectPool);
}

getEffectsFromPool(int totalEffects, List<WeightedEffect> effectPool) {
  return pickListOfWeighted(totalEffects, effectPool).map((e) => e.effect).toList();
}

ActionEffect applyContractModifiers(GameState gs, ActionEffect effect, [bool isForFailure = false]) {
  // Only multiplier modifiers are enabled for penalty generation
  final newValue = applyParamModifiers(
      effect, isForFailure ? {} : gs.contractAddModifiers, gs.contractMultModifiers, isForFailure ? {} : gs.contractFunctionModifiers);

  return ActionEffect(effect.paramEffected, newValue);
}
