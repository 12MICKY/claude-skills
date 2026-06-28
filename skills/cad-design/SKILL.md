---
name: cad-design
description: Use this skill for CAD modeling with Autodesk Fusion 360 and Onshape — parametric sketching, constraints, 3D bodies and components, assemblies, sheet metal, CAM toolpaths, and exporting STL/STEP/DXF for 3D printing, laser cutting, or CNC machining. Activate when designing parts, creating engineering drawings, or preparing files for fabrication.
---

# CAD Design — Fusion 360 & Onshape

## Core Parametric Workflow

Both Fusion 360 and Onshape follow the same parametric modeling approach:

```
Sketch (2D) → Extrude/Revolve/Sweep (3D body) → Features (holes, fillets, chamfers)
→ Components → Assembly → Export
```

**Parametric = driven by dimensions, not geometry.** Every dimension is a parameter you can change later — the model updates automatically. Design with intent: use constraints to capture design relationships, not just dimensions.

## Sketching Fundamentals

**Constraint types (same in both tools):**

| Constraint | When to use |
|---|---|
| Fixed | Lock a specific point to the origin |
| Horizontal / Vertical | Force lines parallel to axes |
| Coincident | Two points or a point+line share position |
| Tangent | Arc/circle smoothly meets a line |
| Equal | Two edges always stay the same length |
| Symmetric | Mirror about a centerline |
| Midpoint | Point stays at center of a line |

**Fully constrained sketch = all geometry turns black.** Blue geometry = underconstrained (can still move). Red = overconstrained (conflicting constraints — remove one).

**Best practice — always anchor to origin:**
```
1. Draw geometry near origin
2. Add a coincident constraint from a key point to the origin
3. Add dimensions for all remaining degrees of freedom
4. Confirm sketch is fully constrained before exiting
```

**Construction geometry:** toggle lines to construction (dashed) when they're reference-only. Construction lines don't become 3D edges but still participate in constraints and dimensions.

## Fusion 360

### Sketch → 3D Body

```
Solid → Sketch → Select face or plane → Draw → Finish Sketch
→ Solid → Extrude (or press E)
```

**Extrude options:**
- **New Body** — creates an independent solid.
- **Join** — merges with existing body (boolean union).
- **Cut** — subtracts from existing body (boolean difference).
- **Intersect** — keeps only overlapping volume.
- **Symmetric** — extrudes equal distance both directions.

**Revolve** — rotate a profile around an axis. For round parts (bottles, pulleys, knobs).

**Sweep** — extrude a profile along a path. For curved pipes, handles, custom extrusions.

### Useful Features

```
Fillet (F)        — round an edge; use sparingly, add at end of design
Chamfer           — bevel an edge; better for FDM 3D prints than fillets on print face
Shell             — hollow out a body with uniform wall thickness
Mirror            — reflect features/bodies across a plane (design half, mirror it)
Circular Pattern  — repeat around an axis (bolt holes, teeth)
Rectangular Pattern — repeat in a grid
```

**Fillet tip for 3D printing:** don't add fillets on faces that will be on the print bed — they create unsupported overhangs. Add fillets on top or vertical edges only.

### Components and Assemblies

```
Solid → New Component    — container for one part in an assembly
As-built Joint           — define relationships between components
Joint → Rigid            — parts don't move relative to each other
Joint → Revolute         — rotates around an axis (hinges, wheels)
Joint → Slider           — translates along an axis (rails, drawers)
```

**Design best practice:** one component per physical part. Use `New Component` before modeling each part, not after.

### Parameters (spreadsheet-style variables)

```
Modify → Change Parameters
```

```
wall_thickness = 3 mm
bolt_diameter  = 4 mm
clearance      = 0.2 mm    # fit tolerance for printed parts

# Use in sketches: type the parameter name instead of a number
# e.g., dimension = bolt_diameter + clearance
```

**Parametric tolerances for 3D printing:**
- Press-fit: `clearance = 0.1–0.15 mm`
- Slip-fit: `clearance = 0.2–0.3 mm`
- Free (bearing) fit: `clearance = 0.4–0.5 mm`

### CAM (Toolpaths for CNC)

```
Switch workspace: Manufacture
Setup → New Setup → select stock and coordinate system (WCS)
```

**2D operations (for CNC routing/engraving):**
- **2D Contour** — cut along the outside or inside of a profile.
- **2D Pocket** — clear material inside a closed profile.
- **Drill** — drill holes at exact positions.
- **Engrave** — follow a path at fixed depth.

