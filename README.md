# SOC-Based Cell Balancing (ESS / EV)

Simulation study of passive, SOC-based cell balancing for a Li-ion pack.
MATLAB / Simulink R2025b with Simscape, Simscape Electrical and Simscape Battery.

## How to start

1. Open `SOC_Based_Cell_Balancing.prj`. This sets the MATLAB path and puts all
   Simulink cache files in `work/`.
2. Run `scripts/run_pack3s_balancing.m`. It simulates the 3-cell pack and saves
   a results figure to `results/`.
3. To change a number (capacity, start SOCs, bleed resistor, cut-off voltage...),
   edit `scripts/params_pack3s.m`. Never type numbers into block dialogs.
4. Only if you change the model's STRUCTURE, edit and run
   `scripts/build_pack3s_passive_balancing.m`. It rebuilds the model from scratch.

## Folder layout

| Folder      | What is in it |
|-------------|---------------|
| `models/`   | Current model: `pack3s_passive_balancing.slx` |
| `scripts/`  | `params_pack3s.m` (all numbers), `build_...m` (creates the model), `run_...m` (simulate + plot) |
| `learning/` | Step-by-step learning files: step 1 (cell in a MATLAB script), step 2 (same cell in Simulink), step 2b (same cell in Simscape) |
| `archive/`  | Earlier experiments, kept for reference only (not on the path) |
| `results/`  | Figures written by the run script, model screenshots |
| `docs/`     | `ppt_content.md`: slide-by-slide content for the presentation |
| `work/`     | Simulink cache and generated files. Safe to delete. |
| `resources/`| MATLAB project internals. Do not edit. |

## Current model: `pack3s_passive_balancing.slx`

```
 PLANT (physics)
   Charger --(+)--> Cell 1 --> Cell 2 --> Cell 3 --(-)--> Charger      (series string)
     ^ I_cmd          | SOC_1,V_1  | SOC_2,V_2  | SOC_3,V_3
     |                ^ Bleed_1    ^ Bleed_2    ^ Bleed_3
 BMS (control logic)
   SOC[3], V[3]  ->  [ hard cut-off relay ]       -> I_cmd
                     [ Passive Cell Balancing ]   -> Bleed[3]
```

- **Cell k** (masked subsystem): Battery (Table-Based) with its own bleed
  switch + bleed resistor, and a voltage sensor. Input: BleedCmd. Outputs: SOC and V.
- **Charger**: constant-current source that follows `I_cmd`, plus a current sensor.
- **BMS**: plain Simulink logic plus a **Supervisor** (MATLAB Function block, added by `scripts/add_supervisor.m`).
  - Modes (timed cycle): CHARGE 90 min -> REST 20 min -> DISCHARGE 40 min (or until a cell hits `V_min`) -> REST 10 min -> CHARGE ...
  - Balancing is enabled in CHARGE and REST, blocked in DISCHARGE.
  - Cut-off: charging stops when the highest cell reaches `V_cutoff` (4.20 V) and
    restarts when all cells are below `V_resume` (4.15 V).
  - Balancing: a cell's bleed resistor turns on when its SOC is more than
    `Bal_threshold` (1 %) above the lowest cell, and turns off at `Bal_hyst` (0.5 %).
    Its Enable input is always on for now. A supervisor will drive it later.
- Signals between the plant and the BMS use Goto/From tags. A tag with the same
  name is the same wire.

## Baseline result (default parameters)

Starting SOC 0.80 / 0.75 / 0.75, with a 47 Ω bleed resistor (about 88 mA) and
1.25 A of charge current:

- the SOC spread drops below 1 % after about 68 minutes,
- the pack ends at 0.978 / 0.973 / 0.973,
- only Cell 1 bleeds (76.6 minutes in total).

## Next steps

- [x] BMS supervisor (modes: charge / rest / discharge / rest) that drives the balancing Enable input
- [x] Per-cell capacity and R0 (`Cap`, `R0_scale` in the params file)
- [ ] CC-CV charging instead of the hard cut-off
- [ ] Dashboard gauges for live SOC
- [ ] Bleed-resistor power / thermal check
- [ ] Compare against an SOC-based vs voltage-based balancing trigger
