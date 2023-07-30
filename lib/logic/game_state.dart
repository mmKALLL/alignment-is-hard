import 'dart:math';

import 'package:alignment_is_hard/logic/contract.dart';
import 'package:alignment_is_hard/main.dart';
import 'package:flutter/material.dart' hide Action, Actions;

enum Param {
  currentScreen,
  gameSpeed,
  resetGame,
  money,
  trust,
  alignmentAcceptance,
  influence,
  rp,
  ep,
  sp,
  rpWorkers,
  epWorkers,
  spWorkers,
  freeHumans,
  upgradeSelection,
  contractAccept,
  contractSuccess,
  contractFailure,
  refreshContracts,
  contractClaimed,
}

// Utility used to show human-readable versions of the parameters
paramToLabel(Param param) {
  switch (param) {
    case Param.rp:
      return 'RP';
    default:
      return param.toString().split('.').last;
  }
}

class GameState {
  GameState() {
    contracts = List.generate(2, (index) => getRandomContract(this));
  }
  int currentScreen = Screen.ingame;

  int turn = 1; // Number of days elapsed
  int gameSpeed = 1; // 0 = paused; normally one turn happens each second, but this acts as a multiplier
  int lastSelectedGameSpeed = 1; // Used to restore game speed after pausing

  // 0-100. Public view of alignment. One of the win/loss conditions, influences what rate of org breakthroughs lead to alignment improvements
  int alignmentAcceptance = 15;

  // 0-200. Trust towards your organization. Gain or lose depending on how your fund/contract money is handled. If you have high trust you'll get better contracts and retention
  // TODO: How to inform the player of trust's benefits in a transparent manner?
  int trust = 100;

  // The various turn-based actions have an passive and active component - passive is gained each turn, active when a turn is used to take that action
  int influence = 100;

  double money = debug ? 500000 : 500; // 1 = 1k USD. Needed to hire researchers, engineers, and staff. No loans.
  int passiveMoneyGain = 0;

  // Your human resources. Allocate to tasks to generate points in three general areas: capabilities, alignment, fieldbuilding
  int freeHumans = debug ? 10 : 2; // Each human uses one money / turn.
  double getTeamPerformance() => (30 / (25 + freeHumans)); // Unused. Effectiveness of each person. Having more decreases their efficiency.
  bool canUnassignHumans = false;

  int rp = debug ? 10 : 1; // current research points. Used to improve facets of your AI or unlock upgrades
  int ep = debug ? 10 : 1; // current engineering points. Used to fulfill contracts
  int sp = debug ? 10 : 1; // current staff points. Used to get better contracts/funds, develop the field, or hire more people

  int rpWorkers = 1; // Number of people working on RP
  int epWorkers = 1; // Number of people working on EP
  int spWorkers = 1; // Number of people working on SP
  // int getFreeHumans() => unassignedHumans - rpWorkers - epWorkers - spWorkers;
  int getTotalHumans() => freeHumans + rpWorkers + epWorkers + spWorkers;
  int getTotalWorkers() => rpWorkers + epWorkers + spWorkers;

  // Variables to track gain of RP/EP/SP
  int totalRp = 1;
  int totalEp = 1;
  int totalSp = 1;
  int rpProgress = 0;
  int epProgress = 0;
  int spProgress = 0;
  int progressPerLevel = 100;

  int toNextRP() => progressPerLevel - rpProgress;
  int toNextEP() => progressPerLevel - epProgress;
  int toNextSP() => progressPerLevel - spProgress;

  List<String> recentActions = [];
  List<GameState> recentGS = [];

  List<Upgrade> upgrades = [];
  List<Upgrade>? upgradesToSelect;

  final int contractCycle = 360; // Number of days between contract auto-refreshes
  late List<Contract> contracts;

  Organization playerOrganization = Organization('Meta AI', 0.05, FeatureName.automation);
  List<Organization> organizations = [
    Organization('Meta AI', 0.05, FeatureName.automation),
    Organization('Anthropic', 0.3, FeatureName.boundedness),
    Organization('Noeon', 0.75, FeatureName.interpretability),
    Organization('OpenAI', 0.85, FeatureName.strategy),
  ];

  int alignmentContractsNeededToWin = 50;
  int finishedAlignmentContracts = 0;

  int getYear() => 1 + (turn / 360).floor();
  bool isGameOver() => alignmentAcceptance <= 0 || money <= 0; // TODO: Check if game has been lost due to a superintelligent misaligned AI
  bool isGameWon() =>
      alignmentAcceptance >= 100 ||
      finishedAlignmentContracts >= alignmentContractsNeededToWin; // TODO: Check if game has been won due to a superintelligent aligned AI
}

class Upgrade {}

class Feature {
  Feature(this.name, this.isAlignmentFeature, double alignmentDisposition, bool isMainFocus) {
    maxRandomProgress =
        20 + ((isAlignmentFeature ? alignmentDisposition : (1 - alignmentDisposition)) * 50 + (isMainFocus ? 60 : 0)).round();
    level = (maxRandomProgress / 100).floor();
    progress = Random().nextInt(maxRandomProgress % 100);
    workers = (progress / 2).floor();
    workerDelta = maxRandomProgress / 100;
  }

  final FeatureName name;
  final bool isAlignmentFeature;

  late int level; // Levels range from 0-3
  late int maxRandomProgress;
  late int progress; // 0-100, 100 progress needed to reach the next level.
  late int workers;
  late double workerDelta;
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
  Organization(this.name, this.alignmentDisposition, this.mainFocus) {
    features = createFeatures(alignmentDisposition, mainFocus);
  }

  final String name;
  double alignmentDisposition; // 0-1, how readily the org pursues alignment regardless of current alignmentAcceptance
  int turnsToNextBreakthrough = 10 + Random().nextInt(100);
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
