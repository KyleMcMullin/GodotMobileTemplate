# GodotMobileTemplate

A portrait mobile-game starter for **Godot 4.7.1** with menus, audio controls,
optional analytics, and Android service integrations.

## Start a project

1. Select **Use this template** on GitHub and open
   `godot-mobile-template/project.godot` in Godot 4.7.1.
2. Set your project name, icon, and version in Project Settings. Use a unique name
   so the game has its own save directory.
3. Set your privacy-policy and terms URLs in
   [`globals/app_config.gd`](godot-mobile-template/globals/app_config.gd).
   Replace the sample policy text, company splash, and credits.
4. Add your gameplay screens and configure the integrations you need below.
5. Run `./run_tests.sh` from the repository root.
6. Generate export presets through **Project → Export**. The included
   `export_presets.cfg` is a placeholder that must be configured before exporting.

## Features and customization

- **Menus:** splash, age-group entry, policy acceptance, Settings, Privacy,
  analytics preferences, deletion confirmation, and Credits.
- **Navigation:** register screens in `ScreenSwitcher.SCREEN` and `SCREEN_PATHS`.
  Use `switch_screen_transition()` to navigate and `go_back_transition()` to
  return. Add root screens to `ROOT_SCREENS` to reset navigation history.
- **Audio:** register tracks and effects in `AudioManager.SONG_ASSETS` and
  `SFX_ASSETS`. Settings persist master sound, music, and effects preferences.
- **Layout:** portrait 506 × 900 viewport with expanding canvas and touch emulation.
  Adapt layouts and safe-area handling to your game.
- **Input:** `DirectionalSwipe` detects four-way swipes. Instance
  `menus/components/masked_button.tscn` over custom visuals to define a tap target,
  then connect its `pressed` signal.

Paths above are relative to `godot-mobile-template/`.

## Mobile integrations

Bundled versions: **AdMob 5.1.0**, **Play Billing 3.3.0**, and
**Play Games Services 3.4.0**. PostHog uses a locally adapted integration.
Plugin licenses are included in `addons/`.

### Ads

Set your AdMob app IDs in Project Settings under
`admob/general/android/app_id` and `admob/general/ios/app_id`. Download matching
native packages through **AdMob → Android/iOS → Download & Install**.
AdMob requires iOS 15 or later.

The native `bin/` directories are ignored by default. Include the required
binaries in your repository or build pipeline before exporting with AdMob.

Add rewarded placements to `AdManager.REWARDED_AD` and `REWARDED_AD_UNIT_IDS`.
Pass an earned-reward callback to `show_rewarded_ad()` and connect
`rewarded_ad_unavailable` to your failure feedback. Desktop, development, and
purchased ad-free sessions grant the reward directly. Privacy includes a UMP
consent-management entry point when available.

### Purchases and Play Games

Register store products in `PlatformServices.PURCHASE` and `PURCHASE_STRINGS`,
then implement entitlement handling in `GooglePlayBilling`. The included
purchase handlers are scaffolding. iOS purchases and Game Center require
separate integrations.

Configure Play Games authentication and set your Game ID in
**Project → Export → Android → godot_play_game_services/game_id**. Register
achievement IDs, leaderboard IDs, and game-specific cloud snapshots in
`GooglePlayServices`. Built-in config sync transfers audio preferences only.

### Analytics and data deletion

Set your PostHog project API key and ingestion URL in `posthog.json`.
Analytics require opt-in; empty credentials send no events. Child sessions
cannot enable analytics or sign in through the template's account flow.

Connect `AdManager.user_data_deleting` to clear your game's save files and
in-memory state. The template clears its settings and analytics identifier,
retains purchase and age-group flags, and closes the app. It requests deletion
of known cloud snapshots when signed in, without verifying server completion.
Erasing events already stored by an analytics provider requires a separate
provider-side process.

## Tests

Requires Godot 4.7.1 and Python 3:

```bash
./run_tests.sh
GODOT_BIN=/path/to/godot ./run_tests.sh
```

The runner finds Godot on PATH or in the standard macOS app location. It imports
a fresh project copy and checks startup, navigation, audio, analytics guards,
and deletion using temporary save data. Existing saves are left untouched.

For additional tests, install gdUnit4 and add suites under `tests/unit/`:

```bash
./run_tests.sh res://tests/unit
```

## CI and releases

GitHub Actions runs the template checks on pushes and pull requests.
Deployment is disabled by default.

To enable store releases:

1. Complete [godot-ci's signing and store setup](https://github.com/KyleMcMullin/godot-ci/blob/main/SETUP.md).
2. Generate real export presets and configure the identifiers, Apple team,
   preset names, and project path in `.github/workflows/release.yml.example`.
3. Make the shared `godot-ci` workflow accessible to your repository, add its
   required secrets, and rename the example to `release.yml`.
4. Set repository variables `ENABLE_ANDROID_DEPLOYMENT` and/or
   `ENABLE_IOS_DEPLOYMENT` to `true` for configured platforms.

With releases enabled, pushes to `main` target Play internal/TestFlight;
`v*` tags target Play production/App Store review. Pin the shared workflow's
`uses` ref and `godot-ci-ref` input to the same tested revision for releases.

Keep the marketing version consistent across Project Settings, export presets,
and `version.json`. The shared workflow increments Android build numbers;
iOS build numbers must be set before release. `version.json` does not allocate
build numbers. `.circleci/config.example.yml` is inactive and requires separate
pipeline setup.

## References

[AdMob](https://github.com/poingstudios/godot-admob-plugin) ·
[Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) ·
[Play Games](https://github.com/godot-sdk-integrations/godot-play-game-services) ·
[PostHog](https://github.com/dudasaus/godot-posthog-analytics)

Godot splash artwork: [Kenney](https://github.com/KenneyNL/Godot-SplashScreens).
