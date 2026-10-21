# Lockscape

A separate wallpaper for the macOS lock screen.

Since Sonoma the lock screen mirrors the desktop wallpaper. Lockscape is a menu bar app
that swaps the desktop wallpaper to your picture the moment the screen locks and puts
the original back on unlock. No sudo, no system files, SIP untouched. macOS 14+.

It can also keep the lock screen lit for up to an hour, or until you unlock, instead of
the 30 seconds macOS allows. By default only on the power adapter; it never holds the
display below 20% battery, and closing the lid still puts the Mac to sleep.

## Install

Download the `.dmg` from [Releases](https://github.com/SindiSekkas/Lockscape/releases),
drag Lockscape to Applications and open it. The build is not notarized, so macOS blocks
the first launch: allow it in System Settings > Privacy & Security ("Open Anyway"), or run
`xattr -d com.apple.quarantine /Applications/Lockscape.app`.

Or build from source with Xcode:

```sh
scripts/install.sh ~/Pictures/lock.png
```

This copies the app to `/Applications`, adds it to Login Items and starts it. Either way,
pick both pictures from the menu bar icon. `scripts/uninstall.sh` removes everything.

## Development

Open `Lockscape.xcodeproj` (generated from `project.yml` with XcodeGen). Unit tests run
with `xcodebuild -scheme Lockscape test`; `scripts/integration-test.sh image.png`
exercises the real WallpaperAgent without locking the screen.

## Limitations

A short crossfade on lock and unlock. All displays and Spaces get the same picture.
The FileVault login screen at power-on is not affected.
