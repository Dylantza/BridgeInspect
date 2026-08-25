import Testing
import SwiftData
import Foundation
@testable import BridgeInspect

@MainActor
private func makeContext() throws -> ModelContext {
    let container = try AppModelContainer.makeInMemory()
    return ModelContext(container)
}

@MainActor
@Suite("Completion rollup")
struct CompletionTests {

    @Test("An untouched wall has every inspection outstanding")
    func untouchedWall() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        #expect(wall.outstandingCount == InspectionType.allCases.count)
        #expect(wall.isComplete == false)
    }

    @Test("Not applicable counts as resolved, not outstanding")
    func notApplicableResolves() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        for type in InspectionType.allCases {
            let inspection = InspectionResolver.resolve(wall: wall, type: type, context: context)
            inspection.status = .notApplicable
        }

        #expect(wall.outstandingCount == 0)
        #expect(wall.isComplete == true)
    }

    @Test("Space completion is the fraction of resolved cells")
    func spaceFraction() throws {
        let context = try makeContext()
        let space = Space(name: "Space 01")
        context.insert(space)

        for index in 0..<2 {
            let wall = Wall(name: "W\(index + 1)", sortIndex: index)
            wall.space = space
            context.insert(wall)
        }

        let typeCount = InspectionType.allCases.count
        #expect(space.totalCellCount == typeCount * 2)
        #expect(space.completionFraction == 0)

        // Resolve every cell on the first wall only.
        let first = try #require(space.activeWalls.first)
        for type in InspectionType.allCases {
            let inspection = InspectionResolver.resolve(wall: first, type: type, context: context)
            inspection.status = .completed
        }

        #expect(space.completionFraction == 0.5)
        #expect(space.isComplete == false)
    }

    @Test("An empty space reads as zero, never complete")
    func emptySpace() throws {
        let context = try makeContext()
        let space = Space(name: "Space 01")
        context.insert(space)

        #expect(space.totalCellCount == 0)
        #expect(space.completionFraction == 0)
        #expect(space.isComplete == false)
    }
}

@MainActor
@Suite("Wall notes")
struct WallNoteTests {

    @Test("hasNote is false when empty, nil, or only whitespace")
    func emptyNotes() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        #expect(wall.hasNote == false)

        wall.notes = ""
        #expect(wall.hasNote == false)

        wall.notes = "   \n  "
        #expect(wall.hasNote == false)
    }

    @Test("hasNote is true once real text is entered")
    func realNote() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        wall.notes = "Crack near the joint."
        #expect(wall.hasNote == true)
    }
}

@MainActor
@Suite("iPhone media")
struct WallMediaTests {

    @Test("Photos and videos are counted separately")
    func mediaCounts() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        #expect(wall.photoMediaCount == 0)
        #expect(wall.videoMediaCount == 0)

        for index in 0..<3 {
            let item = WallMedia(localFilename: "p\(index).jpg", kind: .photo, sortIndex: index)
            item.wall = wall
            context.insert(item)
        }
        let video = WallMedia(localFilename: "v.mov", kind: .video, sortIndex: 3)
        video.wall = wall
        context.insert(video)

        #expect(wall.photoMediaCount == 3)
        #expect(wall.videoMediaCount == 1)
        #expect(wall.activeMedia.count == 4)
    }

    @Test("Deleted media drops out of the gallery but persists for sync")
    func softDeleteMedia() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let item = WallMedia(localFilename: "a.jpg", kind: .photo)
        item.wall = wall
        context.insert(item)
        #expect(wall.activeMedia.count == 1)

        item.isDeleted = true
        #expect(wall.activeMedia.isEmpty)
        #expect(wall.media.count == 1)
    }

    @Test("Media starts un-uploaded with no remote path")
    func mediaStartsLocal() throws {
        let context = try makeContext()
        let item = WallMedia(localFilename: "a.jpg", kind: .photo)
        context.insert(item)

        #expect(item.isUploaded == false)
        #expect(item.remoteStoragePath == nil)
    }

    @Test("Unknown media kind degrades to photo")
    func unknownKind() throws {
        let context = try makeContext()
        let item = WallMedia(localFilename: "a.jpg", kind: .video)
        context.insert(item)

        item.kindRaw = "hologram"
        #expect(item.kind == .photo)
    }
}

@MainActor
@Suite("Wall photos as a status")
struct WallPhotoStatusTests {

    @Test("Photo is an inspection type like any other")
    func photoIsAnInspectionType() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        #expect(wall.status(for: .photo) == .notStarted)

