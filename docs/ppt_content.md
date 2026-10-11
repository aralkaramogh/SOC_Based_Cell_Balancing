# PPT content: SOC-Based Passive Cell Balancing for a Li-ion Pack
Mini project · Energy Storage Systems for EV (7EL304) · MATLAB/Simulink R2025b + Simscape Battery

Use one section per slide. **Bullets** go on the slide. **Visual** says which figure to insert (all in the `results/` folder). **Notes** are what to say.

---

## Slide 1: Title
- **SOC-Based Passive Cell Balancing for Li-ion Battery Packs**
- Mini project: Energy Storage Systems for EV (7EL304)
- Team: [names] · Guide: [ma'am's name] · [Date]

**Visual:** none (or a simple 3-cell pack icon)

---

## Slide 2: Why cells need balancing
- An EV/BESS pack has many cells **in series**, and the same current flows through every cell
- No two cells are identical: capacity, internal resistance (R0) and self-discharge all differ
- Over time the cells drift apart in **state of charge (SOC)**
- The weakest cell limits the whole pack. It hits **full first** during charging and **empty first** during discharging
- Result: usable capacity is lost and the weak cell ages faster

**Notes:** a series pack is only as good as its weakest cell. Balancing keeps the cells at the same SOC so the pack can use its full capacity.

---

## Slide 3: Passive vs. active balancing
| | Passive | Active |
|---|---|---|
| How | Burns extra charge in a resistor | Moves charge from full cells to empty cells |
| Parts | Switch + resistor per cell | Converters / inductors / capacitors |
| Efficiency | Energy lost as heat | Higher (energy is reused) |
| Cost / complexity | Low, built into most BMS chips | Higher |
| Speed | Slow (typically tens of mA to ~0.2 A) | Faster |

- Typical passive balancing current is about **1–5 % of cell capacity** (Embedded Computing Design)
- A TI BMS chip balances at **about 65 mA** internally, and **about 96 mA** with an external FET (TI app note SLUAA81)

**Notes:** we chose passive because it is the most widely used method in practice and the simplest to model. Active balancing is future work.

---

## Slide 4: Problem statement: voltage is a poor indicator of SOC
- Most simple balancers decide **from cell voltage**
- Under load, measured voltage = OCV(SOC) − I·R0 − slow RC sag
- So **two cells at the same SOC can show different voltages** (and the reverse)
- **Our result:** the same cell at the **same SOC** reads **3.897 V under a 4 A load** but **4.097 V after 5 min of rest**, a 0.2 V difference
- Voltage-based balancing can therefore bleed the wrong cell, or balance when it isn't needed
- LFP cells make it worse: their OCV curve is flat, so voltage says very little about SOC

**Visual:** `results/step1_voltage_vs_soc.png`

**Notes:** this plot is the motivation for the whole project. SOC is flat during rest, but the voltage jumps by 0.2 V.

---

## Slide 5: Objective
- Build a Simulink model of a **3-cell series Li-ion pack (3S1P, 11.1 V, 2.5 Ah, 27.75 Wh)** with **passive balancing**
- Base the balancing decision on **SOC, not voltage**
- Run the pack through realistic **operating modes**: charge → rest → discharge → rest
- Test it with **identical cells** and with **mismatched cells** (different capacity and R0)
- Measure the **time to balance**, the **energy burned** and the **final SOC spread**

---

## Slide 6: Battery pack specification
| Item | Value |
|---|---|
| Configuration | **3S1P**: 3 cells in series, 1 string |
| Cell | Li-ion 18650 type (NMC/NCA), **3.7 V nominal, 2.5 Ah** |
| **Pack capacity** | **2.5 Ah**. Cells in series add voltage, not Ah. |
| **Pack voltage** | **11.1 V nominal**, range **9.0 V – 12.6 V** (3.0 – 4.2 V per cell) |
| **Pack energy** | 11.1 V × 2.5 Ah = **27.75 Wh** |
| Charge / discharge current | 1.25 A = **0.5C** |
| Bleed resistor | 47 Ω per cell → ~88 mA, ~0.37 W |
| Mismatch case | Cell 2 = 2.3 Ah. The weakest cell sets the pack's usable capacity, so it drops to **2.3 Ah (~25.5 Wh)**, 8 % less. |

