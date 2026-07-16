# V6 Asset Design — 3D Model Specifications

## Design Philosophy
Models inspired by **Supreme Commander: Forged Alliance** aesthetic, adapted for Cycle Four factions:
- **Architects** → Seraphim (sleek, curved, glowing)
- **Bloom** → Aeon (organic, hover-tech) + biological components
- **Mesh** → Cybran (insectoid, angular, spiky)

All commanders are **bi-pedal super mechs**. All units are **fully rigged** with bone skeletons for articulated animation.

---

## Commanders (ACU — Armored Command Units)

### Architect Commander
**Inspiration:** Seraphim ACU  
**Silhouette:** Bi-pedal mech, 2-3 stories tall  
**Aesthetics:**
- Sleek, curved armor plating with minimal hard angles
- Glowing energy seams running along limbs and torso
- Advanced, alien-tech appearance
- Aggressive stance (forward-leaning posture)
- Proportions: narrow waist, broad shoulders, elegant leg articulation

**Key Features:**
- Chronotron cannon equivalent: mounted on arm or shoulder (glowing energy weapon)
- Rapid nano-repair bays visible on back/sides
- Energy core glowing in center of chest
- Minimal visible mechanical joints (seamless aesthetic)

**Rigging:**
- Spine chain (3-4 vertebrae for torso flex)
- Shoulder/arm IK chains (2 per side)
- Hip/leg IK chains (2 per side)
- Weapon mount point
- Energy effects attach points

---

### Bloom Commander
**Inspiration:** Aeon ACU + biological growth  
**Silhouette:** Bi-pedal mech with organic overlays  
**Aesthetics:**
- Sleek hover-tech core (smooth, curved chassis)
- Biological components growing over/through armor
- Glowing bioluminescent veins/patterns
- Organic tendrils or root-like structures on legs/back
- Sanctuary/growth-oriented appearance
- Living metal: armor appears partially organic

**Key Features:**
- Bio-weapon: seed launcher or spore cannon (mounted on arm)
- Regeneration glow (warm, pulsing bioluminescence)
- Living root-system legs (articulated segments)
- Hover-field generator base
- Bud formations along armor (breakable cosmetic detail)

**Rigging:**
- Spine chain (flexible for organic feel)
- Arm chains with secondary tendrils (bendy)
- Leg chains with multiple segments (root-like joints)
- Hover-core stabilizers
- Biological growth animation points

---

### Mesh Commander
**Inspiration:** Cybran ACU  
**Silhouette:** Angular, aggressive bi-pedal mech  
**Aesthetics:**
- Exposed mechanical framework (visible exoskeleton)
- Sharp, jagged angles and protrusions
- Dark metallic finish with hot-spot glowing (orange/red)
- Insectoid proportions (narrow joints, spiky limbs)
- Forward-aggressive combat stance
- Mandible-like jaw or sensor arrays

**Key Features:**
- Hacking suite: visible on torso or forearms
- EMP aura generator
- Exposed circuitry visible in joints/seams (glowing circuits)
- Multi-limbed weapon mounts (pincers, lasers, pulse cannons)
- Stealth field generator (barely visible distortion)
- Heavy armor plating offset by spiky protrusions

**Rigging:**
- Spine chain (rigid for mechanical feel)
- Shoulder/arm chains with mandible controls
- Hip/leg IK chains (4-6 articulation points per leg for insectoid gait)
- Weapon hardpoints
- EMP/stealth aura zone

---

## T1 Units (Tier 1 — Basic Combat/Scout)

### Architect T1 Scout — "Salail"
**Inspiration:** Seraphim Salail (fast cloaking scout)  
**Form:** 4-legged walker, sleek and compact  
**Size:** ~2-3m tall  
**Aesthetics:**
- Curved, streamlined body (no sharp angles)
- Glowing energy pathways along armor
- Hover-capable legs or magnetic feet
- Minimal weaponry (light pulse cannons)

**Rigging:** 4-point IK legs, flexible spine, sensor mount

---

### Bloom T1 Scout — "Spirit"
**Inspiration:** Aeon Spirit (hover scout) + biological  
**Form:** Floating saucer with organic appendages  
**Size:** ~2m diameter  
**Aesthetics:**
- Smooth, disc-shaped hover platform
- Biological sensor tendrils hanging beneath (2-4 tendrils)
- Bioluminescent eyes/sensors
- Organic growth patterns on surface

**Rigging:** Hover stabilizers, tendrils (FK), sensor stalks

---

### Mesh T1 Assault — "Mantis"
**Inspiration:** Cybran Mantis (fast assault bot with engineering)  
**Form:** 6-legged insectoid walker  
**Size:** ~2.5m tall  
**Aesthetics:**
- Angular, spiky exoskeleton
- Exposed mechanical joints (visible at knees, elbows)
- Forward-facing mandible or claw appendages
- Glowing hot-spots at joints (orange/red thermal signature)
- Stacked, segmented body sections

