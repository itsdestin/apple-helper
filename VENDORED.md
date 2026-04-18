# VENDORED.md

Provenance for code copied byte-for-byte from third-party sources.

This repo contains **no** byte-for-byte vendored code. iMCP, our primary reference, is credited in `NOTICE.md` as reference-only — we read its patterns for EventKit/Contacts usage and implement our own code in `Sources/AppleHelper/`. The marketplace plugin at `wecoded-marketplace/apple-services/` vendors AppleScript extracted from `supermemoryai/apple-mcp`; that repo's `VENDORED.md` tracks those files.

See `NOTICE.md` for third-party attribution.
