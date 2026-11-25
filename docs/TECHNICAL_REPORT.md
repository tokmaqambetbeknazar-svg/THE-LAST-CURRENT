# THE LAST CURRENT — Technical report

**Course:** AI Fundamentals, QAIRU  
**Student authors:** Mustafin Arlan / Tokmagambet Beknazar  
**Project version:** Godot 4 3D career prototype v0.1

## 1. Problem statement

How can an autonomous maritime navigator estimate hazard probability from noisy sensor readings, choose a low-expected-cost route through obstacles, and select an action under uncertainty? The pirate career game is a fictional, simplified simulation of real-world **risk-aware routing and sequential decision support**.

## 2. Formal model and explicit assumptions

- A 19×19 abstract navigation grid underneath an original procedural 3D archipelago.
- Each normal move has cost at least 1; reefs and islands are impassable.
- Storm-front cells incur risk-weighted extra cost. Two hazard sites are modelled.
- The binary lookout has assumed sensitivity 0.84 and false-positive rate 0.17.
- Each storm has a prior of 0.30 in a new voyage; new observations update beliefs.
- One-step, two-state MDP uses `Calm`, `Dangerous`, actions `Sail`, `Anchor` and reward table shown below. These are toy numerical values, **not real maritime safety recommendations**.

## 3. A* search

Inputs: start position, goal port, blocked cells, cell travel costs.  
Heuristic: Manhattan distance (admissible for 4-neighbor moves and step costs ≥1).  
Compute `f(n)=g(n)+h(n)` and expand the node of lowest f; update cheaper neighbor paths; stop when goal is expanded.  
Outputs: navigable cell path, accumulated weighted cost, number of expanded cells.  
**Why?** It finds a least-cost route in the grid model, not merely a minimum-step path.

## 4. Bayes

Inputs: prior danger probability, observed binary sensor signal, sensitivity, false-positive rate.  
Posterior:

`P(D|A) = P(A|D)*P(D) / [P(A|D)*P(D) + P(A|¬D)*(1-P(D))]`.

For prior 0.30 and alert:

`P(D|A)=0.84*0.30/(0.84*0.30+0.17*0.70)=0.252/0.371≈0.6792`.

After `CLEAR`: `(0.16*0.30)/((0.16*0.30)+(0.83*0.70))=0.048/0.629≈0.0763`.

Outputs: posterior risk, numerator and denominator for display.  
**Why?** Sensors may be incorrect; combine prior information and evidence rather than blindly trusting the reading.

## 5. One-step MDP

Actions `SAIL` and `ANCHOR`; states `CALM` and `DANGEROUS`.

| State | SAIL reward | ANCHOR reward |
|---|---:|---:|
| Calm | +11 | −3 |
| Dangerous | −23 | −3 |

For either action, the weather persists over the immediate decision. The rows below give the transition probabilities used by both implementations. The weather generator may draw a new state at its next scheduled update.

| Current state | Next calm | Next dangerous |
|---|---:|---:|
| Calm | 1 | 0 |
| Dangerous | 0 | 1 |

The predicted belief is the current belief multiplied by this matrix. The expected immediate rewards are

`EU(SAIL)=(1-p)*11 + p*(-23)`; `EU(ANCHOR)=-3`.

- With clear-signal posterior `p≈0.0763`, `EU(SAIL)≈+8.41`, so **SAIL**.
- With alert posterior `p≈0.6792`, `EU(SAIL)≈−12.09`, so **ANCHOR**.

The player can press `G` to have the navigation adviser perform its recommended `SAIL` or `ANCHOR` behavior. With low supplies, sailing reward in the calm state falls from +11 to +7.

**Limitation:** It is a one-step policy evaluation, permitted by the detailed course guidelines, not an infinite-horizon value-iteration solution.

## 6. Integration

Bayesian posterior changes weights in A*; A* supplies the current risk-aware route; MDP compares immediate sail/anchor actions using the same belief. This forms a single navigation assistant that helps players reach objectives and make decisions. The game visualizes computed routes, risk values, reward comparisons and recommended actions.

## 7. Implementation and UI

- Godot 4 / GDScript, 3D nodes and a procedurally animated water shader.
- Third-person ship camera, 4 island ports, reefs and uncertain storm fronts.
- Five career contracts, gold earnings, upgrades (engine/hull/sonar), persistent save file, in-world salvage bonuses and original synthesized audio.
- AI Laboratory overlay is built into the game; Python reference/test scripts are included to reproduce calculations without the engine.

## 8. Results

All 15 Python reference tests passed, including reachability for all 12 directed pairs of distinct ports. On Haven to Coral Bazaar the prior and alert produce the same 10-step route with cost 10.00. On Ember Cove to Whisper Cay, changing both storm beliefs from 0.05 to 0.95 changes the selected path and increases its optimal cost from 11.08 to 22.85. These are costs under different risk assumptions.

A separate Godot 4.7.2 Windows test exercised the game scene, sailed five contracts using automated steering, collected each relic, returned to port, verified payment and reached the final screen. See [test results](TEST_RESULTS.md) for reproduction and coverage.

## 9. Improvements / realistic limitations

Use real bathymetry and weather data in future versions; expand MDP to transitions, Bellman updates and multi-step planning; simulate tides and current drift; use a 3D navigation mesh or realistic boat physics; design additional quest types; and test on diverse Windows systems.
