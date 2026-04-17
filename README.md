# apple-helper

Swift CLI powering the `apple-services` marketplace bundle. Wraps EventKit (Calendar, Reminders) and the Contacts framework behind a uniform JSON CLI so the `apple-services` plugin's bash wrapper can call a single binary.

## Build

```bash
swift build -c release
.build/release/apple-helper --version
```

## Release

Tag `apple-helper-vX.Y.Z`. CI builds a universal (arm64+x86_64) Mach-O, ad-hoc signs it, computes SHA256, and opens a PR against `itsdestin/wecoded-marketplace` vendoring the binary into `apple-services/bin/`.

## Source layout

- `Sources/AppleHelper/` — CLI entry, arg parsing, JSON output, error envelope, EventKit/Contacts ops (all original code)

## License

MIT. Patterns inspired by `mattt/iMCP` (also MIT) are credited in `NOTICE.md` — no iMCP code is vendored byte-for-byte.
