# Ripe

A Pomodoro timer that lives in your Mac's menu bar. The tomato ripens from green to red as each focus session runs.

- Work / break / long-break cycles with sounds and notifications
- Auto-pause when you step away; pauses when your Mac sleeps
- Start/pause from any app with ⌥⌘P
- Statistics: today, this week, best focus hours, and which apps you focused in
- Share your week as an Instagram Story image (1080×1920)

Everything stays on your Mac. App tracking records only app names and seconds, and can be turned off in Settings.

Requires macOS 14 Sonoma or later. Runs on Apple silicon and Intel Macs.

## Install

1. Download **[Ripe.zip](https://github.com/Conner0005/ripe/releases/latest/download/Ripe.zip)** (or visit the [download page](https://conner0005.github.io/ripe/)) and unzip it.
2. Drag **Ripe.app** into **Applications**.
3. Open it. Because Ripe isn't notarized by Apple, macOS will say it can't verify the app the first time:
   - Click **Done** (or **OK**), then open **System Settings → Privacy & Security**.
   - Scroll down to the message about Ripe and click **Open Anyway**, then confirm.

   You only need to do this once. (Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Ripe.app`.)

Ripe appears as a tomato in the menu bar; there's no Dock icon. To move it, hold ⌘ and drag it.

## Build from source

Needs Xcode or the Xcode Command Line Tools (Swift 5.10+).

```sh
git clone <this repo> ripe
cd ripe
./scripts/bundle.sh          # builds build/Ripe.app
cp -R build/Ripe.app /Applications/
```

An app built on your own Mac opens without the warning above.

Run the tests with `swift test --disable-swift-testing`.

To make a release zip (universal, Apple silicon + Intel): `./scripts/release.sh`, which writes `build/Ripe.zip`. Attach it to a GitHub Release with `gh release create v<version> build/Ripe.zip`.

The download page lives in `site/`. After committing changes to it, run `./scripts/publish-site.sh` to update https://conner0005.github.io/ripe/.

## License

MIT. See [LICENSE](LICENSE).
