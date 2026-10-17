# GodotMobileTemplate

Mobile starter for **Godot 4.7.1**, with portrait menus, mobile services and checks
that run on a fresh checkout. Updated October 16, 2026.

Bundled plugins: AdMob 5.0.0, Google Play Billing 3.3.0, Play Games Services 3.4.0,
and a locally adapted Godot PostHog Analytics integration. Plugin licenses live
in their addon directories.

## Start a new game

1. Choose **Use this template** on GitHub. Open
   `godot-mobile-template/project.godot` in Godot 4.7.1.
2. Change the project name, icon and version in Project Settings. A unique name
   also gives the game its own `user://` directory.
3. Set the privacy-policy and terms links in `globals/app_config.gd`. The splash
   screen and Privacy screen share those values. Replace the sample policy text,
   company splash and credits with your game's content.
4. Add screens to `ScreenSwitcher.SCREEN` and `SCREEN_PATHS`; register music,
   effects, purchases, achievements, leaderboard IDs and rewarded placements in
   their managers as needed. The dictionaries intentionally start empty.
5. Run `./run_tests.sh` from the repository root. No test addon is required.
6. Configure real export presets through **Project → Export** before exporting.
   The committed `export_presets.cfg` is an annotated placeholder.

The repository is already marked as a GitHub template. Keep that setting enabled
under **Settings → General → Template repository**.

## Included

- Age-group entry, policy acceptance, optional analytics consent and splash sequence.
  An interrupted analytics prompt is shown on the next launch. Child sessions
  cannot enable analytics or explicitly sign in through PlatformServices.
- Main Menu → Settings → Privacy, analytics preferences, data-deletion confirmation
  and Credits. Menus use scroll containers and 56-unit button heights.
- Persistent master sound, music and effects switches; music resumes when enabled.
- `ScreenSwitcher` with history, Android back navigation and a fade transition.
  Root screens clear history; repeated taps are blocked through the full reveal.
- Rewarded-ad callbacks with duplicate-load protection and an unavailable signal.
  A reward runs once, after earning it. Desktop/development and purchased ad-free
  sessions bypass inventory for local development.
- AdMob UMP consent flow, including `NOT_REQUIRED`, cached consent after an update
  error, and the privacy-options form. Dismissing a form does not repeatedly reopen it.
- Optional PostHog events: no identifier before opt-in, random UUIDs, IP-discard
  event property, bounded request timeouts and request-node cleanup. An empty API
  key sends nothing. Child sessions override any restored analytics preference.
- Google Play billing and games-service scaffolding. Cloud config sync includes
  **audio preferences only**; age, consent and purchase flags stay local.
- Portrait 506 × 900 viewport with expanding canvas, touch emulation,
  `DirectionalSwipe`, and `menus/components/masked_button.tscn` for an invisible
  tap target over separately drawn UI.

These are working starter screens, not a complete game. Add your own gameplay,
FTUE, accessibility options, safe-area treatment, pause/save lifecycle and visual
design according to the new game's needs.

## What came back from the games

This revision compares Layers, Tic Tac Glow and HueBlend. It brings back the
common settings/privacy/credits flows, interrupted-consent handling, analytics
UUID and IP settings, rewarded-ad guards, music unmute behavior and navigation
transition locking. It also fixes template-specific startup and data-wipe bugs.

Game-specific stats, player profiles, idle economy, tutorials, art and paywalls
remain in their games. HueBlend's RevenueCat integration is an option for a game
that needs cross-platform purchases; it is not a dependency of this template.

## Tests

Requires Godot 4.7.1 and Python 3. The runner finds `godot` on PATH or the standard
macOS app; set `GODOT_BIN` for another location.

```bash
./run_tests.sh
GODOT_BIN=/path/to/godot ./run_tests.sh
```

Every run imports a fresh copy of the project and checks startup, child analytics
blocking, deletion preserving only purchase/age flags, audio unmute, screen
loading, back history and rapid transition taps. Runtime/resource errors fail
checks even when Godot exits with status zero.

