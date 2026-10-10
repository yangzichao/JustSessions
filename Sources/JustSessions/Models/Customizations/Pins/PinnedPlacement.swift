import Foundation

/// Where a dragged project or session goes among the pinned ones, named by a pinned neighbor rather than an index, so
/// pins a filter or search hides keep their places around it.
enum PinnedPlacement: Equatable {
    case before(String)
    case after(String)
    /// After every pin, where a newly pinned one goes.
    case last
}
