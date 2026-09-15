import Foundation

/// The explicit state machine. Transitions happen in `GameViewModel` and
/// nowhere else.
enum GameState: Equatable {
    case menu
    case playing
    case paused
    case gameOver
}