**Rigging:** 6-point IK legs with 2 joints each, mandible articulation, torch/tool mount

---

## T2 Units (Mid-tier — Specialized)

### Architect T2 Assault — "Ilshavoh"
**Inspiration:** Seraphim Ilshavoh (hover assault bot)  
**Form:** 4-legged hover tank  
**Size:** ~3m tall  
**Aesthetics:**
- Sleek, aerodynamic chassis
- Glowing armor seams
- Hover-field generators visible (shimmering zones)
- Heavy but elegant weapon mounts

**Rigging:** 4-point IK legs, turret azimuth, weapon gimbal

---

### Bloom T2 Heavy — "Obsidian"
**Inspiration:** Aeon Obsidian (hover assault tank) + biological  
**Form:** Organic hover platform with biological components  
**Size:** ~3.5m  
**Aesthetics:**
- Bulbous, organic shape
- Bioluminescent weapon arrays
- Root-system anchors (when stationary)
- Heavy biological armor plating
- Pulsing energy vents

**Rigging:** Hover core, root deployment, turret gimbal, biological animation points

---

### Mesh T2 Support — "Hoplite"
**Inspiration:** Cybran Hoplite (rocket bot)  
**Form:** Compact 4-legged walker  
**Size:** ~2m  
**Aesthetics:**
- Angular, highly modular appearance
- Exposed rocket/missile pod on back
- Articulated leg joints with visible hydraulics
- Dark chassis with glowing weapon ports
- Lightweight but dangerous look

**Rigging:** 4-point IK legs, missile pod pitch/yaw, sensor turret

---

## T3 Units (High-tier — Specialized Killers)

### Architect T3 Sniper — "Usha-Ah"
**Inspiration:** Seraphim Usha-Ah (sniper bot)  
**Form:** Elegant 2-legged walker or tripod stance  
**Size:** ~4m  
**Aesthetics:**
- Tall, slender profile for sniping angle
- Sleek, curved armor with glowing targeting systems
- Long-range cannon (integrated, not external)
- Stabilizer legs for accuracy
- Precision-focused aesthetic

**Rigging:** 2-3 point stance legs, spine flex, weapon gimbal with stabilizers

---

### Bloom T3 Assault — "Sprite Striker"
**Inspiration:** Aeon Sprite Striker (sniper) + Bloom adaptation  
**Form:** Organic multi-limbed walker  
**Size:** ~4m  
**Aesthetics:**
- Biological root-system base (3-4 articulated roots)
- Flowering weapon mount (bud opens to reveal cannon)
- Bioluminescent targeting array
- Living armor that heals/regenerates appearance
- Symbiotic aesthetic (weapon is biological extension)

**Rigging:** Multi-limb IK (5-6 root legs), weapon bloom animation, targeting pod

---

### Mesh T3 Heavy Assault — "Loyalist"
**Inspiration:** Cybran Loyalist (armored assault) + spike payload  
**Form:** Heavy 4-legged tank-walker  
**Size:** ~4.5m  
**Aesthetics:**
- Massive, imposing angular frame
- Heavy spike/blade protrusions (defensive + offensive)
- Exposed armor seams glowing with EMP charge
- Multi-limbed weapon arrays (front-facing pincers/lasers)
- Aggressive, siege-oriented appearance
- Heat distortion around armor (thermal signature)

**Rigging:** Heavy 4-point IK legs (low-slung), pincer articulation, EMP charge glow animation

---

## Visual Requirements Summary

### Shared Across All Models
✓ **Rigged skeleton** with IK/FK chains for natural movement  
✓ **Faction-specific materials:**
  - Architects: Chrome/metal with glowing seams (cool blue energy)
  - Bloom: Organic/chitin with bioluminescence (warm green/gold)
  - Mesh: Dark metal with hot-spot glows (orange/red)  
✓ **Export as GLTF 2.0** with embedded armatures  
✓ **Animation-ready** (no animations baked, skeleton can be driven by Godot)  

### Poly Budget
- Commanders: 5k–10k tris
- T1 Units: 1k–2k tris
- T2 Units: 2k–4k tris
- T3 Units: 4k–6k tris

### Movement Expectations
- **Architects:** Smooth, mechanical, elegant gait
- **Bloom:** Flowing, organic, root-like locomotion
- **Mesh:** Fast, insectoid, multi-jointed skitter

---

## Next Steps
1. Generate Commanders first (validate aesthetic direction)
2. Generate T1 units (quick validation of faction style)
3. Iterate on scale, proportion, detail based on playtest feedback
4. Add T2/T3 as needed for gameplay expansion
