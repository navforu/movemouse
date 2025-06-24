import AppKit // For NSEvent, NSScreen
import CoreGraphics // For CGEvent, CGWarpMouseCursorPosition

class MouseControlService {

    func moveMouse(to point: CGPoint) {
        // CGWarpMouseCursorPosition moves the cursor to the specified point in global screen coordinates.
        // SwiftUI points are often relative to a view, so ensure 'point' is in global screen coordinates if necessary.
        // For this service, we assume 'point' is already in the correct coordinate system.
        CGWarpMouseCursorPosition(point)
        // You might want to post a synthetic mouse moved event if some applications expect it,
        // though CGWarpMouseCursorPosition usually suffices.
        // let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        // mouseMoveEvent?.post(tap: .cgSessionEventTap)
    }

    func moveMouseSlightly(stealth: Bool) {
        guard let currentPosition = getCurrentMousePosition() else { return }

        if stealth {
            // For stealth mode, we can just post a mouse move event at the current location.
            // This can sometimes be enough to make the system think the mouse moved.
            let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: currentPosition, mouseButton: .left)
            mouseMoveEvent?.flags = [] // Ensure no modifier keys are pressed
            mouseMoveEvent?.post(tap: .cgSessionEventTap)

            // Alternatively, or in addition, a tiny, imperceptible move:
            // CGWarpMouseCursorPosition(CGPoint(x: currentPosition.x + 0.00001, y: currentPosition.y + 0.00001))
            // CGWarpMouseCursorPosition(currentPosition) // And then back, though this might be too fast.
            // The key for "stealth" is that the user doesn't perceive the movement.
            // Posting an event at the same location is often the most "stealthy".
        } else {
            // Perform a small, visible square or circular movement pattern
            let offset: CGFloat = 5.0 // Small distance for movement
            let delayMicroseconds: UInt32 = 50_000 // 50ms delay between small movements

            let originalPoint = currentPosition

            let pointsToVisit = [
                CGPoint(x: originalPoint.x + offset, y: originalPoint.y),
                CGPoint(x: originalPoint.x + offset, y: originalPoint.y + offset),
                CGPoint(x: originalPoint.x, y: originalPoint.y + offset),
                originalPoint // Return to start
            ]

            for point in pointsToVisit {
                CGWarpMouseCursorPosition(point)
                usleep(delayMicroseconds) // Brief pause
            }
            // Ensure it ends up exactly back for precision if needed, though the loop does this.
            // CGWarpMouseCursorPosition(originalPoint)
        }
    }

    func performLeftClick() {
        guard let currentPosition = getCurrentMousePosition() else { return }

        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPosition, mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentPosition, mouseButton: .left)

        mouseDownEvent?.post(tap: .cgSessionEventTap)
        // Brief delay, though often not strictly necessary for a simple click
        // usleep(10000) // 10ms, if needed
        mouseUpEvent?.post(tap: .cgSessionEventTap)
    }

    func getCurrentMousePosition() -> CGPoint? {
        // NSEvent.mouseLocation gives the current mouse position in screen coordinates.
        // The Y-coordinate is flipped compared to Core Graphics (NSEvent is from bottom-left, CGEvent from top-left).
        // However, CGEvent functions typically expect coordinates from top-left.
        // For CGWarpMouseCursorPosition and CGEvent creation, it's usually best to work with top-left coordinates.
        // Let's verify the coordinate system expected by CGWarpMouseCursorPosition.
        // Documentation indicates global display coordinates, usually top-left.

        // Let's use CGEvent to get the location, as it's more consistent with other CGEvent operations.
        guard let event = CGEvent(source: nil) else {
            print("Failed to create CGEvent to get mouse location.")
            return nil
        }
        return event.location // This is in global display coordinates (top-left origin).
    }

    // Note: For screen saver and idle timer interactions:
    // Moving the mouse programmatically with CGWarpMouseCursorPosition or posting CGMouseEvents
    // typically DOES reset the system idle timer, thus preventing the screen saver or sleep.
    // No special "wake" calls are usually needed beyond simulating mouse activity.
}
