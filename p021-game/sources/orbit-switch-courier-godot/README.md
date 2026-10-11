# GAME-G030 Orbit Switch Courier（軌道切替配送）

GAME-069 implements the first playable Godot 4.7.2 Web build from the GAME-068 design spec.

## Core loop

- One-action timing game: tap / click / Space.
- The courier circles one of three orbital lanes automatically.
- Act near a transfer bridge to switch to the adjacent orbit.
- Act near a HUB to deliver the current cargo. Cargo uses both color and shape labels.
- Acting outside a valid timing window, delivering to the wrong HUB, or letting the cargo timer expire costs ENERGY.
- 90 second run, ENERGY 3.
- 3 successful deliveries in a streak activates Combo x2; 5 activates x3.
- Score combines deliveries, combo multiplier and remaining cargo time.
- Local BEST is stored in browser localStorage (with a user:// fallback outside Web).
- Synthesized SFX with SOUND ON/OFF.
- RESULT and immediate retry flow.

## Controls

- Touch / click / Space: start, transfer, deliver, retry.
- M: sound toggle.
- R: reset run.

## Responsive QA

The build is checked at:

- Phone Portrait 390x844
- Phone Landscape 844x390
- Tablet Portrait 768x1024
- Tablet Landscape 1024x768

The QA bridge is available only for deterministic browser verification through ?qa=1.

## Public URL

https://kobitworks.github.io/autoai_poc/p021-game/games/orbit-switch-courier/

## Quality score target

Target: **84/100**

- Game feel: 9
- Controls: 9
- Difficulty: 8
- UI/UX: 9
- Graphics: 8
- Effects: 8
- Sound: 7
- Content / variation: 8
- Replayability: 9
- Technical quality: 9

The game uses original vector-style Godot drawing and synthesized audio only; no paid or externally licensed game art is required.
