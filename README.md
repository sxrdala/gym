# Setline

A native iPhone strength journal for iOS 16.0 and later, including iPhone 8. Start from a routine or an empty quick workout. Between sets, adjust the load and reps with your thumb, tap **Log Set**, and use the exercise chips to switch lifts. The Today tab holds your checklist and a **Resume Active Workout** button whenever a workout is open.

## Build and run on a Mac

1. Copy this directory to a Mac with Xcode 16 or later and an installed iPhone Simulator runtime compatible with that Xcode. Open Xcode once to finish installing its components.
2. Install XcodeGen. With Homebrew, run `brew install xcodegen`. [XcodeGen](https://github.com/yonaskolb/XcodeGen)
3. In Terminal, change to the directory containing `project.yml` and run the following commands.

   ```sh
   xcodegen generate
   open Setline.xcodeproj
   ```

4. Select the **Setline** scheme and an iPhone Simulator. Allow Xcode to resolve the pinned Spotify package while online. Build and run with **⌘R**. A blank `SPOTIFY_CLIENT_ID` is supported for workouts, routines, tasks, and history.
5. For an iPhone, set the app's `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to a unique identifier and regenerate. In **Signing & Capabilities**, choose your development team. Select the connected iPhone as the run destination and run the app. Keep any long-term signing changes in the project specification so they survive regeneration.

## Build on GitHub and install from Windows

1. Push this source, including `.github/workflows/build.yml`, to your GitHub repository. A push starts the build automatically. To rebuild the default branch, open **Actions → Build Setline IPA → Run workflow**.
2. Open the successful run, download **Setline-unsigned** from **Artifacts**, and extract the downloaded ZIP to get `Setline.ipa`. The workflow builds the Release iPhone app without signing, checks for iOS 16.0 and ARM64, and packages the complete app bundle under `Payload/Setline.app`. [GitHub workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
3. Install Sideloadly and the Windows versions of iTunes and iCloud linked by Sideloadly. Connect and unlock the iPhone 8 by USB, accept **Trust This Computer** if prompted, and select the phone in Sideloadly. [Sideloadly for Windows](https://sideloadly.io/)
4. Drag `Setline.ipa` into Sideloadly, enter your Apple Account, and select **Start**. Complete any account verification prompts. Sideloadly signs and installs the app using your account.
5. If prompted, enable **Settings → Privacy & Security → Developer Mode** and confirm after the restart. Trust the developer account under **Settings → General → VPN & Device Management** if prompted, then open Setline. A free Apple Account generally requires refreshing the signature every seven days. Keep the same Apple Account and app identifier for updates. [Sideloadly FAQ](https://sideloadly.io/faq.html)

## Optional Spotify setup

1. Create a Spotify developer app, enable the iOS SDK, enter the same iOS bundle identifier used for signing, and register the exact redirect URI `setline://spotify-login-callback`. Copy its public client ID. [Spotify iOS setup](https://developer.spotify.com/documentation/ios/getting-started)
2. Put the client ID in the app target's `SPOTIFY_CLIENT_ID` setting in `project.yml`. Run `xcodegen generate` again and rebuild. The app reads the expanded value from `SpotifyClientID` in its Info.plist.
3. The project already links the `SpotifyiOS` product through Swift Package Manager at the v5.0.1 release commit. Its package wraps `SpotifyiOS.xcframework` and exports the module imported by the app. Check **Setline → General → Frameworks, Libraries, and Embedded Content** for the linked product. The app target includes the `-ObjC` linker flag. [Pinned package manifest](https://github.com/spotify/ios-sdk/blob/v5.0.1/Package.swift)
4. In **Setline → Info**, verify **Queried URL Schemes** includes `spotify` and **URL types → URL Schemes** includes `setline`. These entries are supplied by the checked-in `Setline/Info.plist`. Changing the callback requires matching changes in the plist, `SpotifyManager.redirect`, and the dashboard registration.
5. On the iPhone, install a compatible Spotify version and sign in. The current App Store version requires iOS 16.1 or later. On iOS 16.0, playback controls require a compatible Spotify version already available on the device. [Spotify App Store compatibility](https://apps.apple.com/us/app/spotify-music-and-podcasts/id324684580)
6. Tap the headphones on Today or in the workout player and select **Connect Spotify** while online. Approve access and return to Setline. In Spotify, enable **Download** on your playlist and wait for the download to finish.
7. Start the playlist and return to the workout. The player follows Spotify's title, artist, and playback state. Setline keeps the access token in memory for the current app process. After a cold launch, use **Connect Spotify** to re-establish the handoff. Spotify manages the account grant and offline media. [Spotify App Remote](https://github.com/spotify/ios-sdk/tree/v5.0.1)

App Remote disconnects when Setline becomes inactive and reconnects on foregrounding with an available token. If the handoff fails or a foreground connection takes longer than eight seconds, the player falls back to **Open Spotify**. A missing Spotify installation produces an inline message. Setline leaves audio-session management to Spotify. [Spotify lifecycle guide](https://developer.spotify.com/documentation/ios/concepts/application-lifecycle)

## How workout recovery works

The app stores a Codable journal snapshot at `Application Support/Setline/journal.json`. `JournalStore` writes the JSON atomically. `Journal` applies each mutation to a copy on the main actor and publishes it after the write succeeds. Logging a set and prefilling the next draft share one write. On failure the app retains the previous state and shows a storage error. If loading fails, the app offers a retry against the existing file.

The JSON store starts fresh when upgrading from the earlier database-backed prototype. The previous database file is retained on disk.

Each session owns an ordered snapshot of the routine's exercises, its selected exercise, the drafts for each exercise, and its logged sets. The recovered snapshot drives the resume card at launch. Starting another workout while one is open returns the existing session. Finishing saves the completion time and active flag together.

The prefill uses the matching set number from the most recently **completed** workout containing the exercise, including workouts from other routines. It then falls back to the preceding local set, and finally to 20 kg or 45 lb for 8 reps. Each logged set records its unit. A draft keeps its unrounded kilogram value when its display unit changes. Tapping a last-session chip copies that entry into the draft.

Quick workouts start empty. Their picker offers saved routine exercise names and common lifts. Add custom names from the routine builder. Checklist items retain their completion state until you toggle or delete them.

## Verification status

| Check | Status |
| --- | --- |
| Swift syntax for all application, XCTest, and UI-test source files | Parsed on Windows with the tree-sitter Swift grammar |
| XcodeGen YAML, target versions, source paths, plist XML, and GitHub Actions YAML and shell syntax | Checked on Windows |
| XcodeGen generation, Swift type-checking, iOS linking, GitHub Actions artifact, Simulator layout, and XCTest execution | Awaiting a GitHub runner or Mac with Xcode |
| Sideloadly installation, App Switcher force-quit, Spotify IPC, URL handoff, downloaded playback, audio continuity, and haptics | Awaiting a physical iPhone 8 |

### Automated tests

Select an iPhone Simulator, select the **Setline** scheme, and press **⌘U**. For a terminal run, list installed simulators and substitute one of their UDIDs in the command below.

```sh
xcrun simctl list devices available
xcodebuild test -project Setline.xcodeproj -scheme Setline \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID'
```

- **JournalTests** uses isolated temporary JSON stores. It checks immediate persistence, edits, deletion and undo, task toggles, session recovery, routine snapshots, history prefill, weight conversion, and rollback on a failed write.
- **RecoveryUITests** starts a quick workout through Today, records 20 kg × 8 and 22.5 kg × 7, terminates and relaunches the app, taps Resume, and checks both values. The Debug app accepts `-ui-testing` and a unique `SETLINE_TEST_STORE` UUID so both launches use an isolated temporary JSON file. The suite also checks that the last-set reference, Spotify bar, two logged sets, steppers, and Log Set button are visible together on a 375 × 667 pt display. Use an iPhone SE (2nd or 3rd generation) simulator for that layout check. To exercise iOS 16, select an iOS 16 runtime where your Xcode installation supports it.

### Physical iPhone acceptance check

1. With Setline installed, turn on Airplane Mode and turn Wi-Fi off. Launch from the Home Screen.
2. Tap **Choose workout → Empty quick workout → Choose exercise → Bench press**. With kg selected, log the default **20 kg × 8**. Tap weight **+** once and reps **−** once. Log **22.5 kg × 7**.
3. Immediately open the iOS App Switcher and swipe Setline away. Reopen from the Home Screen while still offline.
4. Tap **Resume Active Workout**. Verify the same exercise, set 1 at **20 kg × 8**, set 2 at **22.5 kg × 7**, and the counter ready for set 3.
5. Edit set 1 and relaunch. Verify the edit. Undo the latest set, relaunch, and verify only the edited first set remains. Finish the workout. Confirm that History shows the session with one set and Today offers a new workout.
6. Add and toggle a task offline. Relaunch and check that its completion state survived.

### Physical iPhone playback checks

- Start Spotify playback before launching Setline. Listen for uninterrupted audio when opening the app and entering a workout.
- Complete online authorization through the setup sheet. Verify the Spotify app switch, exact callback, current track and artist, play/pause, and next track.
- With the playlist downloaded, enable Airplane Mode with Wi-Fi off. Verify audible playback of a downloaded track and try each remote control while continuing to log sets.
- With App Remote disconnected, tap **Open Spotify** and verify the `spotify://` handoff. Return to the workout and verify the saved sets. Repeat with the first consent request cancelled or Spotify unavailable and check that set logging stays usable.
- On an iPhone 8, check one-handed reach, Dynamic Type, VoiceOver labels, and haptics for logging and task completion.

## Directory structure

```text
.
├── .github/workflows/build.yml
├── project.yml
├── README.md
├── Setline
│   ├── Info.plist
│   ├── SetlineApp.swift
│   ├── Models.swift
│   ├── Journal.swift
│   ├── JournalStore.swift
│   ├── Assets.xcassets
│   │   ├── Contents.json
│   │   └── AppIcon.appiconset
│   │       ├── Contents.json
│   │       └── Setline.png
│   ├── Spotify
│   │   ├── SpotifyManager.swift
│   │   └── SpotifyViews.swift
│   └── Views
│       ├── Components.swift
│       ├── EmptyState.swift
│       ├── Haptics.swift
│       ├── TodayView.swift
│       ├── RoutinesView.swift
│       ├── WorkoutView.swift
│       ├── SetControls.swift
│       └── HistoryView.swift
├── SetlineTests
│   └── JournalTests.swift
└── SetlineUITests
    └── RecoveryUITests.swift
```