Tests use a unique temporary save directory, verify its location before test
writes, and remove it afterwards. They do not move, overwrite or delete real
save data. The editor import may update Godot's normal editor settings.

For game-specific tests, optionally install gdUnit4 and put suites in
`tests/unit/`. They run after the template checks:

```bash
./run_tests.sh res://tests/unit
```

## CI and deployment

GitHub Actions runs the same fresh-import and regression checks on pushes and
pull requests. **Deployment is off by default**, so a new template-derived repo
can pass checks without store accounts, signing keys or CircleCI.

When ready to ship:

1. Complete [godot-ci's account and signing setup](https://github.com/KyleMcMullin/godot-ci/blob/main/SETUP.md).
2. Generate real Android/iOS export presets. Set the package/bundle identifiers,
   Apple team, preset names and project path in `.github/workflows/ci.yml`.
3. Add the secrets listed in [godot-ci](https://github.com/KyleMcMullin/godot-ci).
4. Set the repository variable `ENABLE_ANDROID_DEPLOYMENT` and/or
   `ENABLE_IOS_DEPLOYMENT` to the string `true` only for configured platforms.

The optional release job uses the published shared Actions workflow. With a
platform enabled, `main` deploys to Play internal/TestFlight and `v*` tags deploy
to Play production/App Store review. Pull requests never deploy. The shared
workflow is referenced at `main`; pin both its `uses` ref and `godot-ci-ref` input
to a tested revision before relying on it for releases.

**The local CircleCI split is not published upstream.** `.circleci/config.example.yml`
is retained as an inactive starting point (copy it to `config.yml` only after
finishing the upstream setup). The published reusable workflow does
not accept `android-runner`, `ios-runner` or `circleci-project-slug`; this caller
therefore does not pass them. Publish and validate that shared workflow and orb
before activating CircleCI or platform-specific release tags.

`version.json` is starter metadata, not an active build allocator. Keep its
marketing version aligned with `application/config/version` and the export
presets. The currently published workflow bumps Android's `version/code`; iOS
build numbers still need to be set before release. Do not assume the unpublished
split-runner allocation scripts run here.

## Configure mobile integrations

- **AdMob:** set your app IDs in Project Settings under
  `admob/general/android/app_id` and `admob/general/ios/app_id`. Download native
  binaries using **AdMob → Android/iOS → Download & Install**. Their addon-local
  `.gitignore` files exclude `bin/`; commit the required binaries explicitly or
  supply them in your build pipeline. Otherwise disable the integration for export.
  Add real rewarded-unit IDs to `AdManager.REWARDED_AD_UNIT_IDS`; connect
  `rewarded_ad_unavailable` to the relevant user feedback.
- **Play Games:** follow the plugin's authentication setup and put the Game ID in
  **Project → Export → Android → godot_play_game_services/game_id**. Register
  achievements, leaderboards and game-specific cloud snapshot names. iOS Game
  Center is not implemented by this template.
- **Purchases:** register products in the store and implement entitlement handling
  in `GooglePlayBilling`. Its purchase handlers are examples, not a finished
  purchase-verification system. iOS purchases require a separate integration.
- **PostHog:** put a project API key and ingestion URL in `posthog.json` if used.
  Analytics remain optional and empty credentials send no events.
- **Deletion:** the template clears its config and analytics identifier while
  preserving the local purchase and age-group flags. Connect
  `AdManager.user_data_deleting` to clear game-specific files and in-memory state.
  Deletion of known cloud snapshots is requested when authenticated; the bundled
  plugin provides no deletion-completion signal, so server completion is not
  verified. Deleting the local identifier does not erase events already held by
  an analytics provider; implement that provider-side process if needed.

The age threshold and parental math component are starter behavior; choose the
appropriate product policy and replace sample text before release.

Plugin documentation:
[AdMob](https://github.com/poingstudios/godot-admob-plugin),
[Play Games](https://github.com/godot-sdk-integrations/godot-play-game-services),
[Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing),
[PostHog](https://github.com/dudasaus/godot-posthog-analytics).
Godot splash artwork: [Kenney](https://github.com/KenneyNL/Godot-SplashScreens).
