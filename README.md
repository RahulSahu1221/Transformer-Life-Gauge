<div align="center">

# ⚡ Transformer Life Gauge

### *Turning a Transformer's Thermal Behavior Into a Live "Battery Percentage" for Its Remaining Insulation Life*

A concept + prototype-stage IoT project that estimates a power transformer's **real-time remaining insulation life** using the industry-standard **IEEE C57.91 thermal aging model** — combining live sensor data (load current, oil temperature, ambient temperature) with an ESP32 + MQTT + cloud dashboard pipeline.

Built as a bridge between **electrical transformer design fundamentals** and **practical, low-cost IoT engineering**.

<br>

![Status](https://img.shields.io/badge/Status-Concept%20%2F%20Design%20Stage-orange)
![Model](https://img.shields.io/badge/Model-IEEE%20C57.91-1c3d5a)
![Hardware](https://img.shields.io/badge/Hardware-ESP32-e74c3c)
![Protocol](https://img.shields.io/badge/Protocol-MQTT-660066)
![Dashboard](https://img.shields.io/badge/Dashboard-ThingsBoard-2e86de)
![Domain](https://img.shields.io/badge/Domain-Power%20Transformers-2c3e50)
![Type](https://img.shields.io/badge/Type-IoT%20%2B%20Electrical%20Engineering-16a085)
![License](https://img.shields.io/badge/License-MIT-brightgreen)

<br>

---

### ⭐ If you find this concept useful, consider giving the repo a star!

---

</div>

## 📌 Table of Contents

- [Overview](#-overview)
- [The Problem](#-the-problem)
- [Transformer Types: Where This Project Fits](#-transformer-types-where-this-project-fits)
- [Why This Works — The Physics](#-why-this-works--the-physics)
- [Temperature & Loading Reference Data](#-temperature--loading-reference-data)
- [The Math Model](#-the-math-model)
- [System Architecture](#-system-architecture)
- [Parameters Monitored](#-parameters-monitored)
- [Bill of Materials (Prototype)](#-bill-of-materials-prototype)
- [Wiring Diagram](#-wiring-diagram)
- [Software Stack](#-software-stack)
- [Firmware Logic (Pseudocode)](#-firmware-logic-pseudocode)
- [Dashboard (ThingsBoard)](#-dashboard-thingsboard)
- [Alarm Conditions](#-alarm-conditions)
- [Bonus Feature: Dynamic Loading Advisor](#-bonus-feature-dynamic-loading-advisor)
- [Applications](#-applications)
- [What Already Exists (Prior Art)](#-what-already-exists-prior-art)
- [Roadmap](#-roadmap)
- [Limitations & Honest Caveats](#-limitations--honest-caveats)
- [Learning Outcomes](#-learning-outcomes)
- [References](#-references)
- [License](#-license)

---


## 🔎 Overview

Power transformers rarely fail from "old age" directly — they fail because the **paper insulation** wrapped around the windings chemically degrades over time, and heat is the single biggest accelerant of that degradation. Today, most transformers are maintained on a **fixed schedule** (periodic manual inspection) rather than based on their **actual real-time thermal history**.

**Transformer Life Gauge** is a low-cost IoT retrofit concept that:
1. Continuously measures load current and temperature.
2. Feeds them into the industry-standard IEEE C57.91 thermal aging model.
3. Displays the transformer's **remaining insulation life as a live percentage** — like a phone battery indicator.
4. (Bonus) Advises how much safe overload capacity is available at any given moment.

This is **not a new algorithm** — the underlying thermal aging math is a well-established IEEE standard already used in expensive fiber-optic monitoring systems on large, critical, high-voltage transformers. The goal of this project is to make the **same proven model** accessible on **mid-size and smaller transformers** using cheap, off-the-shelf IoT hardware (ESP32 + MQTT + cloud dashboard) instead of specialized fiber-optic sensor systems.

---

## ❗ The Problem

- Most transformers (especially distribution and mid-size industrial units, roughly 25 kVA – 100 MVA) are **not** continuously monitored for insulation health.
- Maintenance is typically **time-based**, not **condition-based** — inspections happen on a calendar, regardless of how hard the transformer has actually been run.
- By the time visible symptoms appear (oil discoloration, unusual noise, tripping), significant insulation life may already be lost.
- Continuous thermal/aging monitoring already exists — but almost exclusively on large (100+ MVA), critical, high-voltage (132 kV+) transformers, using **expensive fiber-optic hot-spot sensors**. This technology doesn't scale economically to the much larger population of smaller transformers.

---

## 🏭 Transformer Types: Where This Project Fits

Not all transformers are the same — the term covers a wide range of equipment, and it matters which category this project targets.

| Aspect | Distribution Transformer | Power Transformer |
|---|---|---|
| **Where it sits in the grid** | Last stage — steps voltage down for direct use by homes/shops/small industry | Earlier stages — between generation, transmission, and sub-transmission |
| **Voltage range** | ~11kV–33kV down to 400V/230V | ~33kV and up to 400kV+ |
| **Rating** | A few kVA up to ~2,500 kVA | Several MVA up to 500+ MVA |
| **Loading pattern** | Highly variable, peaky (residential demand swings) | Runs closer to steady, planned load |
| **Efficiency design point** | Best efficiency at partial load (~50%) | Best efficiency near full/rated load |
| **Population size** | Huge — thousands per utility | Relatively few — each one a major asset |
| **Typical monitoring today** | Almost never individually monitored | Increasingly monitored on the largest/most critical units |

**This project specifically targets mid-size power transformers** (roughly 5–100 MVA, 33kV–132kV+) — large enough that a failure is genuinely costly and slow to recover from, but not yet large or critical enough to justify today's expensive fiber-optic monitoring systems (which are typically reserved for 100+ MVA, 132kV+ transformers). This range also overlaps directly with the smaller end of typical power transformer product lines (e.g., 66kV distribution-class power transformers), making it a realistic, relevant proposal rather than a residential-scale idea.

---

## 🔬 Why This Works — The Physics

Two temperatures matter, and they are different:

| Temperature | What it is | How it's measured |
|---|---|---|
| **Top-oil temperature** | Bulk oil temperature | Simple thermometer/RTD (easy) |
| **Winding hot-spot temperature** | Hottest point inside the winding | Not directly measurable without expensive fiber-optic sensors — must be *estimated* |

**Key engineering rule of thumb (derived from the IEEE C57.91 model):**
> For every ~6–8°C the winding hot-spot temperature rises above its rated value, the insulation ages roughly **twice as fast**.

This is why continuously tracking (or estimating) hot-spot temperature — instead of checking it once a year — gives a much more accurate picture of real insulation aging.

---

## 🌡 Temperature & Loading Reference Data

### What "ambient temperature" means
Ambient temperature is simply the temperature of the **air surrounding the transformer** — not the oil, not the winding. It's the starting point that heat gets added onto, in a rising chain:

```
Ambient Air  →  Top-Oil Temperature  →  Average Winding Temperature  →  Winding Hot-Spot
   (lowest)                                                                  (highest)
```

The design standard uses **30°C** as the reference ambient temperature for calculations — a standardized assumption, not a real-time value. Real ambient temperature varies with weather, season, and location, which is exactly why an ambient sensor is part of the sensing pipeline.

### Reference temperature zones

| Zone | Hot-Spot Temperature | Meaning |
|---|---|---|
| **Rated / "handles well"** | 110°C (continuous) | Design reference for thermally-upgraded paper — built to run here indefinitely at normal aging speed |
| **Emergency / short-term allowed** | Up to ~140–180°C | Permitted briefly (hours) under emergency loading — burns through insulation life much faster |
| **Absolute danger ceiling** | 200°C hot-spot / 120°C top-oil | IEEE C57.91-2011 hard limits — beyond this, risk of gas-bubble formation and immediate dielectric breakdown, not just faster aging |

### Typical winding temperature under normal working conditions (at 100% rated load)

```
Ambient temperature                         30°C
+ Average winding temperature rise         +65°C   (a "65°C rise" class transformer)
= Average winding temperature               95°C
+ Hot-spot allowance above average         +15°C   (uneven heat distribution in the coil)
= Reference hot-spot temperature           110°C
```

In practice, most transformers run well below 100% load most of the time (see below), so real winding temperatures are commonly in the **60–90°C range** rather than the 110°C reference value.

### Typical real-world loading

| Context | Typical Loading | Notes |
|---|---|---|
| Distribution transformers (peak) | ~50–60% of nameplate rating | ~50% annual load factor is common |
| Residential load factor | ~15–35% | Highly peaky demand (evenings, AC season) |
| General power distribution networks | ~40–70%, most of the time | Networks spend ~99% of time in this band |
| Practical continuous-loading ceiling | ~80% | Above this is typically reserved for short-term/emergency loading |

**Why this matters for this project:** because real transformers usually run well below their rated capacity, they usually age slower than the "20-year" textbook figure — but occasional peak-load events (heatwaves, contingencies, EV charging spikes) can push a transformer into accelerated aging for hours or days at a time, completely invisible to a fixed-schedule inspection regime. This is precisely the pattern the Life Gauge is designed to catch.

---

## 🧮 The Math Model

All formulas below follow **IEEE Std C57.91 (Guide for Loading Mineral-Oil-Immersed Transformers)**.

### Step 1 — Estimate winding hot-spot temperature

```
θ_H = θ_A + Δθ_TO × [ (1 + K²R) / (1 + R) ]^n + Δθ_HS × K^(2m)
```

| Symbol | Meaning | Source |
|---|---|---|
| `θ_A` | Ambient temperature | Measured (sensor) |
| `K` | Load ÷ rated load | Measured (current sensor) |
| `R` | Ratio of load loss to no-load loss at rated load | Transformer design/test data |
| `Δθ_TO` | Rated top-oil temperature rise | Transformer design/test data |
| `Δθ_HS` | Rated hot-spot-to-top-oil gradient | Transformer design/test data |
| `n, m` | Empirical exponents (depend on cooling type: ONAN/ONAF/OFAF) | IEEE C57.91 tables |

> 💡 **Note:** `R`, `Δθ_TO`, and `Δθ_HS` come directly from a transformer's temperature-rise design/test report — exactly the kind of data an electrical design engineer calculates during the design stage. For a prototype, use representative textbook/datasheet values or your own bench-test measurements.

### Step 2 — Convert hot-spot temperature into an aging acceleration factor

```
F_AA = exp[ (15000 / 383) − (15000 / (θ_H + 273)) ]
```

- At the **rated** hot-spot temperature, `F_AA = 1` (normal aging speed).
- Above rated temperature, `F_AA` grows **exponentially** — this is the mathematical source of the "doubles every 6–8°C" rule.
- (Constants shown are for thermally upgraded insulating paper, reference hot-spot 110°C / 383K. Non-upgraded paper uses a 95°C / 368K reference — check IEEE C57.91 Table 1 for the correct constant set for your insulation class.)

### Step 3 — Accumulate life consumed over time

```
Loss of Life (%) = Σ (F_AA,n × Δt_n) / Rated Total Insulation Life × 100
Life Remaining (%) = 100 − Loss of Life (%)
```

Run this calculation every sampling interval (e.g., every 1–5 minutes) and accumulate the result — this is the number shown on the live gauge.

---

## 🏗 System Architecture

```
┌─────────────────────┐     ┌───────────────┐     ┌────────┐     ┌───────────────────┐
│ Temp Sensor (DS18B20)│    │               │     │        │     │                   │
│ Current Sensor (ACS712)├──►│  ESP32 (MCU)  ├────►│  MQTT  ├────►│  ThingsBoard Cloud │
│ Ambient Sensor (DHT22)│    │ Runs the F_AA │     │ Broker │     │  Live Dashboard    │
└─────────────────────┘     │ formula       │     └────────┘     │  + Alerts          │
                             └───────────────┘                    └───────────────────┘
```

- **Sensors** → collect real-time load current and temperature data.
- **ESP32** → runs the hot-spot estimation + aging formula, publishes results via MQTT.
- **MQTT Broker** → lightweight pub/sub messaging (same protocol used in typical Smart Factory IoT setups).
- **ThingsBoard** → cloud dashboard displaying the live "Life Remaining %" gauge, historical trend charts, and threshold-based alerts.

---

## 📈 Parameters Monitored

| Parameter | Sensor (Prototype) | Role in the Model |
|---|---|---|
| Load current | ACS712 | Determines `K` (load ÷ rated load) — main driver of hot-spot temperature |
| Oil temperature | DS18B20 | Simulated top-oil temperature (`θ_TO`) |
| Ambient temperature | DHT22 | Baseline temperature (`θ_A`) in the hot-spot formula |
| Calculated hot-spot temperature | Derived (not directly sensed) | Drives the aging acceleration factor `F_AA` |
| Calculated aging rate (`F_AA`) | Derived | Determines how fast insulation life is being consumed right now |
| Cumulative life consumed | Derived | Feeds the live "Life Remaining %" gauge |

> On a real transformer, oil temperature and load current would come from industrial-grade RTD probes and CT clamps instead of the prototype sensors above — the model and calculations stay identical.

---

## 🧰 Bill of Materials (Prototype)

For a **bench-top demo** (simulating transformer heat with a small load, not an actual power transformer):

| Component | Purpose | Approx. Price (₹) |
|---|---|---|
| ESP32 Dev Board | Microcontroller — runs formula, sends data over WiFi | 250–350 |
| DS18B20 waterproof temp sensor | Simulated "oil temperature" | 80–150 |
| ACS712 (20A) current sensor module | Simulated "load current" | 100–150 |
| DHT22 (optional) | Ambient temperature/humidity | 150–200 |
| Small heating element / bulb + dimmer | Stand-in for transformer heat source | 150–300 |
| Breadboard + jumper wires | Prototyping | 150–200 |
| USB cable + power supply | Powering ESP32 | 100–150 |
| Enclosure box (optional) | Housing / demo polish | 150–300 |
| Misc (resistors, wires, solder) | — | 100–150 |
| **Total** | | **≈ ₹1,200 – ₹2,000** |

**Software/cloud cost:** ₹0 (ThingsBoard Community Edition, public/self-hosted MQTT broker, Arduino IDE — all free).

> 🔧 **Scaling to a real transformer:** swap DS18B20/ACS712 for industrial-grade oil-immersion RTD probes and a proper CT clamp, and replace placeholder `R`, `Δθ_TO`, `Δθ_HS` values with that transformer's actual temperature-rise test data.

---

## 🔌 Wiring Diagram

```
ESP32                DS18B20 (Temp)
  3.3V ─────────────── VCC
  GND  ─────────────── GND
  GPIO4 ─── 4.7kΩ ───┬─ DATA
                      └─(pull-up to 3.3V)

ESP32                ACS712 (Current)
  5V   ─────────────── VCC
  GND  ─────────────── GND
  GPIO34 (ADC) ──────── OUT

ESP32                DHT22 (Ambient, optional)
  3.3V ─────────────── VCC
  GND  ─────────────── GND
  GPIO27 ────────────── DATA
```

> ⚠️ ACS712 runs on 5V logic; ESP32 ADC pins are 3.3V-tolerant only. Use a voltage divider or level shifter on the OUT pin, or read via an external 3.3V-compatible ADC (e.g., ADS1115) for more accurate readings.

---

## 💻 Software Stack

| Layer | Tool | Notes |
|---|---|---|
| Firmware | Arduino IDE / PlatformIO (C++) | Runs on ESP32 |
| Messaging | MQTT (e.g., `PubSubClient` library) | Publishes sensor + calculated data |
| Cloud Dashboard | [ThingsBoard](https://thingsboard.io/) Community Edition | Free, self-hostable or use ThingsBoard Cloud sandbox |
| Data Storage | ThingsBoard time-series DB | Built-in, no separate DB setup needed for prototype |
| Optional Alerts | ThingsBoard Rule Chains | Trigger notification if life-consumption rate spikes |

---

## 🧑‍💻 Firmware Logic (Pseudocode)

```cpp
// Simplified logic — not full production code
void loop() {
  float ambientTemp = readAmbientSensor();      // °C
  float oilTemp      = readOilTempSensor();      // °C
  float loadCurrent   = readCurrentSensor();      // A
  float K = loadCurrent / RATED_CURRENT;

  // Step 1: Estimate hot-spot temperature
  float hotSpotRise = DELTA_THETA_HS * pow(K, 2 * M_EXP);
  float oilRise = DELTA_THETA_TO * pow((1 + pow(K,2)*R) / (1 + R), N_EXP);
  float thetaH = ambientTemp + oilRise + hotSpotRise;

  // Step 2: Aging acceleration factor
  float F_AA = exp((15000.0/383.0) - (15000.0/(thetaH + 273.0)));

  // Step 3: Accumulate loss of life
  float sampleIntervalHours = SAMPLE_INTERVAL_SEC / 3600.0;
  totalAgedHours += F_AA * sampleIntervalHours;
  float lossOfLifePercent = (totalAgedHours / RATED_LIFE_HOURS) * 100.0;
  float lifeRemainingPercent = 100.0 - lossOfLifePercent;

  publishToMQTT(lifeRemainingPercent, thetaH, F_AA, loadCurrent);
  delay(SAMPLE_INTERVAL_SEC * 1000);
}
```

---

## 📊 Dashboard (ThingsBoard)

Recommended widgets:
- **Gauge widget** → Live "Life Remaining %" (the headline number).
- **Time-series chart** → Hot-spot temperature trend over time.
- **Time-series chart** → Load current trend over time.
- **Alarm rule** → Trigger notification if `F_AA` exceeds a set threshold for a sustained period (indicates abnormal aging rate).

---

## 🚨 Alarm Conditions

Example threshold logic to implement in ThingsBoard rule chains (tune these once real transformer reference data is available):

| Condition | Example Threshold | Alert Level | Suggested Action |
|---|---|---|---|
| Hot-spot temperature | > rated `θ_H` + 15°C | ⚠️ Warning | Check cooling system / reduce load |
| Hot-spot temperature | > rated `θ_H` + 25°C | 🔴 Critical | Immediate load reduction required |
| Aging acceleration factor (`F_AA`) | Sustained > 4 for 1+ hour | ⚠️ Warning | Insulation aging at 4x normal rate — investigate |
| Life Remaining | Drops below 20% | ⚠️ Warning | Plan for inspection / replacement scheduling |
| Life Remaining | Drops below 10% | 🔴 Critical | Prioritize for detailed inspection (e.g., DGA test) |
| Load current | > 110% of rated for 4+ hours | ⚠️ Warning | Evaluate against Dynamic Loading Advisor output |
| Sensor dropout | No data received for 10+ minutes | ⚠️ Warning | Check connectivity / hardware fault |

---

## 🎯 Bonus Feature: Dynamic Loading Advisor

Since the system tracks aging rate in real time, it can answer a second, very practical question:

> *"If I overload this transformer by X% for the next few hours, how much life will it actually cost me?"*

This is a known industry concept called **dynamic thermal loading**, used by utilities for emergency/contingency loading decisions (e.g., when a neighboring transformer is out of service). Implementation idea: run the Step 1–3 formulas forward in simulation for a proposed load profile, and report projected life-loss before the operator commits to the overload.

---

## 🌍 Applications

- **Distribution transformers** (residential/commercial feeders) — currently the least-monitored tier; biggest potential impact due to sheer numbers.
- **Industrial plant transformers** — factories running variable, sometimes heavy loads that don't match "textbook" rated conditions.
- **Renewable energy sites** (solar/wind step-up transformers) — variable generation causes unusual, fluctuating load profiles well-suited to real-time tracking.
- **EV charging infrastructure** — fast-charging stations impose sudden, high-load demand spikes on local transformers.
- **Rural/remote substations** — locations where frequent manual inspection is logistically difficult or expensive.
- **Fleet-wide asset management** — utilities could rank hundreds of transformers by real-time aging rate to prioritize maintenance budget where it matters most.

---

## 🔍 What Already Exists (Prior Art)

Be upfront about this — it strengthens the project's credibility rather than weakening it:

- **IEEE C57.91** is a published, decades-old standard — the aging math itself is not new.
- **Commercial "transformer digital monitors"** already implement this exact model, typically using **fiber-optic hot-spot sensors**, on **large (100+ MVA), critical, high-voltage (132kV+) transformers**.
- **Dynamic thermal loading** is an established, named utility practice, not an original idea.

**The actual contribution of this project:** applying the same proven model through a **low-cost, retrofit-friendly IoT stack** (ESP32 + MQTT + cloud dashboard) to make it accessible on the **much larger population of mid-size and distribution transformers** that don't currently get this level of monitoring, because fiber-optic systems are priced for the top tier only.

---

## 🗺 Roadmap

- [x] Concept design and thermal aging model research
- [x] Bench-top prototype BOM and wiring plan
- [ ] Build and test bench prototype (simulated heat load)
- [ ] Calibrate against known `R`, `Δθ_TO`, `Δθ_HS` reference values
- [ ] Build ThingsBoard dashboard with live gauge + alerts
- [ ] Implement Dynamic Loading Advisor simulation
- [ ] Validate against real transformer temperature-rise test data (if available)
- [ ] Explore ML-based refinement of aging predictions using historical trend data
- [ ] Explore integration with Dissolved Gas Analysis (DGA) data as a complementary diagnostic

---

## ⚠️ Limitations & Honest Caveats

- This is a **thermal model estimate**, not a direct physical measurement — it should support engineering judgment and complement (not replace) established diagnostics like Dissolved Gas Analysis (DGA).
- Accuracy depends heavily on having correct `R`, `Δθ_TO`, and `Δθ_HS` values for the specific transformer — these should come from actual design/test data, not generic assumptions.
- "Rated total insulation life" is itself a statistical/engineering reference figure, not a hard physical failure point — real transformers often exceed it. Treat the percentage as a **relative aging trend indicator**, not an exact countdown to failure.
- The bench prototype simulates transformer heating with a small load; it does not replicate real transformer thermal dynamics, oil circulation, or cooling system behavior.

---

## 🎓 Learning Outcomes

Building this project is expected to strengthen understanding of:

- Transformer thermal behavior — top-oil vs winding hot-spot temperature, and how loading/cooling type affects both.
- Insulation aging theory — the Arrhenius-based relationship between temperature and material degradation rate.
- Applying a published engineering standard (IEEE C57.91) to a working system, rather than just reading about it.
- End-to-end IoT pipeline design — sensor interfacing, MQTT messaging, cloud dashboards, and alarm rule logic.
- Embedded C++ development on ESP32 (ADC reading, sensor libraries, MQTT publishing).
- Translating a design-stage engineering calculation (normally done once, in Excel) into a continuous, automated monitoring system.
- Communicating a technical concept clearly — through documentation, diagrams, and presentation.

---

## 📚 References

- IEEE Std C57.91 — *IEEE Guide for Loading Mineral-Oil-Immersed Transformers and Step-Voltage Regulators*
- IEC 60076-7 — *Loading guide for oil-immersed power transformers*
- IEEE Std C57.104 — *IEEE Guide for the Interpretation of Gases Generated in Oil-Immersed Transformers* (for DGA context)

---

## 📄 License

This project is shared for educational and portfolio purposes. Feel free to fork, adapt, and build on it — attribution appreciated.

---

**Author:** Rahul Sahu — B.Tech Electrical & Electronics Engineering
*Built as a concept project connecting IoT experience with power transformer design fundamentals.*
