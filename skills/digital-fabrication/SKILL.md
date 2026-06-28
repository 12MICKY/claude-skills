---
name: digital-fabrication
description: Use this skill for 3D printing (FDM), laser engraving and cutting with LightBurn, and multi-tool machines like Snapmaker. Covers slicer settings (Orca Slicer, Bambu Studio, PrusaSlicer), print troubleshooting, material profiles, LightBurn power/speed tables, material settings for wood/acrylic/leather, job setup, and camera calibration. Activate for any 3D print quality issue, slicer configuration, laser job setup, or material selection question.
---

# Digital Fabrication — 3D Printing & LightBurn

## FDM 3D Printing Fundamentals

### Key Parameters (Slicer)

| Parameter | Typical value | Effect |
|---|---|---|
| Layer height | 0.1–0.3 mm | Lower = smoother surface, longer print |
| Nozzle diameter | 0.4 mm (standard) | Determines min feature size |
| Print speed | 50–150 mm/s | Faster = more artifacts, better for drafts |
| Infill % | 15–40% | Strength; >40% rarely needed |
| Infill pattern | Gyroid / Grid | Gyroid = isotropic strength; Grid = fast |
| Wall loops | 3–4 | Outer strength and detail |
| Top/bottom layers | 4–5 | Surface quality and impermeability |
| Support type | Normal / Tree | Tree = less material, easier to remove |
| Support angle | 45–50° | Angle above which supports generate |
| Bed temperature | Varies by material | See table below |
| Print temperature | Varies by material | See table below |

### Material Settings

| Material | Nozzle | Bed | Enclosure | Notes |
|---|---|---|---|---|
| PLA | 200–220°C | 60°C | Open OK | Easy, brittle, low heat resistance (<60°C) |
| PETG | 230–245°C | 70–85°C | Open OK | Tough, slightly flexible, food-safe options |
| ABS | 240–255°C | 100–110°C | Required | Warps heavily; needs enclosure + brim |
| ASA | 245–260°C | 100°C | Required | Like ABS but UV-resistant; for outdoor parts |
| TPU (flexible) | 220–235°C | 45°C | Open OK | Slow speed (25 mm/s); direct drive preferred |
| PA (Nylon) | 250–270°C | 70°C | Dry required | Hygroscopic; dry 8h before use |
| PC | 270–300°C | 110°C | Required | High strength and heat resistance |

**Moisture rule:** PETG, Nylon, TPU absorb moisture from air → stringy prints, popping sounds. Dry at 65°C for 4–6 hours in food dehydrator or oven.

### Orca Slicer / Bambu Studio Workflow

```
1. File → Import 3MF/STL
2. Select printer profile + filament profile
3. Adjust supports: Auto (tree) for complex overhangs
4. Layer height: 0.2 mm for functional parts, 0.1 mm for detail
5. Infill: 15% Gyroid for normal parts, 40%+ for mechanical stress
6. Slice → Preview → check layer view for problem areas
7. Export → send to printer (via USB, Wi-Fi, or SD card)
```

**Orca Slicer for Snapmaker:** use the Snapmaker Orca AppImage (not Flatpak OrcaSlicer — WebKit issues). Select Snapmaker J1/A350/U1 profile.

### Print Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| First layer not sticking | Bed too far from nozzle, dirty bed | Relevel, clean with IPA, increase bed temp |
| Warping corners | Thermal contraction (ABS/ASA) | Enclosure, brim 5–10 mm, draft shield |
| Stringing | Too-high temp, retraction too low | Lower temp 5°C, increase retraction 0.5 mm |
| Gaps in top surface | Not enough top layers or low infill | Add 1–2 top layers, increase infill to 20%+ |
| Layer separation | Low temp, printing too fast | Raise temp 5°C, reduce speed |
| Elephant foot | First layer over-extruded / bed too close | Increase Z offset, reduce first-layer flow |
| Blobs/zits | Over-extrusion at seam | Enable Seam Painting, reduce pressure advance |
| Clogged nozzle | Carbon buildup, wrong temp for material | Cold pull: heat to 250°C, cool to 90°C, pull |
| Print shifts (X/Y) | Loose belt or motor current too low | Tighten belt, check motor current in firmware |

### Supports

**Tree supports** (default for complex parts):
- Less contact with model surface → cleaner removal
- Use for organic shapes, figurines, overhanging bridges

**Normal supports**:
- More reliable for large flat overhangs
- Easier to configure Z-distance

**Support Z distance:** `0.15–0.2 mm` — gap between support top and model bottom. Smaller = better surface but harder to remove.

**Support interface layers:** 2–3 layers at top and bottom of supports → much cleaner separation. Enable in slicer.

### Post-Processing

```bash
# FDM surface finishing
- Sand with 220 → 400 → 800 grit for smooth finish
- Acetone vapor smoothing for ABS only (flammable — fume hood required)
- Primer + paint: spray filler primer first, then color coat
- Epoxy coating (XTC-3D): brush on, self-levels, adds strength
```

## Snapmaker U1 — Multi-Tool Machine

**Three modes:** FDM printing / Laser engraving+cutting / CNC routing

**Tool change workflow:**
1. Home machine (`G28`)
2. Swap toolhead (push-click connector)
3. Run calibration for new toolhead
4. Load correct profile in Orca Slicer (print) or LightBurn (laser)

**Laser module focal point:**
- Fixed focus: set material height = focal distance from spec sheet
- Auto-focus: run `M1010` or use Snapmaker Luban auto-focus feature

