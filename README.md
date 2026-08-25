# BridgeInspect

Offline-first iPhone app for documenting and inspecting spaces inside bridges.

## Status

Phases 1–9 complete and building. Supabase and sync are not built yet.

| Phase | Scope | State |
|-------|-------|-------|
| 1 | Architecture | done |
| 2 | Xcode project | done |
| 3 | SwiftData models | done |
| 4 | Projects | done |
| 5 | Spaces | done |
| 6 | Variable walls | done |
| 7 | Space table | done |
| 8 | Inspection status + detail | done |
| 9 | iPhone media capture (photo + video) | done |
| 10–13 | Supabase, Upload, Download, conflicts | not started |
| 14 | Testing and field polish | partial |

24 tests in 7 suites, all passing on iPhone 17 Pro (iOS 26.5).

## Two kinds of "photo"

These are easy to confuse, so they are modelled differently on purpose:

- **PHOTO and C-UP columns** — shots taken on a separate DSLR/mirrorless body.
  The app never holds the image, it only records that the shot was taken. Both
  are ordinary `InspectionType` values; their detail sheet accepts a frame count.
- **iPhone media** — photos and videos captured live on the phone, stored as
  files on disk via `MediaStore` and modelled by `WallMedia`. Reached from the
  wall screen, not the table.

Only the second kind involves Supabase Storage during sync.

## Build

```
xcodebuild -project BridgeInspect.xcodeproj -scheme BridgeInspect \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Requires Xcode 26.6+ and an installed iOS simulator runtime.
Deployment target iOS 18.0, Swift 6 with strict concurrency.

## Regenerating the project

`BridgeInspect.xcodeproj` is generated, not hand-edited. After adding or
removing a Swift file:

```
python3 Scripts/generate_project.py
```

## Structure

```
BridgeInspect/
  App/          entry point, ModelContainer, root tabs
  Models/       SwiftData @Model types and enums
  Features/     one folder per screen
  Services/     MediaStore; Supabase and sync land in phase 10+
```

## Design

Field conditions drive the visual decisions: low light, gloved hands, a dirty or
wet screen.

- **Status is a shape, not a colour** — filled circle, hollow ring, short bar.
  Readable in the dark, at an angle, and for colour-blind users. Colour appears
  only in the completion bar, never in a status glyph.
- **60pt rows**, well above the 44pt minimum, because taps are made with gloves.
- **Long-press a cell** to mark it Completed without opening anything; the
  detail sheet is for everything else.
- **All nine columns fit a 393pt iPhone** without horizontal scrolling. The WALL
  column is frozen for wider devices and larger text sizes.

Shared constants live in `DesignSystem/Theme.swift`.

## Data model

```
Project → Space → Wall → Inspection
                     └─→ WallMedia   (iPhone photos and videos)
```

The number of walls per space is **not fixed** — walls are rows, created and
removed freely. Space 01 may have 4 walls and Space 02 may have 9.

Inspections are created lazily the first time a cell is touched, so an
undocumented wall costs nothing.

### Decisions worth knowing

- **Enums stored as raw strings.** Migration-safe and predicate-friendly; an
  unrecognized value degrades to a default rather than crashing.
- **Every property has a default value.** Required for SwiftData lightweight
  migration; without it the next schema change is a heavyweight migration.
- **Soft deletes everywhere** (`isDeleted`). A hard delete is invisible to a
  device that has been offline, which would resurrect the row on its next upload.
- **Client-generated UUIDs.** Prerequisite for offline creation and idempotent
  upsert.
- **MV, not MVVM.** `@Query` already gives observable state bound to views. A
  ViewModel is planned only for the sync screen, which has genuine transient state.

## Sync design (not yet implemented)

Every syncable record carries `updatedAt`, `remoteUpdatedAt`, and `syncState`.
A record is dirty when `syncState == .local` — the upload queue is a query, not
a side table.

**Upload:** dirty records parents-first (Project → Space → Wall → Inspection →
WallMedia), upserted by primary key so retries are safe. `syncState` flips to
`.synced` only after the server confirms.

**Download:** rows newer than the last sync, merged per record. Not present
locally → insert. Present and clean → overwrite. **Present and dirty → local
wins.** That last rule is what guarantees field work is never destroyed by a
download.

Conflict strategy is last-write-wins at record level with local changes
protected — correct for two users who are almost always in different spaces.

## Testing

Swift Testing, run against an in-memory `ModelContainer`. The sync merge tests
will be the highest-value tests in the project once sync exists.

```
xcodebuild test -project BridgeInspect.xcodeproj -scheme BridgeInspect \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
