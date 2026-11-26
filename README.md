# GymBlox

GymBlox is an offline training journal for iOS 16.0 and later, designed for a 375 × 667 pt iPhone display.

## Workout and diet

Workout and Diet share a calendar from November 25 through December 24, 2026. Quick workout opens an empty session. New workout lets you name one. Tap a preset in Add exercise or enter a custom name. New exercises start with two target sets. Tap a weight to edit, a circle to mark a set performed, or an exercise header to collapse it. Finished workouts stay on their date. Duplicate to Today creates a fresh set of targets. Settings holds exercise presets and workout defaults.

Under **Diet → Food**, tap a saved meal to log it, or use **Quick add**. Swipe a logged row to delete it. **Cardio** shows steps and custom sessions for the selected day. Profile holds body measurements and daily targets. Net calories equal food intake minus estimated step and cardio calories.

Core Motion supplies daily steps on supported iPhones with Motion & Fitness access. On foregrounding, GymBlox reads complete local calendar days within the pedometer’s rolling seven-day history and subscribes to today’s updates. Recorded days remain in the journal. A dash indicates a missing measurement. Step burn uses an estimate of 0.0005 kcal per kilogram per step. Each cardio session stores its MET, duration and weight at logging. Cardio calories equal MET × weight in kg × hours. Step and session estimates are additive, so walking recorded by both contributes to both totals.

## Spotify setup

1. In the Spotify Developer Dashboard, enable the iOS SDK and register `gymblox://spotify-login-callback`. On the installed iPhone app, tap **Music → Bundle ID → Copy** and register that exact iOS bundle identifier. Settings also exposes the signed identifier.
2. Set the public client ID in `SPOTIFY_CLIENT_ID` in `project.yml`, regenerate with XcodeGen and build. The app reads the expanded `SpotifyClientID` from its Info.plist.
3. Sign in to Spotify on the iPhone. Tap **Music → Connect Spotify** and approve access. Music shows the current track, playback controls and SDK errors. Use **Open Spotify** to launch Spotify directly.
4. Download a playlist inside Spotify. Under **Music → Downloaded playlists**, add a name and its `spotify:playlist:…` URI to launch it in one tap.

GymBlox keeps the access token in memory and reconnects when it becomes active. After restarting the app, use Connect Spotify again. [Spotify iOS setup](https://developer.spotify.com/documentation/ios/getting-started)

## Build and run on a Mac

1. Copy this directory to a Mac with Xcode 16 or later and an installed iPhone Simulator runtime compatible with that Xcode. Open Xcode once to finish installing its components.
2. Install XcodeGen. With Homebrew, run `brew install xcodegen`. [XcodeGen](https://github.com/yonaskolb/XcodeGen)
3. In Terminal, change to the directory containing `project.yml` and run the following commands.

   ```sh
   xcodegen generate
   open GymBlox.xcodeproj
   ```

4. Select the **GymBlox** scheme and an iPhone Simulator. Allow Xcode to resolve the pinned Spotify package while online. Build and run with **⌘R**. A blank `SPOTIFY_CLIENT_ID` is supported for journaling.
5. For an iPhone, set the app's `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to a unique identifier and regenerate. In **Signing & Capabilities**, choose your development team. Select the connected iPhone as the run destination and run the app. Keep any long-term signing changes in the project specification so they survive regeneration.

## Build on GitHub and install from Windows

1. Push this source, including `.github/workflows/build.yml`, to your GitHub repository. A push starts the build automatically. To rebuild the default branch, open **Actions → Build GymBlox IPA → Run workflow**.
2. Open the successful run, download **GymBlox-unsigned** from **Artifacts**, and extract the downloaded ZIP to get `GymBlox.ipa`. The workflow builds the Release iPhone app without signing, checks for iOS 16.0 and ARM64, and packages the complete app bundle under `Payload/GymBlox.app`. [GitHub workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
3. Install Sideloadly and the Windows versions of iTunes and iCloud linked by Sideloadly. Connect and unlock the iPhone 8 by USB, accept **Trust This Computer** if prompted, and select the phone in Sideloadly. [Sideloadly for Windows](https://sideloadly.io/)
4. Drag `GymBlox.ipa` into Sideloadly, enter your Apple Account, and select **Start**. Complete any account verification prompts. Sideloadly signs and installs the app using your account.
5. If prompted, enable **Settings → Privacy & Security → Developer Mode** and confirm after the restart. Trust the developer account under **Settings → General → VPN & Device Management** if prompted, then open GymBlox. A free Apple Account generally requires refreshing the signature every seven days. Keep the same Apple Account and app identifier for updates. [Sideloadly FAQ](https://sideloadly.io/faq.html)

## Storage and verification

The app writes `Application Support/Setline/journal.json` atomically and publishes changes after each successful write. Existing workouts, sets, meal logs, day-specific targets and tasks carry forward. Existing routine exercise names seed the preset picker on upgrade.

Run `python scripts/generate_icon.py` with Pillow to reproduce the opaque RGB icon catalog. The macOS workflow builds for an iOS 16.0 minimum, checks the compiled icon metadata, Home Screen PNG, Assets.car and ARM64 executable, then packages the app. Its simulator job runs JournalTests and RecoveryUITests on a 375 × 667 pt iPhone SE simulator. To run the tests locally, open the generated project, choose the GymBlox scheme and press **⌘U**.

On a physical iPhone, check the signed icon on the Home Screen, approve Motion & Fitness access, compare daily step totals, and complete a Spotify app switch. These checks require device data or installed apps.
