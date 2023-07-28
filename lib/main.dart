// ignore_for_file: sized_box_for_whitespace

import 'dart:async';

import 'package:alignment_is_hard/components/action_buttons.dart';
import 'package:alignment_is_hard/components/human_allocation.dart';
import 'package:alignment_is_hard/components/top_bar.dart';
import 'package:alignment_is_hard/logic/actions.dart';
import 'package:alignment_is_hard/logic/game_state.dart';
import 'package:alignment_is_hard/components/resource_display.dart';
import 'package:alignment_is_hard/views/contracts_view.dart';
import 'package:flutter/material.dart' hide Action, Actions;
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:flutter/foundation.dart';
// part 'main.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alignment is Hard',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: GameColors.mainColor,
      ),
      home: const MainComponent(title: 'Alignment is Hard'),
    );
  }
}

class MainComponent extends StatefulWidget {
  const MainComponent({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MainComponent> createState() => _MainComponentState();
}

class _MainComponentState extends State<MainComponent> {
  _MainComponentState() {
    gameLoop = Timer.periodic(const Duration(milliseconds: 300), (timer) => {setState(() => reduceTimeStep(gs, 1))});
  }
  GameState gs = GameState();

  // This call to setState tells the Flutter framework that something has
  // changed in this State, which causes it to rerun the build method below
  // so that the display can reflect the updated values. If we changed
  // _counter without calling setState(), then the build method would not be
  // called again, and so nothing would appear to happen.

  void handleAction(Action action) {
    setState(() {
      if (action.effects[0].paramEffected == Param.resetGame) {
        gs = GameState();
        return;
      }
      reduceActionEffects(gs, action.effects);
      // TODO: Do something to handle any events of the action
    });
  }

  late Timer gameLoop;

  @override
  Widget build(BuildContext context) {
    final actions = Actions(gs);

    addReturnButton(List<Widget> mainContent) => Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(children: [
          Container(
            width: 165,
            child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  // add outline border without filling the center
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: Color.fromARGB(140, 0, 0, 0), width: 1.2),
                  ),
                ),
                onPressed: () => handleAction(actions.gotoGameScreen),
                child: Row(children: const [
                  Icon(Icons.arrow_back_sharp, size: 16),
                  SizedBox(width: 4),
                  Text('Return to game'),
                ])),
          ),
          Column(children: mainContent)
        ]));

    // Column is also a layout widget. It takes a list of children and
    // arranges them vertically. By default, it sizes itself to fit its
    // children horizontally, and tries to be as tall as its parent.
    //
    // Invoke "debug painting" (press "p" in the console, choose the
    // "Toggle Debug Paint" action from the Flutter Inspector in Android
    // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
    // to see the wireframe for each widget.
    //
    // Column has various properties to control how it sizes itself and
    // how it positions its children. Here we use mainAxisAlignment to
    // center the children vertically; the main axis here is the vertical
    // axis because Columns are vertical (the cross axis would be
    // horizontal).
    Widget mainWidget = gs.currentScreen == Screen.ingame
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ResourceDisplay(
                gs: gs,
                handleAction: handleAction,
              ),
              const SizedBox(
                height: 8,
              ),
              HumanAllocation(gs: gs, handleAction: handleAction),
              // const SizedBox(
              //   height: 8,
              // ),
              // Text('You are at ${locationToLabel(gs.currentLocation)}. What will you do with your life?'),
              GameScreenActionButtons(gs, handleAction)
            ],
          )
        // Game over and victory screens
        : gs.currentScreen == Screen.gameOver
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text(style: TextStyle(fontSize: 24), 'Game Over!'),
                const SizedBox(height: 64),
                const Text(
                    'Unfortunately, you failed to prevent \na superintelligent AI from taking over. \n\nThere are no retries in real life, \nbut here you can learn and try again. \n\nFinal status:'),
                const SizedBox(height: 32),
                ResourceDisplay(
                  gs: gs,
                ),
                const SizedBox(height: 32),
                ActionButton(
                    gs,
                    handleAction,
                    Action(
                      'Try again!',
                      [ActionEffect(Param.resetGame, 0)],
                    ),
                    Icons.arrow_back_sharp)
              ])
            : gs.currentScreen == Screen.victory
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text(style: TextStyle(fontSize: 24), 'Victory!!!'),
                    const SizedBox(height: 64),
                    const Text(
                        'Congratulations, you managed to endure the desert and \nmake your way toward a brighter future! \n\nFinal status:'),
                    const SizedBox(height: 32),
                    ResourceDisplay(gs: gs),
                    const SizedBox(height: 32),
                    ActionButton(
                        gs,
                        handleAction,
                        Action(
                          'Continue playing!',
                          [ActionEffect(Param.currentScreen, Screen.ingame)],
                        ),
                        Icons.arrow_back_sharp)
                  ])
                : gs.currentScreen == Screen.contracts
                    ? addReturnButton([ContractsView(gs, handleAction)])
                    : gs.currentScreen == Screen.upgrades
                        ? addReturnButton(
                            [ResourceDisplay(gs: gs, handleAction: handleAction), UpgradeScreenActionButtons(gs, handleAction)],
                          )
                        : gs.currentScreen == Screen.humanAllocation
                            ? addReturnButton([
                                ResourceDisplay(
                                  gs: gs,
                                  handleAction: handleAction,
                                ),
                              ])
                            : gs.currentScreen == Screen.upgradeSelection
                                ? addReturnButton([UpgradeScreenActionButtons(gs, handleAction)])
                                : addReturnButton([const Text('Unknown Screen')]);

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: buildTopBar(context, gs),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: mainWidget,
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
