import 'dart:math';

import 'package:alignment_is_hard/components/resource_display.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/logic/upgrade.dart';
import 'package:alignment_is_hard/logic/weighted.dart';
import 'package:alignment_is_hard/main.dart';
import 'package:flutter/material.dart' hide Action, Actions;

enum Param {
  currentScreen,
  gameSpeed,
  resetGame,
  day,
  money,
  trust,
  alignmentAcceptance,
  asiOutcome,
  influence,
  organizationAlignmentDisposition,
  rp,
  ep,
  sp,
  rpWorkers,
  epWorkers,
  spWorkers,
  rpProgress,
  epProgress,
  spProgress,
  freeHumans,
  upgradeSelection,
  contractAccept,
  contractSuccess,
  contractFailure,
  refreshContracts,
  contractClaimed,
}

// Utility used to show human-readable versions of the parameters
paramToLabel(Param param, [bool startWithCapital = false]) {
  switch (param) {
    case Param.rp:
      return 'RP';
    case Param.ep:
      return 'EP';
    case Param.sp:
      return 'SP';
    case Param.rpWorkers:
      return 'RP workers';
    case Param.epWorkers:
      return 'EP workers';
    case Param.spWorkers:
      return 'SP workers';
    case Param.freeHumans:
      return 'free humans';
    case Param.rpProgress:
      return 'RP progress';
    case Param.epProgress:
      return 'EP progress';
    case Param.spProgress:
      return 'SP progress';
    case Param.alignmentAcceptance:
      return 'alignment acceptance';
    case Param.asiOutcome:
      return 'ASI outcome';
    case Param.upgradeSelection:
      return 'upgrade';
    default:
      final name = param.toString().split('.').last; // The stringified name of an enum is "EnumType.valueName"
      return startWithCapital ? capitalize(name) : name;
  }
}

class GameState {
  GameState() {
    contracts = List.generate(2, (index) => getRandomContract(this));
  }
  int currentScreen = Screen.ingame;

  int turn = 1; // Number of days elapsed
  int gameSpeed = debug ? 1 : 0; // 0 = paused; normally one turn happens each second, but this acts as a multiplier
  int lastSelectedGameSpeed = 1; // Used to restore game speed after pausing

  // 0-100. Public view of alignment. One of the win/loss conditions, influences what rate of org breakthroughs lead to alignment improvements. Second-order effect on asiOutcome.
  double alignmentAcceptance = 20;

  // 0-100. Shifted whenever breakthroughs are made, by the level of the feature receiving the breakthrough. 0 = capabilities win; misaligned ASI. 100 = aligned ASI.
  double asiOutcome = 50;

  // 0-200. Trust towards your organization. Gain or lose depending on how your fund/contract money is handled. If you have high trust you'll get better contracts
  double trust = 100;

  // 0-200. Influence is a percentage multiplier to the effect of your social actions (like increasing alignment acceptance)
  double influence = 100;

  // The various turn-based actions have an passive and active component - passive is gained each turn, active when a turn is used to take that action
  double money = debug ? 500000 : 1000; // 1 = 1k USD. Needed to hire researchers, engineers, and staff. No loans.
  double passiveMoneyGain = 0;
  double wagePerHumanPerDay = 1.0;

  // Your human resources. Allocate to tasks to generate points in three general areas: capabilities, alignment, fieldbuilding
  int freeHumans = debug ? 10 : 2; // Each human uses one money / turn.
  double getTeamPerformance() => (30 / (25 + freeHumans)); // Unused. Effectiveness of each person. Having more decreases their efficiency.
  bool canUnassignHumans = false;

  double rp = debug ? 100 : 8; // current research points. Used to improve facets of your AI or unlock upgrades
  double ep = debug ? 100 : 8; // current engineering points. Used to fulfill contracts
  double sp = debug ? 100 : 8; // current social points. Used to get better contracts/funds, develop the field, or hire more people

  int rpWorkers = 1; // Number of people working on RP
  int epWorkers = 1; // Number of people working on EP
  int spWorkers = 1; // Number of people working on SP
  // double getFreeHumans() => unassignedHumans - rpWorkers - epWorkers - spWorkers;
  int getTotalHumans() => freeHumans + rpWorkers + epWorkers + spWorkers;
  int getTotalWorkers() => rpWorkers + epWorkers + spWorkers;

  // Variables to track gain of RP/EP/SP
  double totalRp = 1;
  double totalEp = 1;
  double totalSp = 1;
  double rpProgress = 0;
  double epProgress = 0;
  double spProgress = 0;
  double progressPerLevel = 100;

  double toNextRP() => progressPerLevel - rpProgress;
  double toNextEP() => progressPerLevel - epProgress;
  double toNextSP() => progressPerLevel - spProgress;

  List<String> recentActions = [];
  List<GameState> recentGS = [];

  List<Upgrade> upgrades = staticUpgrades;
  List<Upgrade>? upgradesToSelect;

  int contractCycle = 360; // Number of days between contract auto-refreshes
  int organizationCycle = 360; // Number of days between new organizations appearing
  late List<Contract> contracts;

  // Organization playerOrganization = Organization('Meta AI', -30, FeatureName.automation);
  List<Organization> organizations = [
    Organization('Meta AI', -20, FeatureName.automation, 0),
    Organization('Anthropic', -5, FeatureName.boundedness, 0),
    Organization('Noeon', -20, FeatureName.interpretability, 0),
    Organization('OpenAI', 10, FeatureName.strategy, 0),
    Organization('DeepMind', 0, FeatureName.predictability, 0),
  ];

