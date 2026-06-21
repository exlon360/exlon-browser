# Magnet Simulator

Magnet Simulator is a SwiftUI and SceneKit iOS app for exploring a 3D magnetic sandbox.

## Included Magnet Types

- Bar magnet
- Horseshoe magnet
- Ring magnet
- Disk magnet
- Cube magnet
- Sphere magnet
- Neodymium block
- Solenoid
- Electromagnet
- Halbach array
- Flexible magnetic sheet
- Compass needle
- Ferrofluid
- Magnetic gel

## Controls

- Scenario picker for catalog, gel lab, electromagnet, Halbach, and compass views.
- Active magnet picker for focusing one magnet type in the catalog scene.
- Strength, current, gel viscosity, field density, and motion sliders.
- Field lines, magnetic gel, compass grid, and force-arrow toggles.
- Polarity flip, field pulse, pause, and reset actions.

## GitHub IPA Build

Run the `Build Magnet Simulator IPA` workflow on GitHub, or push a tag like:

```bash
git tag magnetsim-v0.1.0
git push origin magnetsim-v0.1.0
```

The workflow produces `MagnetSimulator-unsigned.ipa`.

Unsigned IPAs still need Apple signing before installing on a real iPhone.
