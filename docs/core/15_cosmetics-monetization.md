# Monetization — Cosmetic Tier Structure

> Session 4 output. Defines the full cosmetic unlock ladder from default
> palettes through full faction reskins. Covers pricing philosophy, earned
> vs. purchased distinction, sub-path variant skins, full reskins, and hard
> implementation rules. Option B resonance is embedded in two reskins without
> in-game acknowledgment.

---

## Philosophy First

Three rules that constrain everything below:

1. **No pay-to-win, no pay-to-progress.** No speed boosts, no resource
   multipliers, no early unlocks. A player who spends nothing reaches the
   same endgame as a player who spends everything.
2. **Readability is inviolable.** Premium skins never change unit silhouettes,
   faction color coding in combat UI, or tell animations (windup, attack,
   special ability). At a glance, mid-wave, a player must always be able to
   read what they're looking at.
3. **Earned cosmetics feel like achievements; purchased cosmetics feel like
   self-expression.** Earned palettes mark what you've done. Purchased skins
   mark who you are. Neither should feel like the other.

---

## The Four Tiers

| Tier | Name | Cost | Unlocked by |
|---|---|---|---|
| 0 | Default | Free | Starting faction selection |
| 1 | Earned Palettes | Free | Gameplay milestones and prestiges |
| 2 | Sub-Path Variants | Paid | Purchase |
| 3 | Full Reskins | Paid | Purchase |

Prestige cosmetics (non-palette effects) sit between Tier 1 and 2 — earned,
never purchased, purely achievement markers.

---

## Tier 0 — Default Palettes

Each faction's default palette is its identity shorthand. These are the
faction's *self-image* — how they would choose to present if asked.

**Architects — "The Standard"**
Cold precision. Steel-white primary structures, deep charcoal secondary, amber
accent for active systems and power conduits. Everything has clean edges and
visible geometry. No organic curves. No warm tones. The amber accent is the
only thing that moves.

**The Bloom — "First Growth"**
Deep forest green primary, amber-gold bioluminescence for active biomass, dark
earth secondary. Units have visible vein structures that pulse gently during
idle. Nothing is angular. Everything breathes.

**The Mesh — "Live Network"**
Near-black primary structures, electric blue accent for active nodes and data
streams, deep violet secondary for inactive/dormant elements. Exposed conduit
lines run across all surfaces. The blue accents flicker in patterns that look
almost intentional.

---

## Tier 1 — Earned Palettes

Six earned palettes per faction. Permanent unlocks tied to specific gameplay
events. Subtle variations — same faction identity, shifted register.

### Shared unlock events (all three factions)

| Palette | Unlock condition | What shifts |
|---|---|---|
| **Veteran** | Complete first prestige | Slightly desaturated primary — worn, used, not new. |
| **Deep Cycle** | Complete fifth prestige | Darker overall, accent color deepens. The faction at a late hour. |
| **Convergence** | Complete a run with a second faction | Subtle secondary-faction color bleeds into the accent. An Architect who has played Bloom gets amber-green edges. The only cosmetic that visually references Option B — earned, never purchased. |

### Faction-specific earned palettes

**Architects**

| Palette | Unlock | What shifts |
|---|---|---|
| **Singularity** | Reach Architect milestone (first Nexus Core completion) | Accent shifts from amber to white-hot. Structures emit a barely-visible pulse. |
| **Efficiency Mark** | Survive 50 consecutive waves without any structure destruction | Primary brightens to clinical white. Perfect. Unmarked. |
| **The Long Build** | Accumulate 100 hours of total playtime as Architects | Primary shifts to very deep, almost black steel. Something that has been running for a very long time. |

**The Bloom**

| Palette | Unlock | What shifts |
|---|---|---|
| **Biosphere** | Reach Bloom milestone (60% map coverage) | Green deepens to near-black in primary; bioluminescence intensifies to compensate. |
| **After the Fire** | Survive an "Overrun" offline result and recover without forced prestige | Primary shifts to ash-grey and deep orange. Regrowth after burning. |
| **Old Growth** | Accumulate 100 hours of total playtime as Bloom | Color drains toward grey-green. Ancient. Bark-like. |

