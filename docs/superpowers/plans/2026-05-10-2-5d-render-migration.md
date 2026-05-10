# 2.5D Render Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fragile 2D shadow fakery with a 2.5D-style render layer that keeps the existing 2D gameplay and UI intact.

**Architecture:** `Level` remains the gameplay owner. A new `World25D` node owns the visual depth pass: one explicit sun vector, texture-silhouette cast shadows, contact shadows, and character rim shading for existing 2D actors and scenery. A true 3D `SubViewport`/`Camera3D` pass was prototyped, but Godot 4.6 `gl_compatibility` runtime capture went black with either direct 3D or `SubViewport`; the implemented path keeps the game shippable and visually aligned with the requested Spell Brigade-style top-down shadows.

**Tech Stack:** Godot 4.6, GDScript, `AnimatedSprite2D`/`Sprite2D` shadow proxies, `ShaderMaterial`, CanvasItem shaders.

---

### Task 1: Runtime 2.5D World

**Files:**
- Create: `environment/world_25d.gd`

- [x] Create a `World25D` script that builds a runtime 2.5D-style shadow/rim pass.
- [x] Use a single exported sun/shadow direction for all visual projections.
- [x] Add weak-reference proxy tracking for 2D actor nodes and background sprites.

### Task 2: Actor and Prop Proxies

**Files:**
- Modify: `environment/world_25d.gd`

- [x] Mirror `friendly`, `baby_elephant`, and `lion` nodes into silhouette shadow proxies.
- [x] Read each actor's `Flipper/Body` animation frame texture every frame.
- [x] Keep original 2D body sprites visible/readable; add rim material instead of hiding gameplay visuals.
- [x] Mirror background prop sprites from groups into shaped cast shadows.

### Task 3: Scene Wiring

**Files:**
- Modify: `environment/Level.tscn`
- Modify: `environment/background.gd`
- Modify: `environment/visual_effects.gd`

- [x] Add `World25D` under `Level`.
- [x] Add spawned background sprites to `render_25d_ground` and `render_25d_prop` groups.
- [x] Disable legacy 2D fake lighting when `World25D` exists.

### Task 4: Verification

**Files:**
- Test through Godot MCP.

- [x] Run `git diff --check`.
- [x] Run the level through Godot MCP with temporary direct route.
- [x] Capture a screenshot and verify consistent top-right sun shadows are visible.
- [x] Confirm `game/Main.gd` is restored after temporary route testing.
