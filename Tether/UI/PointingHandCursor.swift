import AppKit
import SwiftUI

/// Shows the pointing-hand cursor while the pointer is over a clickable control.
/// (`.pointerStyle(.link)` needs macOS 15; Tether supports macOS 13.)
private struct PointingHandCursor: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside && isEnabled { push() } else { pop() }
            }
            .onChange(of: isEnabled) { enabled in
                if !enabled { pop() }
            }
            // A control that disappears under the pointer (window closes, view swaps) never gets
            // the hover-exit event, so restore the cursor here instead of leaving the hand stuck.
            .onDisappear { pop() }
    }

    private func push() {
        guard !isPushed else { return }
        NSCursor.pointingHand.push()
        isPushed = true
    }

    private func pop() {
        guard isPushed else { return }
        NSCursor.pop()
        isPushed = false
    }
}

extension View {
    /// Pointing-hand cursor on hover, for anything the user can click.
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}
