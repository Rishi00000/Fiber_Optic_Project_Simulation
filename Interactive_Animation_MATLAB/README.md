# Interactive Fiber Optic Device Simulation Suite (MATLAB)

**Project Title:** Simulation of Fiber Optic Isolator, Circulator, and Wavelength Division Multiplexing (WDM)  
**Primary Focus:** Professional, high-fidelity animated light pulse propagation through optical fibers and photonic devices.  
**Platform Compatibility:** 100% compatible with **MATLAB Online** (web browser) and **Desktop MATLAB** (R2020a through R2026+).

---

## Folder Isolation Notice
> [!IMPORTANT]
> This folder (`Interactive_Animation_MATLAB/`) is completely self-contained. It contains all visualization scripts, graphical fiber-drawing primitives, interactive UI panels, and animation loops. None of your teammate's calculation scripts, graphs, or data in the parent directories have been altered.

---

## 1. Quick Start Guide

### Option A: Running in MATLAB Online (Recommended for College Submissions)
1. Open your browser and go to [MATLAB Online](https://matlab.mathworks.com).
2. In the "Current Folder" browser on the left, upload this entire `Interactive_Animation_MATLAB` folder (or drag and drop it into MATLAB Drive).
3. In the MATLAB Online Current Folder panel, double-click to enter `Interactive_Animation_MATLAB`.
4. In the Command Window, type:
   ```matlab
   launch_app
   ```
   and press **Enter** (or open `launch_app.m` in the Editor and click the green **Run** button).
5. The full-screen interactive dashboard will open immediately.

### Option B: Running in Desktop MATLAB
From the MATLAB command prompt:
```matlab
cd('d:\FiberOpticProject\Fiber_Optic_Project_Simulation\Interactive_Animation_MATLAB')
launch_app
```

### Option C: Running Individual Standalone Modules
You can also launch any single device simulation independently:
- **Optical Isolator:**
  ```matlab
  animate_isolator
  ```
- **Optical Circulator (3-Port):**
  ```matlab
  animate_circulator
  ```
- **Wavelength Division Multiplexing (WDM):**
  ```matlab
  animate_wdm
  ```

---

## 2. Module Overview & What to Show Your Professor

### Module A: Fiber Optic Isolator (`animate_isolator.m`)
* **Objective:** Visually demonstrate why laser sources require optical isolators to prevent back-reflections from causing laser instability.
* **What the Animation Shows:**
  - **Forward Direction:** The Laser Diode launches a luminous optical pulse (cyan glow) at 1550 nm. It passes the $0^\circ$ input polarizer, rotates $+45^\circ$ inside the magneto-optic YIG crystal (Faraday rotator), aligns with the $45^\circ$ output analyzer, and emerges with minimal insertion loss ($0.5\text{ dB}$, $\sim 8.91\text{ mW}$).
  - **Reverse Direction:** Reflected backward light enters the $45^\circ$ analyzer. Because the Faraday effect is **non-reciprocal**, the light rotates *another* $+45^\circ$ in the same direction, arriving at the input polarizer oriented at $90^\circ$ (orthogonal). Light is completely blocked/extinguished ($\ge 30\text{ dB}$ isolation, $\le 0.01\text{ mW}$ leakage).
* **Controls:**
  - Toggle between **Forward** and **Reverse** propagation.
  - Sliders for Input Power (1-30 mW), Insertion Loss (0.1-3 dB), Isolation (15-50 dB), and Speed.
  - **Pause/Resume** button to freeze the pulse right inside the Faraday crystal to explain the $45^\circ$ rotation to your instructor.

### Module B: Basic Three-Port Circulator (`animate_circulator.m`)
* **Objective:** Demonstrate non-reciprocal cyclic routing across three distinct optical fiber ports:
  $$\text{Port } 1 \longrightarrow \text{Port } 2 \longrightarrow \text{Port } 3 \longrightarrow \text{Port } 1$$
* **What the Animation Shows:**
  - Three distinct single-mode fiber waveguides connected to a central magneto-optic circular junction.
  - Selecting **Port 1** launches a pulse along Fiber 1, curves through the internal junction, and exits smoothly at **Port 2**.
  - Selecting **Port 2** routes the pulse to **Port 3**.
  - Selecting **Port 3** routes the pulse to **Port 1**.
  - The active route is highlighted in neon green, and the destination port flashes upon arrival.
* **Controls:**
  - **Port 1 / Port 2 / Port 3** selector buttons.
  - **Ideal vs. Realistic** mode (incorporates 0.6 dB insertion loss and 35 dB crosstalk isolation).
  - Real-time step-by-step physical status tracker.

### Module C: WDM Multi-Channel Transmission (`animate_wdm.m`)
* **Objective:** Demonstrate how 4 separate wavelength channels in the optical C-band travel simultaneously along a single optical fiber and get separated at the receiver.
* **What the Animation Shows:**
  - **4 Transmitters (TX1 - TX4):** 1530 nm (Cyan), 1540 nm (Green), 1550 nm (Amber), and 1560 nm (Magenta).
  - **Multiplexer (MUX):** Combines the separate input fiber beams into a single shared long-haul transmission fiber.
  - **Co-Propagation:** Multi-wavelength pulses travel together through the fiber core. Attenuation causes gradual power drop over distance, and chromatic dispersion causes slight group delay offsets.
  - **Demultiplexer (DEMUX):** Prismatic/AWG grating separates the channels back into individual output fibers leading to **Receivers (RX1 - RX4)**.
* **Controls:**
  - Individual channel checkboxes (turn channels on/off to prove independent transmission).
  - Fiber distance slider (10 to 100 km) with live loss calculation ($0.2\text{ dB/km}$).
  - Speed control and pause/resume.

---

## 3. Technology & Architecture

- **Zero External Toolboxes:** Uses only core MATLAB graphics primitives (`figure`, `axes`, `patch`, `line`, `plot`, `uicontrol`, `uipanel`), guaranteeing instant compatibility on any MATLAB version.
- **Scientific Aesthetic:** Charcoal/dark navy background (`#0f1420`), luminous laser pulse glow effects, fiber core-and-cladding rendering, and responsive real-time status captions.
- **Interactive UI Architecture:** Pure MATLAB event callbacks with non-blocking animation loops (`drawnow`), allowing instant pause, resume, and real-time parameter tweaking.