**The Mesh**

| Palette | Unlock | What shifts |
|---|---|---|
| **Mesh Control** | Reach Mesh milestone (hold 5 nodes for 60 seconds) | Accent shifts from blue to deep red. The network has turned. |
| **Clean Run** | Complete a wave tier without losing a single hacked node | Accent goes pure white on black. Signal-clean. No noise. |
| **Old Signal** | Accumulate 100 hours of total playtime as Mesh | Blue accents shift toward amber-warm. The Dreamer color bleeding in at the edges. |

---

## Prestige Cosmetics — Earned Effects

Between Tier 1 and Tier 2. Never purchasable. Pure achievement markers.

| Effect | Unlock | What it does |
|---|---|---|
| **Resonance Aura** | Prestige 3 | Structures emit a barely-visible field effect during wave defense. Faction-colored. Subtle. |
| **Fragment Glow** | Collect all 7 Ancient Fragments | Fragment collectibles have a faint glow on the player's HUD. Visible only to the player. |
| **The Mark** | Complete a run with all three factions | The three-circle containment stamp appears as a faint floor texture in the player's home base. No tooltip. No explanation. |

The Mark is the highest-prestige cosmetic in the game. Players who earn it
know what it means. No one who hasn't earned it does.

---

## Tier 2 — Sub-Path Variant Skins

Three skins, one per heresy path. Apply to the heresy path only; the standard
path retains its default or earned palette.

**Pricing: $4.99 each. $11.99 for all three (bundle ~20% off).**

---

### Spiritual-Tech — Architects Heresy Skin

**What changes:**
- Primary material shifts from steel-white to deep grey stone — the same
  low-albedo material as the Pilgrimage site.
- Ley-line power conduits replace amber electrical accents — slower pulse,
  amber-gold to deep green-gold, visible as surface veins on buildings.
- The Warden unit has visible root-anchor structures at its base.
- Structures at terrain-adjacent positions have a visible shimmer at contact
  points — the building drawing from the land.

**What doesn't change:** Silhouettes. Combat tell animations. UI faction marker.

**Tone:** The Architect who adapted to the place rather than installing
themselves in it.

---

### Assimilator — Bloom Heresy Skin

**What changes:**
- Primary color shifts from forest green toward deep teal-green — cooler,
  more electric.
- Visible integrated components on all structures — metal absorbed and
  partially digested, now part of the structure's surface. Exposed circuitry
  that the biomass has grown around and through.
- Bioluminescence shifts from amber-gold to bioluminescent blue-white.
- The Crucible-Hive has visible intake apertures — open, biological, clearly
  designed to receive and process material.

**What doesn't change:** The organic base is always visible. Silhouettes. UI
faction marker.

**Tone:** Unsettling in a way the Purist Bloom isn't. The Mesh, seeing this
skin on a Bloom unit, should feel something they cannot classify.

---

### Dreamer — Mesh Heresy Skin

**What changes:**
- The electric-blue accent shifts toward a warmer amber — as if the blue is
  a layer over something warmer underneath, and the underneath is showing.
- All structures have a faint secondary visual layer — a ghost-image of their
  pre-augmentation equivalent, barely visible.
- The Remembered unit has its two combat layers visible in the skin itself —
  present-day form in standard Mesh aesthetics, memory-layer in warm sepia,
  slightly offset, overlapping.
- Idle animations are slower than standard Mesh.

**What doesn't change:** The Mesh base is always the dominant layer.
Silhouettes. UI faction marker.

**Tone:** The Mesh at rest looks, in this skin, like something that used to
be something else.

---

## Tier 3 — Full Faction Reskins

Two reskins per faction, six total. Complete visual overhauls — different
material language, different color palette, different ambient effects — while
holding silhouette and readability rules absolutely.

**Pricing: $9.99 each. $24.99 per faction bundle (both reskins + ~20% off).
$59.99 all six (~25% off).**

---

### Architects

**"The Expedition" — Field Research Aesthetic**