        let inspection = InspectionResolver.resolve(wall: wall, type: .photo, context: context)
        inspection.status = .completed
        #expect(wall.status(for: .photo) == .completed)
    }

    @Test("Frame count is recorded for camera types only")
    func frameCountTracking() throws {
        let cameraTypes: Set<InspectionType> = [.photo, .closeup]
        for type in InspectionType.allCases {
            #expect(type.tracksFrameCount == cameraTypes.contains(type))
        }
    }

    @Test("Close-up is its own column, separate from wall photos")
    func closeupIsSeparate() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let photo = InspectionResolver.resolve(wall: wall, type: .photo, context: context)
        photo.status = .completed

        #expect(wall.status(for: .photo) == .completed)
        #expect(wall.status(for: .closeup) == .notStarted)
    }

    @Test("Frame count persists on the photo inspection")
    func frameCountPersists() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let inspection = InspectionResolver.resolve(wall: wall, type: .photo, context: context)
        #expect(inspection.frameCount == nil)

        inspection.frameCount = 6
        #expect(wall.inspection(for: .photo)?.frameCount == 6)
    }

    @Test("Photo column is first in the table")
    func photoIsFirstColumn() throws {
        #expect(InspectionType.allCases.first == .photo)
    }
}

@MainActor
@Suite("Variable wall counts")
struct WallCountTests {

    @Test("Spaces may hold any number of walls")
    func variableCounts() throws {
        let context = try makeContext()
        let project = Project(name: "Bridge A")
        context.insert(project)

        for (index, wallCount) in [3, 9, 4].enumerated() {
            let space = Space(name: "Space 0\(index + 1)", sortIndex: index)
            space.project = project
            context.insert(space)
            for wallIndex in 0..<wallCount {
                let wall = Wall(name: "W\(wallIndex + 1)", sortIndex: wallIndex)
                wall.space = space
                context.insert(wall)
            }
        }

        #expect(project.activeSpaces.map(\.activeWalls.count) == [3, 9, 4])
    }

    @Test("Soft-deleted walls disappear from the table but persist")
    func softDeleteWall() throws {
        let context = try makeContext()
        let space = Space(name: "Space 01")
        context.insert(space)

        let wall = Wall(name: "W1")
        wall.space = space
        context.insert(wall)
        #expect(space.activeWalls.count == 1)

        wall.isDeleted = true
        #expect(space.activeWalls.isEmpty)
        #expect(space.walls.count == 1)   // tombstone still present for sync
    }
}

@MainActor
@Suite("Inspection status")
struct InspectionTests {

    @Test("Missing inspection reads as Not Started")
    func defaultStatus() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        for type in InspectionType.allCases {
            #expect(wall.status(for: type) == .notStarted)
        }
    }

    @Test("Resolver creates an inspection once and reuses it")
    func resolverIsIdempotent() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let first = InspectionResolver.resolve(wall: wall, type: .hammer, context: context)
        let second = InspectionResolver.resolve(wall: wall, type: .hammer, context: context)

        #expect(first.id == second.id)
        #expect(wall.inspections.count == 1)
    }

    @Test("Completing sets completedAt, reverting clears it")
    func completedTimestamp() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let inspection = InspectionResolver.resolve(wall: wall, type: .gpr, context: context)
        #expect(inspection.completedAt == nil)

        inspection.status = .completed
        #expect(inspection.completedAt != nil)

        inspection.status = .notStarted
        #expect(inspection.completedAt == nil)
    }

    @Test("Unknown stored status degrades to Not Started instead of crashing")
    func unknownRawValue() throws {
        let context = try makeContext()
        let inspection = Inspection(type: .sensor)
        context.insert(inspection)

        inspection.statusRaw = "somethingFromAFutureVersion"
        #expect(inspection.status == .notStarted)
    }
}

@MainActor
@Suite("Sync metadata")
struct SyncMetadataTests {

    @Test("New records start dirty")
    func newRecordsAreLocal() throws {
        let context = try makeContext()
        let project = Project(name: "Bridge A")
        context.insert(project)
        #expect(project.syncState == .local)
    }

    @Test("touch() re-dirties a synced record")
    func touchMarksDirty() throws {
        let context = try makeContext()
        let space = Space(name: "Space 01")
        context.insert(space)

        space.syncState = .synced
        #expect(space.syncState == .synced)

        space.touch()
        #expect(space.syncState == .local)
    }

    @Test("Editing an inspection marks it dirty for upload")
    func editingMarksDirty() throws {
        let context = try makeContext()
        let wall = Wall(name: "W1")
        context.insert(wall)

        let inspection = InspectionResolver.resolve(wall: wall, type: .ultrasonic, context: context)
        inspection.syncState = .synced

        inspection.status = .completed
        #expect(inspection.syncState == .local)
    }
}
