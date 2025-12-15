# GodotMobileTemplate

## LAST UPDATED: 12/15/2025 - Godot v4.5.1

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
