# SKYBOUND - Godot 10-second cinematic

Godot 4 source for the SKYBOUND cinematic flight PoC.

## Scene timeline

- 0.0-2.0s: dawn establishing shot on the cliff
- 2.0-5.2s: heroine launches and catches the updraft
- 5.2-8.6s: auto-pilot flight over clouds, ruins and the valley
- 8.6-10.0s: camera pulls back toward the sunrise and fades out
- At 10.0s the scene loops automatically

Tap/click the scene or press Space to restart from 0.0s.

## Design goals

- No gameplay input required
- Lightweight procedural scenery for Web/mobile
- Responsive canvas stretch for phone/tablet portrait and landscape
- GL Compatibility renderer for Godot Web
- No runtime network dependency

Open `project.godot` in Godot 4 and run the main scene.
