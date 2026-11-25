# The Last Current — Legends of the Sea

QAIRU · AI Fundamentals · Mustafin Arlan and Tokmagambet Beknazar

A 3D maritime navigation game built with Godot 4. A captain recovers relics from island ports while a lookout supplies imperfect storm readings. The navigation assistant estimates the risk, plots a route around reefs and advises whether to sail or anchor. Maps, sensor rates and rewards are synthetic.

## Run the game on Windows

1. Extract the whole project into one folder.
2. Open Godot 4 Standard (verified with 4.7.2), choose **Import** and select `project.godot`.
3. Let the audio and icon finish importing. Press **F5**, select **Start New Career**, then **Accept the Next Contract**. Starting a new career replaces the local career save.
4. Follow the golden markers to the island dock. Press **E** to pick up the relic, sail back to Haven Port and press **E** again. The port offers ship upgrades between contracts.

| Keys | Action |
|---|---|
| W / S, A / D or arrows | Accelerate / reverse, steer left / right |
| Q, F | Scan the storm front, open or close AI Lab |
| G, Space | Apply the recommended action, or hold Space to anchor |
| T, R | Toggle route markers, recalculate the route |
| E, Esc, M | Interact at the dock, pause, toggle music |

## Reproduce the AI calculations

From the project root, run the following with Python 3.8 or later. The Python reference uses the standard library.

```shell
python ai_reference.py
python -m unittest discover -s tests -v
```

| Input | Calculation or observation | Output |
|---|---|---|
| Prior 0.30, ALERT, sensitivity 0.84, false alarm rate 0.17 | 0.252 / (0.252 + 0.119) | Storm probability 67.92% |
| Same prior, CLEAR | 0.048 / (0.048 + 0.581) | Storm probability 7.63% |
| Normal supplies, alert posterior | Sailing earns about −12.09 in expectation, anchoring earns −3 | ANCHOR |
| Normal supplies, clear posterior | Sailing earns about +8.41 in expectation, anchoring earns −3 | SAIL |
| Ember Cove to Whisper Cay, both risks 0.05 then 0.95 | A* minimizes the sum of risk-weighted cell costs | Route changes, costs 11.08 and 22.85 |

AI Lab shows the current voyage's data. The Python example fixes the sensor outcomes so both branches can be reproduced on demand. The game draws observations at random.

## Repository contents

| Path | Purpose |
|---|---|
| `scenes/Main.tscn`, `scripts/`, `assets/` | Godot scene, gameplay, AI implementation, procedural world and sound |
| `ai_reference.py`, `tests/` | Reproducible calculations, 15 unit tests and a Godot career test |
| [Technical report](docs/TECHNICAL_REPORT.md) | Problem, assumptions, algorithm steps, results and limitations |
| [Test results](docs/TEST_RESULTS.md) | Commands, observed outcomes and test boundaries |
| [Defense notes](docs/DEFENSE_PREP_RU_EN.md) | Timed live demonstration and individual practice questions |
| [AI usage](docs/AI_USAGE_DECLARATION.md) and [team contributions](docs/TEAM_CONTRIBUTION.md) | Development disclosures |

See [the Russian quick start](START_HERE_RU.txt) for the local demo setup.
