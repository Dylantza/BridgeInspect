import Foundation

/// Tracks whether a record has been pushed to the cloud.
/// `.local` is the upload queue: dirty records are found by query, not a side table.
enum SyncState: String, Codable, CaseIterable, Sendable {
    /// Created or modified on device, not yet confirmed by the server.
    case local
    /// Confirmed present on the server and unchanged since.
    case synced
    /// Last upload attempt failed. Still dirty, still retried.
    case failed
}
