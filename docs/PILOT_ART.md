# Pilot portrait assets

Six original portraits were generated with the built-in image generation tool, one call per pilot. No external reference images were supplied. The selected source PNGs were preserved; the app bundles 384×384 WebP copies at quality 0.88, prepared with Godot’s image pipeline. No face or composition edits were made.

## Assets and subjects

- [`assets/pilots/rookie.webp`](../assets/pilots/rookie.webp): Vale, a seasoned woman flight leader in her forties, short dark hair with a silver streak, olive skin, steady brown eyes, small healed eyebrow scar, worn navy flight collar with a muted teal shoulder panel.
- [`assets/pilots/ace.webp`](../assets/pilots/ace.webp): Vega, a male ace pilot in his late twenties, tan skin, short wavy dark hair, lively dark eyes, relaxed confident half-smile, worn navy flight collar with a restrained amber shoulder panel.
- [`assets/pilots/engineer.webp`](../assets/pilots/engineer.webp): Patch, a Black woman engineer in her fifties, cropped natural silver-black hair, thoughtful brown eyes, friendly practical expression, slim repair headset at one ear, worn navy work-flight collar with muted mint shoulder panel.
- [`assets/pilots/hunter.webp`](../assets/pilots/hunter.webp): Orion, an East Asian male hunter pilot in his forties, close-cropped black hair, light stubble, calm watchful eyes, old small cheek scar, worn navy flight collar with muted copper shoulder panel.
- [`assets/pilots/scavenger.webp`](../assets/pilots/scavenger.webp): Scrap, an adult freckled red-haired salvage pilot in their thirties, fair skin, short tousled copper hair, crooked grin, a small utility ear radio, worn navy patched flight collar with muted ochre shoulder panel.
- [`assets/pilots/tactician.webp`](../assets/pilots/tactician.webp): Nyx, a South Asian woman tactician in her thirties, dark brown skin, black hair pulled back with one side closely cut, clear focused eyes, composed expression, worn navy flight collar with restrained violet shoulder panel.

## Shared prompt

Replace `{subject}` with the corresponding subject above, without its final period. This reconstructs each final generation prompt.

Use case: stylized-concept. Asset type: a single square pilot portrait for the StarRun space combat game, readable as a small 64px menu avatar. Primary request: {subject}. Style: grounded painted science-fiction game portrait, confident angular brushwork, clearly human expressive face, detailed but not photoreal, slightly weathered material texture, consistent with illustrated metallic spacecraft. Composition: one person only, tight head and upper-shoulder crop, full top of head visible, face centered and large, eyes at upper third, near-frontal slight three-quarter turn. Plain very dark navy background. Soft warm face light with subtle cool teal edge light. Strong readable facial planes, restrained saturation, no neon fog, no glamorous fashion styling, no exaggerated cartoon proportions. The face must be fully unobscured: no helmet, mask, visor or face-covering gear. No text, letters, numbers, logos, frame, insignia or watermark.

All requests used an opaque background (`transparent_background: false`). The portraits were visually reviewed together and in the phone menus. `scripts/pilot_portrait.gd` provides the shared frame and passes input through to the card so a held drag still scrolls.
