# Verification record

Windows · Godot 4.7.2 Standard · project source and bundled Python reference

| Check | Observed result |
|---|---|
| Python unit suite | All 15 tests passed. Cases cover sensor updates, boundary inputs, both decisions, low supplies, blocked paths, weighted costs and reachability between every pair of different ports. |
| Controlled route comparison | Haven to Coral Bazaar remains at cost 10.00 after the alert in the example. Ember Cove to Whisper Cay changes route as both risks rise from 0.05 to 0.95. Cost rises from 11.08 to 22.85. |
| Godot gameplay logic | A seeded driver loaded the main scene, accepted all five contracts, scanned, invoked advice, sailed both legs, collected each relic, received payment and reached the ending. It also bought an engine upgrade and reloaded the career after contract one. |
| Scope of engine check | The driver follows the actual A* waypoints using automated steering and the game's movement and collision loop. It invokes the interaction handlers directly. Keyboard feel, visual layout, music playback and presentation timing require a human playthrough. |
| Environment diagnostics | The headless Windows run reported a system certificate-store error and audio playback resources still referenced during shutdown. The career checks reached completion. |

## Reproduction

```shell
python ai_reference.py
python -m unittest discover -s tests -v
```

For the engine check, open PowerShell at the project root. Replace the path with your extracted console executable.

```powershell
.\tests\run_career_test.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

The runner imports resources first and creates an isolated temporary Windows application-data directory for the test save. The final test line should say `Completed contracts: 5/5. Failed checks: 0`.
