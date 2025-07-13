# Alignment is Hard

## Note: Newer version available at https://github.com/mmKALLL/the-final-decade

The Final Decade is the latest evolution of this project. The Alignment is Hard repo is retained only for historical reference.

Alignment is Hard is a high-stakes resource management strategy game about making interesting and meaningful input-random decisions. It addresses a bone I have with mobile strategy games: they tend to be consistently clearable with simple heuristics.

This game on the other hand is designed to hone into the core of what makes strategic decisions interesting: they should affect things without being obvious, be asymmetric to prevent heuristics, input-random to prevent memorization, simple enough to understand at a glance, yet layered enough to make first-order optimization obviously bad.

### How to play

Assign humans to different roles, finish contracts to keep them paid, and try to increase ASI outcome to 100%. That's it!

You can use the spacebar to pause, and keys 1~5 to adjust the game speed.

#### Main resources:

- Money - needed to hire researchers, engineers, and staff. You lose if this runs out.
- RP - Research Points - used to unlock upgrades and influence individual organizations
- EP - Engineering Points - used to fulfill contracts for money and other benefits
- SP - Social Points - used to hire more people and influence alignment acceptance

#### Secondary resources:

- Alignment acceptance - Public view of alignment. Influences what rate of org breakthroughs lead to alignment improvements, or e.g. how likely a new researcher is to join an alignment team vs a capabilities team
- Trust - start at 100, gain or lose depending on how your fund/contract money is handled. If you have high trust you'll get more lucrative contracts
- Influence - affects how effective your social persuasion efforts are

#### Glossary:

- ASI - Artificial Superintelligence. Your goal is to make sure that its discovery results in a positive outcome.
- org - organization. The main "allies and antagonists" of the game, their progress determines the high-level tug of war between alignment and capabilities in the game
- Breakthrough - every x days, organizations can make a "breakthrough", which increases an organization's progress in a research area (in addition to other effects)
- AA - Alignment acceptance, one of the win conditions and a modifier to what percentage of research goes into alignment
- AD - Alignment disposition, an individual modifier for organizations that gets applied on top of AA to determine the outcome of breakthroughs
- ASI outcome - gauge that starts at 50% and shifts whenever a breakthrough is made; if it reaches 0% you lose (due to misaligned ASI), and if 100% you win (due to aligned ASI)

#### Win/loss conditions

- When a superintelligent AI is created, you win if it will be aligned to human needs and values. There are multiple win conditions, and you only need to reach one of them:
  1. Achieve 100% alignment acceptance
  2. Achieve 100% ASI outcome
  3. Finish 50 alignment funding contracts
- You lose if the research to align superintelligent AI becomes hopeless. There are multiple loss conditions:
  1. Have 0% alignment acceptance
  2. Have 0% ASI outcome
  3. Run out of funds and can't take any new contracts
- Each year a new org spawns, with greater funding and more bias towards capabilities research over time (although affected by alignment acceptance)
- Breakthroughs made by organizations cause ASI outcome to increase/decrease by the level of the breakthrough. Similarly level 2+ breakthroughs increase/decrease alignment acceptance by 1.

## Building the game

After installing Flutter, you should be able to simply open the project in VS Code and use the Flutter extension to start a debug session.

Building the game can be done with `flutter build web`.

For uploading to itch.io, you'll need to remove the <base href> tag from the built index.html file (as itch does black magic with the URL resolver and won't handle absolute paths correctly), and zip the entire build folder with index.html in the root.
