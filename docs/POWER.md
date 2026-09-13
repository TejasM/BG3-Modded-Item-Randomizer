# Experimental power-aware distribution

This fork adds an equipment power gate to MIR's existing world-loot selection.
It does not add merchant stock, equip NPCs, remove original mod placements, or
guarantee that every installed item will appear. MIR's exclusions, category
weights, declared-rarity window, container rules and spawn ledger still apply.

The fork retains MIR's module identity and save ledger. Use it as a replacement
for upstream MIR, not as a second mod loaded alongside it. This branch has not
been tested inside BG3 and is not a packaged release.

## Controls

The new **Power** MCM tab enables the gate (on by default) and optionally excludes
equipment with detected unknown effects (off by default). Disabling the power
gate restores upstream selection behavior. Settings apply on the next roll.

`!mir_power <stat name or template UUID>` prints the catalog entry's score,
reasons, unknown effects, minimum level and Act. Browser shares remain estimates
before progression filtering, as they already are for the rarity window.

## Assessment

`Server/Power.lua` evaluates recognized equipment boost calls and traverses
passive and granted-spell references with cycle/depth limits. It resolves
inherited attributes without summing overridden parent values. Assessments are
computed when the catalog is built, not on every loot roll.

Initial weights are engineering heuristics, **not calibrated balance claims**:

| Feature | Points |
| --- | ---: |
| Weapon enchantment, AC boost, spell attack/DC boost | 3 per point |
| Ability increase | 2 per point |
| Flat/dice damage bonus | 1.5 per average damage |
| Resistance | 5 per call |
| Extra action or bonus action | 18 per point |
| Granted spell | 2 + twice spell level; also flagged for review |

Declared rarity supplies a minimum score of 0/3/7/12/18. Unrecognized boost
expressions, unresolved references, and detected conditional or scripted
functor fields trigger low confidence and a minimum score of 12.

| Score | Minimum host level | Minimum Act |
| --- | ---: | ---: |
| Below 3 | 1 | 1 |
| 3 to below 7 | 3 | 1 |
| 7 to below 12 | 5 | 1 |
| 12 to below 18 | 8 | 2 |
| 18 or more | 10 | 3 |

Both requirements must be satisfied. Missing level/Act data holds equipment
back. Consumables and cosmetic categories are exempt. Empty eligible pools do
not fall back to powerful items. The gate applies to category selection, rarity
selection and the final item pick.

For source-level compatibility overrides, edit `powerOverrides` in
`Server/Config.lua`, then restart/rebuild the catalog:

```lua
powerOverrides = {
    ["item-template-uuid"] = { minLevel = 6, minAct = 2 },
    ["Problematic_Stat_Name"] = { exclude = true },
},
```

Template overrides take precedence over stat overrides. Overrides do not bypass
MIR exclusions or the strict-unknown option. Disabling the power system disables
its overrides too. These overrides are source configuration, not MCM storage.

## Limits and next development steps

Base weapon damage and base armor class are not normalized against weapon/armor
families yet. Status chains, recharge rules, conditional uptime, set bonuses and
arbitrary Lua effects are not fully evaluated. Invisible scripted behavior may
remain undetected: a lack of unknown flags is not proof of complete analysis.
No runtime code from other mods is evaluated by this classifier.

Next: export assessments from a real load order, compare vanilla progression
anchors, add stat-family baselines and status/recharge analysis, then tune the
weights. Merchant/boss reward placement is separate future work.

## Development and verification

`tests/` contains Python-driven Lua 5.4 unit tests and a test of the production
loot selector with mocked game APIs. Install the test dependency and run:

```powershell
python -m pip install lupa==2.8
python -m unittest discover -s tests -v
```

The tests cover inheritance, reference cycles, unknown effects, manual overrides,
progression gates, final selection, Lua syntax and MCM setting IDs. They do not
validate BG3's runtime API behavior or game balance.

To package with a separately installed LSLib Divine executable, run from the
repository root (choose an output directory that exists):

```powershell
& 'C:\path\to\Divine.exe' -a create-package -g bg3 -s .\src -d .\MIR.pak
```

The inherited `scripts/build_mir.ps1` uses its author's machine paths and also
installs into the game; it is not the portable build entry point for this fork.

Before a release, verify MCM toggles, several real stat dumps, level/Act changes,
save/reload ledger behavior, scoped containers and the strict-unknown option in
BG3. No game installation was changed during this implementation.