Worn equipment. Patched structures. Steel-white has become off-white with
visible weathering, dark where joints have been repaired, brighter where new
components have been installed. *Used but maintained.* Accent shifts from
amber to muted gold. Power conduits look rerouted several times over.

This is the Architect who has been pursuing Ancient knowledge for so long they
stopped caring whether the base looks impressive.

---

**"Before the Schism" — Ancient-Adjacent Aesthetic** *(Option B resonance)*

Structures built from the same low-albedo dark stone as the Pilgrimage site.
Precise. Seamless. No tool marks. Scale is 15% too large — matching Pilgrimage
proportions. The game does not acknowledge this.

Accent is deep green-gold, not amber. Ley-line patterns visible on surfaces.

This is what the Architects look like if you ask: what did they look like
before they decided emotion was noise? The answer the skin proposes is that
they looked, once, more like the Pilgrimage site than like a factory.

No tooltip. No in-game text acknowledges any of this.

---

### The Bloom

**"Deep Ocean" — Bioluminescent Depth Aesthetic**

Primary shifts from forest green to deep blue-black. Bioluminescence becomes
the only light source — blue-white, brighter than the standard palette.
Structures look like deep-sea organisms. The Mother-Spire resembles a
deep-vent hydrothermal structure with bioluminescent fronds.

Strongest aesthetic distance from default while remaining unmistakably Bloom.

---

**"After the Canopy" — Dormant Season Aesthetic**

Ash-grey and deep rust-brown primary — dormant biomass, leaves shed, structures
contracted. Bioluminescence goes dark except at the very center of each
structure, where a small deep-amber pulse continues. Alive. Waiting.

The Bloom of deliberate restraint. Visually suggests a faction that has chosen
patience over growth.

---

### The Mesh

**"Old Network" — Pre-Augmentation Aesthetic** *(Option B resonance)*

Warm amber and deep copper primary. Exposed mechanical components that look
*built by hand* — visible fasteners, irregular surface texture, the aesthetic
of engineering before precision manufacturing. The cold blue is almost entirely
absent, replaced by incandescent warm light at nodes and connection points.

Structures look like they were built by something that had hands, made choices
about aesthetics, cared what things looked like. The standard Mesh does not
care. The Old Network skin remembers when it did.

The most directly Option B item in the entire cosmetic catalog. No tooltip.
No in-game text acknowledges any of this.

---

**"Dark Web" — Maximum Depth Aesthetic**

Near-total black primary. Blue accent shifts to deep ultraviolet — visible
but barely. Node connection points are intense white, like stars in a field.
Exposed conduit lines hidden behind smooth black surfaces. Whatever is running
in this network is not visible from the outside.

The Mesh that has decided visibility is a vulnerability.

---

## What Each Tier Communicates to the Player

| Tier | Signal | Player reading |
|---|---|---|
| Default palette | "I play this faction" | Identity: which faction did you choose |
| Earned palette | "I have played this faction long enough for this" | History: how deep have you gone |
| Prestige effect | "I have done something specific that most players haven't" | Achievement: what have you accomplished |
| Sub-path skin | "This is the version of this faction I believe in" | Conviction: which path did you commit to |
| Full reskin | "This is how I see this faction" | Interpretation: what does this faction mean to you |

---

## Hard Rules for Implementation

1. **Silhouette integrity.** Every skin approved only after a unit-recognition
   test: can a player identify all unit types at combat distance with no UI
   labels? If no, skin is rejected or modified.
2. **No skin degrades readability vs. default.** If a premium skin creates
   readability complaints post-launch, it gets patched.
3. **Earned cosmetics are permanent.** Cannot be reset by prestige. A player
   who earned the Convergence palette keeps it on all future runs.
4. **No limited availability.** No seasonal exclusives, no battle pass, no
   FOMO. Every item available at any time. Players who find this game in year
   three have access to everything year-one players had.
5. **The Option B reskins carry no tooltip or in-game acknowledgment of their
   lore significance.** The meaning is for players who earned it by playing,
   not by reading a store description.