  // modifiers that affect param gain/loss
  Map<Param, List<CurriedModifier>> addModifiers = {};
  Map<Param, List<CurriedModifier>> multModifiers = {};
  Map<Param, List<CurriedModifier>> functionModifiers = {};

  Map<Param, List<CurriedParamEventHandler>> paramEventHandlers =
      {}; // handlers that can stack more effects when a parameter's value has been changed
  Map<EventId, List<CurriedActionEventHandler>> eventHandlers =
      {}; // handlers that can perform additional reductions when actions are taken

  // mods that affect contract generation
  // FIXME: Make these affect contract gen
  Map<Param, List<CurriedModifier>> contractAddModifiers = {};
  Map<Param, List<CurriedModifier>> contractMultModifiers = {};
  Map<Param, List<CurriedModifier>> contractFunctionModifiers = {};

  // mods that affect organization generation
  // TODO: Make these affect organization gen
  Map<Param, List<CurriedModifier>> organizationAddModifiers = {};
  Map<Param, List<CurriedModifier>> organizationMultModifiers = {};
  Map<Param, List<CurriedModifier>> organizationFunctionModifiers = {};

  int alignmentContractsNeededToWin = 50;
  int finishedAlignmentContracts = 0;

  int getYear() => 1 + (turn / 360).floor();
  bool isGameOver() => asiOutcome <= 0 || alignmentAcceptance <= 0 || money <= 0;
  bool isGameWon() => asiOutcome >= 100 || alignmentAcceptance >= 100 || finishedAlignmentContracts >= alignmentContractsNeededToWin;
}

class Feature extends Weighted {
  Feature(this.name, this.isAlignmentFeature, double alignmentDisposition, bool isMainFocus) {
    value = level = Random().nextInt(2) + (isMainFocus ? 1 : 0); // 1-2 for main focus, 0-1 for others
    weight = (isMainFocus ? 3 : 1) + Random().nextInt(isMainFocus ? 2 : 3); // 1-5, chance to pick within the same type of features
  }

  final FeatureName name;
  final bool isAlignmentFeature;

  late double level; // Levels range from 0-5
}

/*
  world model (can model how the world works),
  goal creation (can formulate goals and steps),
  strategic agency (can take actions in the real world),
  self replication (can resist being shut down), => combination of others
  deception (can hide its capabilities),
  power seeking behavior (can try to kill all humans), => combination of others
  automated research (can improve itself to superhuman levels in x turns),
*/
enum FeatureName { agency, strategy, deception, automation, interpretability, boundedness, predictability, alignment }

bool isAlignmentFeature(FeatureName featureName) {
  return [FeatureName.interpretability, FeatureName.boundedness, FeatureName.predictability, FeatureName.alignment].contains(featureName);
}

String getShortFeatureName(FeatureName name) {
  switch (name) {
    case FeatureName.agency:
      return 'agen.';
    case FeatureName.strategy:
      return 'strat.';
    case FeatureName.deception:
      return 'dcep.';
    case FeatureName.automation:
      return 'auto.';
    case FeatureName.interpretability:
      return 'intrp.';
    case FeatureName.boundedness:
      return 'bndn.';
    case FeatureName.predictability:
      return 'pred.';
    case FeatureName.alignment:
      return 'align.';
  }
}

const int featureMaxLevel = 5;

List<Feature> createFeatures(double alignmentDisposition, FeatureName mainFocus) {
  Feature createFeature(FeatureName name, bool isAlignmentFeature) {
    return Feature(name, isAlignmentFeature, alignmentDisposition, name == mainFocus);
  }

  List<Feature> features = [];
  for (var i = 0; i < FeatureName.values.length; i++) {
    features.add(createFeature(FeatureName.values[i], i >= 4));
  }

  return features;
}

class Organization {
  Organization(this.name, this.alignmentDisposition, this.mainFocus, int currentYear) {
    features = createFeatures(alignmentDisposition, mainFocus);
    breakthroughInterval = 80 + Random().nextInt((50 + 1000 / (currentYear + 5)).round());
    alignmentDisposition += isAlignmentFeature(mainFocus) ? 15 : -15;
  }

  final String name;
  double alignmentDisposition; // -50 to +50, added to alignmentAcceptance when determining how likely the org is to make breakthroughs
  late int breakthroughInterval;
  int turnsSinceLastBreakthrough = 0;
  bool active = true; // Organizations become inactive once all their features in one category are maxed out
  FeatureName mainFocus;
  late List<Feature> features;
}

class GameColors {
  static const happinessColor = Color(0xFFFFD95C);
  static const energyColor = Color(0xFFC1CEFE);
  static const healthColor = Color(0xFFE1786E);
  static const communityColor = Color(0xFFB6CDB9);
  static const mainColor = Colors.blue;
  static const actionButtonColor = Color(0xFF008542);
  static const actionButtonIconColor = Color(0xFFFFFFFF);
  static const disabledColor = Color(0x8F8F8F8F);
}

class Screen {
  static int mainMenu = 0; // unused
  static int gameOver = 1;
  static int victory = 2;
  static int introduction = 4; // unused
  static int ingame = 5;
  static int upgrades = 6;
  static int upgradeSelection = 7;
  static int humanAllocation = 8; // unused
  static int contracts = 9;
}
