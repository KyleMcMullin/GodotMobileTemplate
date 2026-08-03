# GodotMobileTemplate

## LAST UPDATED: 12/15/2025 - Godot v4.5.1

> **This repo must be marked as a Template repository** in Settings → General →
> check "Template repository", or the "Use this template" button will not appear.

A template designed to make starting mobile games with Godot much easier. This template provides several utils and helpful starter things to minimize initial setup and avoid spending time writing boiler plate code.

Key features:

- Prompting for T&C/Policies, saving acceptance to user config
- Customizable splash screen with Godot Logo
- Audio Manager supporting SFX and Music, Muting/Unmuting Sound/FX/Music separately and saving that to persist on app close
- SceneSwitcher that allows for easy screen switching/registration. Supports a TransitionScreen that defaults to fade in/out but can be customized
- AdManager util that sets up everything needed to server ads using Poing Godot AdMob plugin including UMP. Includes default setup for adding ad free
- GooglePlayBilling util that sets up/gives examples for purchase on the Google Play Store
- GooglePlayServices util that sets up/gives examples for GooglePlayServices like signing in, snapshot saving, achievements and leaderboards
- PlatformServices util that obscures generalizes functionality for multiple platforms to support android and IOS. Basically takes function calls and routes them to the correct services
- Adjust project settings for mobile including turning off quit on go back, emulating mouse/touch from each other, viewport width/height, portrait mode, stretch resizability, HDR 2D, and a few other helpful things for mobile
- Includes PostHog implementation for analytics that is hooked up to many areas of the app already. By default uses anonymous events and saves device/OS info. Can be enabled or disabled.
- DirectionalSwipe util that gives left/right/up/down swipes in a way that feels natural

While this example lays the foundation for resizability, it will not handle all of that on its own. Control nodes should be quite easy but anything beyond that may require additional development/configuration to get working correctly, check out the Godot docs for that.

## CI/CD — starting a new game

Every game made from this template is born with a working build pipeline. The
pipeline logic itself is **not** in this repo — it lives in
[**godot-ci**](https://github.com/KyleMcMullin/godot-ci) and is referenced live by
`.github/workflows/ci.yml`. "Use this template" copies files once with no link back,
so anything copied here would go stale immediately; keeping the logic in `godot-ci`
means a fix there applies to every game, including ones created long ago.

### Steps

1. Click **Use this template** → create your repo.
2. Edit `.github/workflows/ci.yml`: set `android-package-name`, `ios-bundle-id`,
   `ios-team-id`, and the preset names.
3. Open the project in Godot and regenerate `export_presets.cfg`
   (Project → Export). The committed one is an annotated placeholder, not a working
   config — read its header.
4. Add the repo secrets listed in
   [godot-ci's README](https://github.com/KyleMcMullin/godot-ci#secrets).
5. Open a PR to check the plumbing — PRs run tests only — then push to `main`.

### What runs when

| Trigger | Result |
|---|---|
| Pull request | Tests only. Never exports, never deploys. |
| Push to `main` | Test → export → Play **internal** track + **TestFlight**. |
| Push tag `v*` | Test → export → Play **production** + **App Store review**. |

`enable-ios` ships as `false`. Leave it that way until Apple enrollment and signing
are done, or every push to `main` will fail on the iOS job.

### Tests

Testing uses **gdUnit4**. `./run_tests.sh` at the repo root runs the suite, and CI
runs that same script — so local and CI results always agree.

```bash
./run_tests.sh                    # whole suite
./run_tests.sh res://tests/unit   # a subset
```

gdUnit4 is not bundled with this template. Until you install it (Godot → AssetLib →
"gdUnit4") and add a `tests/` folder, the script skips and CI stays green. The script
stashes your real `user://` save data before running and restores it afterwards, so
tests never clobber your local game state.

**Before any deploy can work**, you need store accounts, a keystore, API keys and app
listings. That is a one-time, multi-day process (Apple enrolment alone takes 24–48h).
Work through
[godot-ci/SETUP.md](https://github.com/KyleMcMullin/godot-ci/blob/main/SETUP.md).

For the full pipeline explanation, inputs, secrets table, and known first-run rough
edges, see [godot-ci's README](https://github.com/KyleMcMullin/godot-ci#readme).

## IMPORTANT NOTES

Anything in the addons folder comes from plugins that have their own licenses. Depending on the last time this template was updated, implementations may have changed drastically. When loading up the project for the first time I highly suggest viewing each plugin's documentation for any changes, as well as to get the latest version with any improvements. THESE WILL ALL HAVE ADDITIONAL SETUP TO DO. This may be things like setting up accounts and connecting IDs to the plugins. I will list them here with links

- [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin)
- [Godot Play Game Services](https://github.com/godot-sdk-integrations/godot-play-game-services)
- [Godot PostHog Analytics](https://github.com/dudasaus/godot-posthog-analytics)
- [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing)

Key elements that will need to be done for plugins to work. This list is not exhaustive, again, read the documentation, please

- Setup auth for Google Play Services following instructions on GitHub
- Put your Game ID in the Godot Play Game Services tab on the bottom menu
- Create a PostHog app and copy your api key into posthog.json
- Create an admob account, make sure you practice with test ads from the plugin documentation.
- Install android build templates/binaries/everything needed to export. Make sure to put any relevant plugin folders into the android folder (see admob documentation)
- Create app on google play console and do any necessary setup there for billing like adding your purchase options
- Add leaderboards/achievements in google play console

Godot Splash Screen Image comes from [KenneyNL Godot-SplasheScreens](https://github.com/KenneyNL/Godot-SplashScreens/tree/main)