**Tool settings (example: 3mm flat end mill in wood):**
```
Spindle speed:  18000 RPM
Feed rate:      1000 mm/min
Plunge rate:    300 mm/min
Depth of cut:   1.5 mm (half tool diameter per pass)
```

**Post-process → export G-code:**
```
Post Process → select machine post processor
→ Save to .nc or .gcode file
```

### Export for Fabrication

```
File → Export → STL       # 3D printing
File → Export → STEP      # share with other CAD tools (preserves parametric intent)
Sketch → right-click → Save as DXF   # laser cutting / CNC
```

**STL refinement:** higher = smaller triangles = better surface quality = larger file.
- Draft: `0.1 mm` deviation — fast slice, visible facets on curves.
- Normal: `0.05 mm` — good balance.
- Fine: `0.01 mm` — only needed for organic shapes.

## Onshape

### Key Differences from Fusion 360

| Feature | Fusion 360 | Onshape |
|---|---|---|
| Where it runs | Desktop app (Windows/Mac) | Browser (any device) |
| File storage | Local + Autodesk cloud | Onshape cloud only |
| Free tier | Free for personal use | Free for public documents |
| Assemblies | Single file, components tab | Same file, Part Studios + Assembly tabs |
| Version history | Timeline (visual) | Commit history (like git) |

### Onshape-Specific Workflow

**Part Studio** = where you create geometry (equivalent to Fusion's design workspace).

**Assembly** = where you mate parts together.

```
Create document → Part Studio tab → Sketch → Extrude → Features
→ Assembly tab → Insert parts → Add mates
```

**Mate types:**
- **Fastened** — rigid, no movement.
- **Revolute** — rotation around one axis.
- **Slider** — translation along one axis.
- **Cylindrical** — rotation + translation (like a bolt in a hole).
- **Ball** — rotation in all directions (ball joint).

**Mate connector = coordinate system attached to a face/edge/point.** Always add mate connectors at meaningful geometric features (center of hole, end of shaft) for reliable assembly.

### Variables in Onshape

```
Part Studio → Variables feature → Add
```
```javascript
wall = 3;        // mm
bolt_d = 4;      // bolt diameter
fit = 0.2;       // slip fit clearance
```

Reference with `#variable_name` in dimension boxes.

### Export from Onshape

```
Right-click part or face → Export
→ STL (3D printing)
→ STEP (CAD exchange)
→ DXF/DWG (2D drawing, laser cutting)
→ Parasolid, IGES (other CAD tools)
```

**Drawing tab:** add dimensions, tolerances, title block for engineering documentation.

## Design Rules for 3D Printing (FDM)

Apply these in CAD before slicing:

| Rule | Reason |
|---|---|
| Min wall = 2× nozzle diameter (≥0.8 mm for 0.4 mm nozzle) | Thinner walls may not slice |
| Overhang ≤45° from vertical | Steeper = needs supports |
| Holes perpendicular to print bed are round | Horizontal holes print as teardrops — model a teardrop if precision needed |
| Add 0.2 mm clearance for mating parts | FDM prints slightly oversize |
| Chamfer bottom edges (0.5–1 mm) | Improves bed adhesion, prevents elephant foot |
| Avoid features thinner than 1.2 mm | Too fragile / may not print |

## Design Rules for Laser Cutting

```
2D sketch → export DXF → import to LightBurn
```

| Rule | Reason |
|---|---|
| Min feature size ≥ material thickness | Thin bridges break or char |
| Kerf offset: 0.1–0.2 mm per side for wood | Laser removes material; account in slot/tab joints |
| Press-fit slots: subtract 0.1 mm per side | Tight finger joints without glue |
| Dogbone fillets on inside corners | CNC router can't cut sharp inside corners |
| No overlapping lines in DXF | Laser cuts twice = burns through |

## Common Mistakes

- **Forgetting tolerances:** designed at exact size → printed parts don't fit. Always add clearance.
- **Over-constraining:** adding dimension + coincident to same point → red sketch. Remove one.
- **Not grounding assembly:** floating components → joint positions shift unexpectedly. Fix one component first.
- **STL too coarse:** low-resolution STL prints with visible flat facets on curved surfaces. Increase mesh quality on export.
- **Thin walls in Onshape/Fusion show fine but don't slice:** slicer ignores walls thinner than one extrusion width. Minimum = nozzle × 2.
- **DXF with open contours:** laser software can't fill or follow unclosed paths. Audit with LightBurn's "close paths" tool before cutting.