**Notes:** in a series pack, the same current flows through every cell, so the pack's Ah equals the *smallest* cell's Ah. This is exactly why one weak cell matters, and why balancing is needed.

---

## Slide 7: Cell model (equivalent circuit)
- Each cell is a **Simscape Battery (Table-Based)** block with a 2.5 Ah Li-ion cell (18650 type)
- OCV(SOC, T) and R0(SOC, T) come from lookup tables
- Equation: **V = OCV(SOC) − I·R0 − V_RC**
- SOC from charge counting: **SOC = SOC₀ − ∫I dt / Q**
- We checked this block against our own hand-written model (next slide)

**Visual:** the circuit drawing (OCV source + R0 + R1‖C1), or `results/model_cell.png`

---

## Slide 8: Building up the cell model step by step (simulations)
- **Step 1:** the cell model written by hand in a MATLAB script (equations + loop)
- **Step 2a:** the same cell in Simulink with basic blocks, **without** the RC branch → average error **0.040 V** compared with the script
- **Step 2b:** the RC branch added (Transfer Fcn R1/(R1·C1·s+1)) → error **0.0001 V**
- **Step 2c:** the same cell with the **Simscape Battery (Table-Based)** block → error **0.0006 V**
- Conclusion: the ready-made Simscape block matches our own equations, so we can trust it for the pack model

**Visuals (2×2 grid):** `results/learn_step2_model_noRC.png`, `results/learn_step2a_noRC_vs_script.png`, `results/learn_step2b_withRC_vs_script.png`, `results/learn_step2c_simscape_vs_script.png`
(also available: `learn_step2_model_withRC.png`, `learn_step2c_simscape_model.png`)

**Notes:** the missing RC branch explains why voltage recovers slowly after a load is removed. Leaving it out gave a 40 mV error.

---

## Slide 9: Development journey (model iterations)
| # | Model | What it added |
|---|---|---|
| 1 | `amogh_try` | First try: one Simscape cell with a source, MOSFET and resistor |
| 2 | `ess_charging_rig` | 3 cells in series + current-controlled charger + current sensor |
| 3 | `ess_charging_rig_cutoff` | + voltage sensors, highest-cell voltage, cut-off relay (stop at 4.20 V) |
| 4 | `ess_balancing_rig` | + bleed switches/resistors + the Passive Cell Balancing block. **41 blocks on one flat sheet, hard to read** |
| 5 | `pack3s_passive_balancing` | Final: the same physics, organised into **subsystems** + operating modes |

**Visuals:** `results/iter1_amogh_try.png`, `results/iter2_ess_charging_rig.png`, `results/iter3_ess_charging_rig_cutoff.png`, `results/iter4_ess_balancing_rig.png` (a row of thumbnails, or one per click)

**Notes:** each iteration added one feature and was tested before moving on. By iteration 4 the model worked but the wiring was hard to follow, which led to the restructuring on the next slide.

---

## Slide 10: Model structure: subsystems for easier viewing
- The flat model (iteration 4) was **reorganised into subsystems**, each with one job:
  - **Cell 1 / 2 / 3:** a masked subsystem holding the battery + bleed switch + bleed resistor + voltage sensor. Each mask shows that cell's SOC₀ and capacity.
  - **Charger:** a controlled current source + current sensor (positive = charge, negative = discharge)
  - **BMS:** the supervisor (modes) + the SOC-based balancing logic
- **Plant (physics) and BMS (control) are separated**, like real hardware vs. firmware
- Signals travel through **Goto/From tags** instead of long crossing wires
- **All numbers are in one file** (`params_pack3s.m`). No values are typed inside blocks.
- Same results, much easier to read, explain and extend