**API access via Moonraker:** `http://PRINTER_IP/api/` — supports OctoPrint-compatible endpoints. Use `X-Api-Key` header for authenticated calls.

## LightBurn

### Interface Overview

```
Workspace:    design canvas — place/import designs here
Cuts/Layers:  left panel — assign power/speed per color layer
Laser:        right panel — frame, start, stop, origin controls
Console:      bottom — raw G-code commands and machine output
```

### Job Setup

```
1. Set Document Settings: workspace size = laser bed size
2. Set Start From: Absolute Coords (recommended for repeatability)
3. Assign material to bed: Jig / zero machine to material corner
4. Import design: File → Import SVG/DXF/PNG
5. Assign layers: group objects by color → set Cut/Fill/Engrave per layer
6. Run Frame: verify bounds without firing laser
7. Fire laser job
```

**Origin workflow:**
```
Absolute Coords  — machine home = (0,0), consistent positioning
Current Position — laser current position = job origin, use for quick one-offs
User Origin      — user-defined point, good for jig-based work
```

### Layer Types

| Layer type | Use case |
|---|---|
| Line (Cut) | Vector cutting — follows path outline |
| Fill | Raster fill — engraves solid areas |
| Fill+Line | Engrave interior + cut outline |
| Offset Fill | Concentric fill — better for thick areas |
| Image (Dither) | Photograph/grayscale engrave |

**Layer order = cutting order.** Set inner cuts before outer cuts — cut interior features first, then outer profile, so the part doesn't move mid-job.

### Power/Speed Reference Tables

**Diode laser (10W–20W, e.g. Snapmaker 10W/20W):**

| Material | Mode | Power | Speed | Passes |
|---|---|---|---|---|
| 3mm plywood | Cut | 100% | 200 mm/min | 3–4 |
| 3mm plywood | Engrave | 50% | 3000 mm/min | 1 |
| 3mm acrylic (clear) | Cut | 100% | 120 mm/min | 4–5 |
| 3mm acrylic (colored) | Cut | 100% | 200 mm/min | 3 |
| 4mm MDF | Cut | 100% | 150 mm/min | 4 |
| Leather (1–2mm) | Engrave | 40% | 2000 mm/min | 1 |
| Leather (1–2mm) | Cut | 80% | 300 mm/min | 2 |
| Anodized aluminum | Engrave | 80% | 1500 mm/min | 1 |
| Cardboard 3mm | Cut | 60% | 400 mm/min | 1–2 |

**CO2 laser (40W–80W):**

| Material | Mode | Power | Speed | Passes |
|---|---|---|---|---|
| 3mm plywood | Cut | 55% | 20 mm/s | 1 |
| 3mm acrylic | Cut | 60% | 15 mm/s | 1 |
| 6mm acrylic | Cut | 75% | 8 mm/s | 1 |
| Engrave wood | Fill | 25% | 150 mm/s | 1 |
| Engrave acrylic | Fill | 18% | 200 mm/s | 1 |

**Always run a material test grid before production jobs** — vary power (rows) and speed (columns) on a scrap piece.

### LightBurn Material Test

```
Laser Tools → Material Test
→ Set power range: 20%–100%, 9 steps
→ Set speed range: 100–500 mm/min, 9 steps
→ Shape: rectangle 10×10 mm
→ Generate → Run on scrap
```

Find the cell with clean cut/engrave → note power % and speed for your material file.

### Kerf Calibration

Laser removes a small amount of material (kerf) when cutting. For press-fit finger joints:

```
Laser Tools → Kerf Test
→ Measure resulting cut with calipers
→ Enter kerf width in Cut Settings → Kerf Offset
```

Typical kerf: `0.1–0.25 mm` for diode laser on plywood.

### Camera Calibration (Workspace Preview)

```
Laser → Calibrate Camera Lens
→ Calibrate Camera Alignment
→ Capture workspace image
```

After calibration: click anywhere on the camera image to position the job precisely over your material. Alignment accuracy: ±0.5–1 mm.

### Rotary Attachment

```
Laser → Rotary Setup
→ Enable rotary
→ Enter steps per revolution (from rotary datasheet)
→ Enter object diameter (measure with calipers)
→ Test: jog Y-axis 100 mm → object should rotate 100 mm of circumference
```

For engraving cylinders (cups, pens): design as flat → LightBurn wraps automatically.

### Common Issues

| Problem | Cause | Fix |
|---|---|---|
| Not cutting through | Power too low, speed too high, out of focus | Increase passes, reduce speed, refocus |
| Charring / burn marks | Too slow, too many passes | Faster speed, air assist, masking tape on surface |
| Uneven depth | Warped material | Pin material flat, or use autofocus |
| SVG doesn't import correctly | Ungrouped/overlapping paths | Use Inkscape to fix: Path → Union |
| Image too dark/light | Gamma mismatch | Adjust image brightness in LightBurn before sending |
| Skipped lines in engrave | Loose belt | Tighten Y-axis belt |

### Safety

- **Never leave running unattended** — fire risk, especially with wood/acrylic.
- **Air assist** reduces charring and extends lens life — always on when cutting.
- **Ventilation required** — laser fumes are toxic. Duct outside or use fume extractor with HEPA + activated carbon filter.
- **Wear laser safety goggles** matched to laser wavelength (diode ≈ 450 nm blue or 1064 nm IR; CO2 = 10600 nm).
- **Never cut PVC** — produces chlorine gas.
- **Never cut polycarbonate (PC)** — produces toxic fumes, poor cut quality.
- **Mirror/reflective metals** can reflect beam back into lens — engrave anodized only.
