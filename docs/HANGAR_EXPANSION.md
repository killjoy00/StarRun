# Expanded Hangar and pilot roster — v0.8.1

The Hangar grows from 22 to **38 refundable upgrade tracks**. Existing prices,
purchases and refunds are unchanged. New tracks start at zero in old profiles and
saved flights; buying one applies to the next flight, as with existing upgrades.

| Group | Upgrade | Effect per rank | Ranks | First cost / increase |
|---|---|---|---:|---:|
| Hull | Ablative panels | 3% less beam, missile and mine damage | 4 | 12 / 5 |
| Hull | Restart circuit | Shield-break recovery 0.2 seconds sooner | 4 | 12 / 5 |
| Hull | Sealed systems | Status effects last 5% less | 4 | 14 / 5 |
| Hull | Docking crew | Repair 4% more maximum hull between worlds | 3 | 14 / 7 |
| Weapons | Charged coil | Start with one extra Arc Coil rank | 1 | 35 / 0 |
| Weapons | Lance mount | Start with rank-1 Lance | 1 | 40 / 0 |
| Weapons | Siege targeting | 3% more automatic damage to bosses and parts | 5 | 14 / 6 |
| Weapons | Warhead tooling | 5% more Seeker damage | 4 | 12 / 5 |
| Abilities | Pilot drills | One extra starting signature-ability rank | 2 | 16 / 10 |
| Abilities | Field patch kit | Repair 1 hull on an ability use | 3 | 18 / 8 |
| Abilities | Hot start | First use of each ability per world has 10% less cooldown | 3 | 18 / 8 |
| Tactics | Focused uplink | Rerolls include an owned upgrade when eligible | 1 | 35 / 0 |
| Tactics | Banish relay | Regain one removal on entering a new world | 2 | 20 / 12 |
| Tactics | Repair stores | Draft skips repair 6 extra hull | 3 | 8 / 4 |
| Salvage | Component salvage | One extra base core per destroyed boss part | 3 | 18 / 8 |
| Salvage | Clean contract | Three extra base cores for clearing above 60% hull | 3 | 18 / 8 |

Focused uplink respects max ranks, removed tracks, fused components and world
eligibility. It does not add another reroll or duplicate a card. Hot start is
spent separately for each equipped ability and retained across saves. Damage
reductions multiply with the existing passive reductions. Pilot drills caps the
starting signature at rank 3, so it does not bypass the rank-5 fusion requirement.
Core bonuses use the existing payout multipliers.

## Two active draft options

**Wing Drones** launches two escorts for six base seconds. They aim and fire
independently every half second. Further ranks increase damage and duration;
rank 5 adds a third escort and rank 10 adds a fourth. Its base cooldown is 18
seconds.

**Ion Mine** places a charge near the closest enemy. It arms briefly, then
explodes on proximity or after 1.8 seconds, damaging nearby enemies and clearing
shots in its radius. Rank 5 expands the radius from 150 to 190; rank 10 deploys
two charges. Its base cooldown is 15 seconds. It needs no manual aiming.

When both reach rank 5, **Storm Carrier** combines them into four escorts and
three mines on one button, freeing a slot. It has its own icon and cast effect,
22-second base cooldown and direct fused upgrade track. The two consumed tracks
leave future offers. The full pool now has **22 base actives and 11 fusions**.
Armed mines, drone cadence and first-cast bonuses survive saves; transient
support clears on warp. Friendly drones, mines and blasts render below hostile
shots and beam warnings in normal and reduced-effects modes.

## Pilot faces

All six pilots have individual painted face portraits. They appear in pilot
selection and the equipped-pilot area of the main menu. Portraits allow input to
pass through to the surrounding card, preserving hold-and-drag scrolling.
Bundled 384-pixel WebP copies keep the six assets below 200 KB combined.
The [art notes and generation prompts](PILOT_ART.md) record the source artwork.

## Validation

Focused mechanics checks exercise actual damage, status duration, cooldowns,
healing, rerolls, rewards, support projectiles and save/warp behavior. The full
simulation suite also covers every active and every fusion. Rendered phone checks
include all five expanded Hangar categories, the last pilot and upgrade rows,
normal/reduced fusion effects, and hostile cores overlapping escorts and mines.
Touch tests begin a held drag directly on a pilot's face.

The six fixed-loadout world checks remain clearable with new permanent upgrades.
At full Hangar, boss fights lasted 42.7, 53.2 and 45.0 seconds in worlds 2–4;
incoming damage was 201.6, 725.2 and 887.3. This is one deterministic seed per
profile/world, not a human win-rate estimate. World damage and health curves
from v0.8.0 are unchanged.

With the expanded active pool, the 24-seed natural-draft Stage 1 benchmark cleared
12/24 with abilities unused, 19/24 with cooldown spam and 16/24 with the timed
pilot. Mean ending hull was 44.5, 86.4 and 79.5 respectively. These pilots also
receive different drafts because combat and draft share RNG, so those numbers
do not isolate timing. The unchanged fixed-equipment Hard boss comparison still
cleared 5/24 with cooldown spam (8.7 mean hull) and 24/24 with timed counters
(98.9 mean hull). The existing survival and controlled timing gates pass.

Adding a rank-5-pair Storm Carrier to the world-4 fixtures shortened those boss fights to 52.4 seconds at half Hangar and 37.3 seconds at full Hangar. Both cleared; the full-Hangar fixture still received 650.7 damage during the world.

## 2026-11-16 Hangar price adjustment

The table above records original v0.8.1 introduction prices. Future purchases are about **15% more expensive**, rounded up to whole Cores (Hull plating 5 → 6; Lance mount 40 → 46). Existing ranks remain installed. On loading an older profile, the game records the historical prices of owned ranks, so Refund All returns the Cores actually paid. Newly purchased ranks refund their updated price. Ship and pilot unlocks do not change.