**Visuals:** before/after: `results/iter4_ess_balancing_rig.png` next to `results/model_top.png`. Small insets: `results/model_cell.png`, `results/model_charger.png`, `results/model_bms.png`

---

## Slide 11: Pack and balancing circuit
- 3 cells in series (**pack: 11.1 V nominal, 2.5 Ah, 27.75 Wh**), each with its own **bleed switch + resistor (47 Ω)**
- Bleed current ≈ **88 mA** at 4.15 V, which is about 0.37 W per resistor (inside the industry range above)
- A controlled current source acts as the **charger (+)** or the **load (−)**
- The plant (physics) and the BMS (control logic) are kept separate, as in a real system

**Visual:** `results/model_top.png`

---

## Slide 12: BMS logic: SOC-based balancing rule
- For every cell: **if SOC_k − min(SOC) > 1 % → turn its bleed resistor ON**
- **Turn it OFF** when the gap falls below **0.5 %** (hysteresis, so the switch doesn't chatter)
- Only cells above the lowest one are bled. The lowest cell is the reference.
- Checked every 1 s (BMS sample time)

**Notes:** the hysteresis band stops the switch toggling on tiny differences. That matters because a real SOC estimate is never perfectly accurate.

---

## Slide 13: BMS supervisor: operating modes
| Mode | Pack current | Balancing | Leaves the mode when |
|---|---|---|---|
| CHARGE | +1.25 A (0.5C), stops at 4.20 V, resumes below 4.15 V | ON | 90 min have passed |
| REST | 0 A | ON | 20 min have passed |
| DISCHARGE | −1.25 A (load) | **OFF** | 40 min have passed, or any cell reaches 3.0 V |
| REST | 0 A | ON | 10 min have passed → back to CHARGE |

- Balancing is **blocked during discharge**: bleeding while the pack is being drained would waste energy twice
- It's written as a MATLAB Function block (about 30 lines of `if`/`switch` logic)

**Visual:** `results/model_bms.png`

---

## Slide 14: Result 1: identical cells
- Start: SOC = 0.80 / 0.75 / 0.75 (5 % spread)
- The spread drops **below 1 % after 68 min**, during charging
- Only **Cell 1** (the highest) bleeds, for 76.6 min in total
- Energy burned: **1680 J (0.47 Wh)**
- End of cycle: 0.979 / 0.974 / 0.974. **Spread 0.5 %**, the hysteresis OFF threshold.

**Visual:** `results/balancing_equal_*.png` (latest file)

---

## Slide 15: Result 2: mismatched cells (realistic case)
- Cell 2 has **2.3 Ah** (8 % less capacity) and Cell 3 has **1.5× R0**
- During **discharge** the smaller cell empties faster, and the spread **grows from 0.5 % to 2.8 %**. Balancing is off during discharge, so this is the drift that real use causes.
- In the following **rest and charge**, balancing brings it back to **0.5 %**
- All three cells needed bleeding at some point: 100 / 40 / 20 min
- Energy burned: **3374 J (0.94 Wh)**, double the identical-cell case. That's about **3.4 %** of the pack's 27.75 Wh per cycle.

**Visual:** `results/balancing_mismatch_*.png` (latest file)

**Notes:** this shows why balancing must keep running. Imbalance comes back every cycle when the cells are different. It also shows the cost of passive balancing, because the energy turns into heat.

---

## Slide 16: Key observations
- SOC-based passive balancing **brings the cells back together** within a single charge/rest period
- **Capacity mismatch causes a new imbalance every discharge**, so balancing is a continuous job
- Passive balancing is **slow and wasteful**: about 1 Wh lost per cycle in this small pack, and it grows with the mismatch
- Running balancing through **modes** (on in charge/rest, off in discharge) avoids wasting energy twice
- Terminal voltage alone **can't be trusted** under load (0.2 V error at the same SOC)

---

## Slide 17: Limitations and future work
- The BMS uses the **true SOC** from the model. A real BMS has to **estimate** it, first with Coulomb counting and then with an **Extended Kalman Filter (EKF)**
- **Voltage-triggered balancing** as a direct head-to-head comparison (same pack, same scenarios)
- **CC-CV charging** instead of a hard cut-off
- Thermal model of the bleed resistors
- **Active balancing** (bidirectional buck-boost + PI) to recover the wasted energy
- Scale up to a larger pack (e.g. 12S/16S)

---

## Slide 18: Syllabus mapping
- **CO2:** battery system operation (charging/discharging modes, cut-off limits)
- **CO3:** BMS components and working (cell balancing, protection, supervisor logic)
- **Module II:** battery parameters (SOC, OCV, internal resistance, capacity)
- **Module III:** BMS and cell equalization
- **Module IV:** converter topologies (active balancing, future work)

---

## Slide 19: References
1. Texas Instruments, *Cell Balancing With BQ769x2 Battery Monitors*, Application Note SLUAA81. https://www.ti.com/lit/pdf/sluaa81
2. *Cell Balancing Paradigms: Advanced Types, Algorithms, and Optimization Frameworks*, arXiv:2411.05478. https://arxiv.org/html/2411.05478v1
3. *A Deeper Look into Active Balancing on BMS, Part 1*, Embedded Computing Design. https://embeddedcomputing.com/technology/analog-and-power/batteries-power-supplies/a-deeper-look-into-active-balancing-on-bms-part-1
4. *State-of-charge estimation for onboard LiFePO4 batteries with adaptive state update in specific OCV ranges*, Applied Energy (2023). https://www.sciencedirect.com/science/article/abs/pii/S0306261923009455
5. MathWorks, Simscape Battery documentation: Battery (Table-Based), Passive Cell Balancing blocks

---

## Slide 20: Thank you / Q&A
**Likely questions, with short answers:**
- *Why passive and not active?* It's simple, cheap and the most widely used. Active balancing is future work.
- *Why does balancing stop during discharge?* Bleeding while the pack is being drained wastes energy twice and shortens run time.
- *Where does SOC come from?* In this model, from the simulation (true SOC). Next step: estimating it with Coulomb counting and an EKF.
- *What is the pack capacity?* 2.5 Ah at 11.1 V (27.75 Wh). Series cells add voltage, not Ah. With a 2.3 Ah weak cell, the usable capacity drops to 2.3 Ah.
- *Why subsystems?* The flat model had 41 blocks with crossing wires. Subsystems separate the plant from the BMS and make it readable and reusable.
- *Why 47 Ω?* It gives about 88 mA, which is inside the typical 1–5 % of capacity range.
- *Why the hysteresis?* It stops the switch toggling on tiny SOC differences and sensor noise.

---

## Figure index (all files in `results/`)
| File | Shows | Slide |
|---|---|---|
| step1_voltage_vs_soc.png | Same SOC, different voltage under load vs. rest | 4 |
| learn_step2_model_noRC.png / learn_step2_model_withRC.png | Simulink cell model, without/with RC branch | 8 |
| learn_step2a_noRC_vs_script.png | Simulink (no RC) vs. script, 40 mV error | 8 |
| learn_step2b_withRC_vs_script.png | Simulink (with RC) vs. script, matches | 8 |
| learn_step2c_simscape_model.png / learn_step2c_simscape_vs_script.png | Simscape Battery cell vs. script | 8 |
| iter1_amogh_try.png … iter4_ess_balancing_rig.png | Model iterations 1–4 | 9, 10 |
| model_top.png | Final model, top level (subsystems) | 10, 11 |
| model_cell.png / model_charger.png / model_bms.png | Inside the Cell, Charger and BMS subsystems | 10, 13 |
| balancing_equal_*.png (newest) | Result 1: identical cells | 14 |
| balancing_mismatch_*.png (newest) | Result 2: mismatched cells | 15 |
