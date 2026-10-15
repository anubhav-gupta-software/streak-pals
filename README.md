# Streak Pals

Streak Pals is an iPhone app for habits you keep with friends. A gym session, a chapter, a glass of water: you check in, and so does everyone else in the circle. The streak only stays lit when every pal checks in that day. If someone misses, the count starts over the next time you all make it.

You can use it alone, too. A habit with no circle only needs you.

## What you can do

- Create a habit, pick an icon and a color, and set a reminder time.
- Start a circle and share a 6-character invite code, or join one.
- Check in with an optional note and an optional photo.
- See the flame, who has checked in today, and who you're waiting on.
- Look at the current streak, the longest streak, and a 16-week history.
- Get a local reminder. It fires on the phone. There is no push server.
- Put a widget on the Home Screen or the Lock Screen and check in from there when the App Group is turned on.

Photos and notes stay on the phone unless you later turn on CloudKit.

## How a streak is counted

Today is still open until the day ends. If you have checked in and a pal has not, the streak stays where it was and the card says who you're waiting on. Yesterday is closed. If anyone who was in the circle that day missed it, the streak resets.

Someone who joins today is not required for the days before they arrived. Someone who leaves is not required from that day on. Older days stay as they were.

## Requirements

- A Mac with Xcode 16 or newer
- An iPhone running iOS 17 or newer
- A free Apple ID is enough to install it from Xcode

The default scheme does not use App Groups, iCloud, or push. Those need a paid Apple Developer Program membership, and they are optional. See below.

## Open the project

The Xcode project is already generated and checked in.

1. Clone the repo.
2. Open `StreakPals.xcodeproj`.
3. Wait for indexing to finish.

