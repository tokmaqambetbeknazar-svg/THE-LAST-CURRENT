# The Last Current · Live defense

Suggested speaking roles for two students. Both students should practise every question.

| Time | Speaker | What to show |
|---|---|---|
| 0:00–2:00 | Arlan introduces the scenario, Beknazar explains the objective | Describe the ship, reefs, uncertain weather and the three outputs. |
| 2:00–6:00 | Arlan operates the game, Beknazar explains the numbers | Start a contract. Show the route, scan with Q, open the AI Lab with F and apply advice with G. Collect the relic and return to port with E. |
| 6:00–8:00 | Both students | Explain Bayes, A* and the one-step reward calculation. Use the reproducible Python example to show both sensor outcomes and one route change. |
| Up to 3 more minutes | Each student answers individually | Practise the questions below in either order. |

## Opening in English

**Arlan:** “Imagine that a ship needs to collect cargo and return to port. Reefs block some paths, and the crew has incomplete information about the weather. A false alarm can cause a delay. Ignoring a real storm can damage the ship. We built a small 3D simulation where the captain can see how a navigation assistant uses uncertain information.”

**Beknazar:** “Our goal is to answer three questions. How likely is a storm after a sensor reading? Which route has the lowest cost on our map? Should the ship sail now or anchor? The algorithms share the same estimate of storm risk. We use fictional maps and fixed probabilities so that we can repeat the calculations and check them by hand.”

## During the demo

- **Q:** “This scan may give a false alarm. Watch the risk estimate change after the reading.” Each scan starts from the current belief. Repeated scans may produce different numbers.
- **F:** “The AI Lab shows the inputs, the calculation and the result. A* uses the updated risk when it calculates travel costs near the storm.”
- **G:** “The navigator compares the rewards of sailing and anchoring. Pressing G applies the recommended action for five seconds.”
- **E:** “We have reached the island dock. We collect the relic here, then sail back to Haven Port to receive our reward.”
- If the first route stays the same, explain that its cells are away from the storm. Show the controlled Ember–Whisper example with `python ai_reference.py`.

## Explain the three methods

**Bayesian inference — обновление вероятности.** “We start with a 30% storm risk. A real storm gives an alert 84% of the time. Calm weather gives a false alert 17% of the time. After an alert, the storm probability is 0.252 divided by 0.371, or about 68%.”

**A* — поиск пути.** “The map has four movement directions. We add the cost already paid to an estimate of the distance left. We expand the cell with the lowest sum. Reefs block movement. Cells near a risky storm cost more. Manhattan distance is a safe lower estimate because one move costs at least one.”

**One-step MDP — выбор действия на один шаг.** “There are two weather states and two actions. During one decision we assume the weather stays the same. Sailing earns 11 in calm weather and loses 23 in a storm. Anchoring costs 3 either way. With a 68% risk, sailing has an expected reward of about minus 12. Anchoring is better. With a clear reading the risk is about 8%, so sailing is better.”

## Individual questions

| Question | Short answer |
|---|---|
| Why can an alert be wrong? | A calm front can trigger a false alert. Bayes combines the sensor rates with the prior. |
| Why use A*? | Travel costs differ between cells. A* finds a minimum-cost path using an estimate of the remaining distance. |
| Why can the same path remain optimal after a scan? | A storm may be far from the path, or alternatives may still cost more. |
| What does the transition matrix mean? | Over the immediate decision each state stays the same with probability one. A later weather update can change it. |
| What did the tests cover? | Fifteen Python tests cover the calculations and route logic. A Godot driver sailed five contracts, tested pickup, return and upgrade persistence, and reached the ending. |
| What is a limitation? | The map and sensor values are synthetic, and the decision uses one step. Real deployment would need weather measurements and a longer planning horizon. |
