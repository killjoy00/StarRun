# The Silent Archive

In a regular flight, the receiver picks up a seed-timed transmission in Worlds 2–4. Recover two coordinates in the same flight to reveal the Silent Archive after defeating the Void Regent.

- **Tune the receiver.** Wait for **Cast now** and use any ready ability. The window repeats for 52 seconds.
- **Intercept the courier.** The autopilot prioritizes the marked courier. Destroy it within 24 seconds to recover its coordinates.
- **Ignore the signal.** Leave the run on its usual course. An ignored or missed signal can be replaced by a later one.

The post-Citadel transmission offers **Finish campaign**, **Play Endless**, and **Enter the Silent Archive**. The Archive earns its own ending and the local **Open Frequency** achievement. Entry banks the four-world victory and payout. Archive enemies award no XP or Cores. Daily flights never receive the transmissions or the alternate route.

## Combat

Relay patrols lose their coordinated volleys when the relay falls. The Archive's lock projects a danger lane. Use any active during a warning to cancel it. The Last Custodian now has more than twice its original HP and a heavily shielded core. It takes reduced damage when sealed and opens for roughly four seconds after an ability interrupts a warning; ignoring the warning opens it for under two seconds instead. Its three phases change from an aimed beam to a converging lattice and finally a combined attack. **Each new phase requires surviving 16 seconds of rearming and more dangerous projectile volleys** instead of immediately chaining locks. Builds using any ship signature can interrupt, so preserve a ready ability rather than spending everything on cooldown. The HUD shows the current phase, exposed/sealed state, and time until the next lock. This combat is deliberately much harder, but it still has no new XP or Cores.

## Verification

```sh
godot --headless --script tests/archive_campaign.gd -- \
  --ship=arcwing --pilot=rookie --difficulty=normal --matched --require-win --min-boss-seconds=30
```

Omit the ship, pilot, and difficulty filters to exercise the full matrix. Matched runs compare timing with immediate cooldown use from the same World 4 clear, with the same ship, pilot, draft, and seed. The playable workflow captures the signal choice, reveal, arrival, patrol, Custodian introduction and lock, and epilogue in the three viewport sizes.