`project.yml` describes the same targets for [XcodeGen](https://github.com/yonaskolb/XcodeGen). You do not need XcodeGen to build. If you change the spec and want to regenerate, install XcodeGen and run `xcodegen generate` from the repo root. That replaces the checked-in project, so open the result and confirm both schemes are still there.

## Run it in the Simulator

1. Select the **StreakPals** scheme. Not StreakPals-AppGroup.
2. Pick an iPhone simulator.
3. Press Run.

If Xcode asks for a team, add your Apple ID under Xcode > Settings > Accounts and choose your Personal Team. The simulator often signs without that, but the widget extension sometimes makes Xcode ask anyway.

## Install it on your iPhone with a free Apple ID

A free personal team can install the app for about 7 days. After that, plug the phone back in and press Run again. Apple also limits how many apps a free account can keep installed.

1. On the iPhone, go to Settings > Privacy & Security > Developer Mode and turn it on if you are on iOS 16 or later and Xcode asks for it. The phone will restart.
2. Connect the iPhone, unlock it, and tap Trust on the "Trust This Computer" prompt.
3. In Xcode, select the **StreakPals** scheme and your iPhone as the run destination.
4. Select the **StreakPals** target, then Signing & Capabilities.
5. Check **Automatically manage signing**.
6. Set Team to your Personal Team. Add the Apple ID in Xcode > Settings > Accounts if the menu is empty.
7. Change the bundle identifier to something unique, for example `com.yourname.streakpals`. The default `app.streakpals.ios` may already be taken.
8. Select the **StreakPalsWidget** target and set its bundle identifier to the app id plus `.widget`, for example `com.yourname.streakpals.widget`. Use the same team.
9. Press Run.
10. If the phone says the developer is not trusted, open Settings > General > VPN & Device Management, tap your Apple ID, and trust it.

Leave the entitlements files alone for this path. The default ones are empty on purpose. A personal team cannot sign an App Group, iCloud, or push notifications, and this project does not ask for them unless you switch schemes.

### What works on a free account

- Habits, circles, invite codes, check-ins, notes, and photos
- Streaks and stats
- Local reminders
- The widget extension installs with the app

### What does not

- The widget cannot see the app's habits until the App Group is enabled, so the widget asks you to open the app. Tapping it opens Streak Pals.
- Invite codes only resolve for pals on this same iPhone. Another phone needs CloudKit, which needs the paid program.
- TestFlight and the App Store need the paid program.

### Try a shared streak on one phone

1. Finish onboarding with your name.
2. Create a circle. Copy the code.
3. Open Settings (the person icon) and add a pal.
4. Switch to that pal, go to Circles, and join with the code. You can also add them from the circle screen without switching.
5. Add a habit to the circle.
6. Switch between the two profiles and check in as each of them. The day counts when both have.

## The widget

After the app is installed, long-press the Home Screen, tap +, and search for Streak Pals.

- **One habit** is a small widget, and it also has Lock Screen sizes. It can check in with the button when the App Group is on.
- **Today** is the medium and large widget. Each row has its own check-in button.

The button runs inside the widget and writes the same snapshot the app uses. That only works when both targets are signed with the App Group entitlement, because iOS will not let an extension read the app's files otherwise. With a free Apple ID, use the widget as a shortcut into the app.

## Turn on the App Group

This needs the paid Apple Developer Program ($99/year). Skip it if you are on a free Apple ID. Signing will fail if you use this scheme with a personal team.

1. Select the **StreakPals-AppGroup** scheme.
2. On both the app and the widget targets, set Team to your paid team.
3. On both targets, open Signing & Capabilities and add **App Groups**.
4. Use the group id `group.app.streakpals.shared`. The App Group entitlements files already contain that id. If Xcode rewrites the entitlements file, put the same id back.
5. Change both bundle identifiers if you need to, then run.

The app notices the group at launch. It moves new data into the shared container, the widget reads it, and the check-in button works without opening the app. Data saved before the group was turned on stays in the app sandbox, so check in once after switching if a habit looks missing on the widget. Reinstalling after the switch is the clean version of that.

## Turn on CloudKit

Also optional, and also a paid account. The app runs with CloudKit switched off. Nothing in the default build calls iCloud.

CloudKit here uses the **public** database. A circle is stored under its invite code. Anyone who has the app and the code can join that circle. Notes and photos for that circle are uploaded with the check-in. Don't put anything in a note or photo that you wouldn't want another member of the app to see if they have the code. This is not a private iCloud database, and it is not end-to-end encrypted by the app.

1. Use the **StreakPals-AppGroup** scheme and your paid team, with the App Group already working if you want the widget.
2. Select the **StreakPals** target (the app, not the widget).
3. Signing & Capabilities > + Capability > iCloud. Check CloudKit.
4. Add a container. The placeholder in the code is `iCloud.app.streakpals.ios`. Use that, or use your own and change `cloudKitContainerID` on `AppGroup` in `Shared/SnapshotStore.swift`.
5. In `StreakPals/Sync/SyncService.swift`, set `SyncConfiguration.backend` to `.cloudKit`.
6. Run a Debug build on a phone that is signed into iCloud. The first save creates the record types (Pal, Circle, Habit, CheckIn) in the Development environment.
7. Before TestFlight, open the [CloudKit Console](https://icloud.developer.apple.com/), select the container, and deploy the schema to Production.

Pull to refresh on Today, or use Sync now in Settings. Creating a habit, checking in, or joining a circle also syncs.

If iCloud isn't signed in, the app keeps working locally and Settings shows the error.

## Move it to TestFlight later

TestFlight needs the paid program. A free Apple ID cannot upload a build.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/).
2. In [App Store Connect](https://appstoreconnect.apple.com/), create an app whose bundle id matches the StreakPals target.
3. Turn on the App Group (and CloudKit, if you want sync) as above. Use the **StreakPals-AppGroup** scheme so the widget can share data. You can ship without the App Group, but the widget will only open the app.
4. Set the version and build in the target if you are sending up a new one. Marketing version is `1.0`, build number is `1`.
5. Select Any iOS Device (arm64) as the destination.
6. Product > Archive.
7. In the Organizer, Distribute App > App Store Connect > Upload.
8. Export compliance is already answered. `ITSAppUsesNonExemptEncryption` is false, because the app only uses system HTTPS and does not add its own encryption.
9. In App Store Connect, fill in the privacy questionnaire. With the default local mode the app does not collect data and does not track. If CloudKit is on, say that user content (check-ins, notes, photos) is stored so the circle can see it, and that it is not used for tracking.
10. Add internal testers. The first build for a new app still goes through a short beta review before external testers can install it.

The free-account 7-day limit does not apply to TestFlight builds.

## Project layout

```
StreakPals.xcodeproj    Open this.
project.yml             XcodeGen spec, if you want to regenerate.
Config/                 Empty entitlements, and the App Group ones.
Shared/                 Models, streak math, snapshot store, widget intents.
StreakPals/             The app: screens, reminders, CloudKit.
StreakPalsWidget/       Home Screen and Lock Screen widgets.
```

The streak rule lives in `Shared/StreakEngine.swift`. The app and the widget both compile `Shared/`, and they share a file in the App Group container when that entitlement is present. Otherwise the app stores the snapshot in its own Application Support folder.

## Troubleshooting

**Signing failed, and the message mentions App Groups or iCloud.** You are on the StreakPals-AppGroup scheme, or a capability was added on a personal team. Switch back to the **StreakPals** scheme and remove the capability from Signing & Capabilities.

**The widget is blank or says to open the app.** The App Group is off, which is normal on a free account. Open the app and check in there. The widget button starts writing through once the group is signed.

**"No circle on this iPhone uses that code."** The code was created on another device and CloudKit is off. Add the pal on this phone, or turn CloudKit on.

**The app will not open after installing.** Trust the developer certificate under Settings > General > VPN & Device Management.

**The app expired.** Free provisioning lasts about 7 days. Run it from Xcode again.

**CloudKit says the field is not queryable, or the container was not found.** Confirm the container id matches Signing & Capabilities, the iCloud capability is on the app target, and you are signed into iCloud. This sync path fetches records by id and does not rely on custom query indexes, but the container itself still has to exist.

**Xcode says the project was created with a newer version.** Use Xcode 16 or newer. The project uses synchronized folders, which that version introduced.
