import QtQuick

// Pure headless Finite State Machine (FSM) for FluentFlyout
// Governs lifecycle, auto-pop dismissal, pinning, and interactive dragging without UI dependencies.
QtObject {
    id: root

    // --- State Enumerations ---
    readonly property int stateIdle: 0
    readonly property int stateAutoPopped: 1
    readonly property int statePinned: 2
    readonly property int stateDragging: 3

    // Current active state
    property int currentState: stateIdle

    // Media & Presentation Guards
    property bool hasMedia: false
    property bool isPlaying: false
    property bool isExpanded: false
    property bool isHovered: false

    // Auto-hide configuration (3.5s default as specified)
    property int autoHideInterval: 3500

    // --- Signals ---
    signal stateChanged(int oldState, int newState)
    signal requestCleanup()
    signal autoHideTimeout()

    // --- Auto-Hide Countdown Timer ---
    // Active strictly during stateAutoPopped. Stopped in all other states.
    property Timer _autoHideTimer: Timer {
        interval: root.autoHideInterval
        repeat: false
        running: false
        onTriggered: {
            if (root.currentState === root.stateAutoPopped) {
                if (!root.isHovered) {
                    root.transitionTo(root.stateIdle);
                    root.autoHideTimeout();
                } else {
                    // Postpone dismissal while user maintains hover focus
                    root._autoHideTimer.restart();
                }
            }
        }
    }

    // Resume countdown once hover focus is released during stateAutoPopped
    onIsHoveredChanged: {
        if (!isHovered && currentState === stateAutoPopped && !_autoHideTimer.running) {
            _autoHideTimer.restart();
        }
    }

    // --- Media Guard & Instant Cleanup Handlers ---
    // Immediate cleanup: wipe metadata when media stops (hasMedia=false) or player exits
    onHasMediaChanged: {
        if (!hasMedia) {
            handleMediaStopOrExit();
        }
    }

    function handleMediaStopOrExit() {
        // Broadcast cleanup signal to purge metadata cache immediately
        root.requestCleanup();

        // Auto-popped flyout must immediately dismiss when media is no longer active
        if (currentState === root.stateAutoPopped) {
            transitionTo(root.stateIdle);
        }
    }

    // Explicit hook invoked upon player process termination or D-Bus disconnect
    function onPlayerExited() {
        hasMedia = false;
        isPlaying = false;
        handleMediaStopOrExit();
    }

    // Guard evaluation for track transitions and auto-popup
    function canAutoPop() {
        return hasMedia && isPlaying && !isExpanded;
    }

    // --- State Transition Methods ---

    // Trigger auto-pop on track transition
    function autoPop() {
        if (!canAutoPop()) {
            return false;
        }

        // Pinned and Dragging states take precedence over automatic popups
        if (currentState === statePinned || currentState === stateDragging) {
            return false;
        }

        transitionTo(stateAutoPopped);
        return true;
    }

    // Pin flyout permanently (suspends auto-hide timer)
    function pin() {
        transitionTo(statePinned);
    }

    // Unpin flyout back to idle
    function unpin() {
        transitionTo(stateIdle);
    }

    // Toggle between pinned and idle states
    function togglePin() {
        if (currentState === statePinned) {
            transitionTo(stateIdle);
        } else {
            transitionTo(statePinned);
        }
    }

    // Initiate interactive drag
    function startDrag() {
        transitionTo(stateDragging);
    }

    // Complete interactive drag, settling back into pinned state
    function endDrag() {
        if (currentState === stateDragging) {
            transitionTo(statePinned);
        }
    }

    // Explicit dismiss to idle
    function dismiss() {
        transitionTo(stateIdle);
    }

    // Central state transition dispatcher
    function transitionTo(targetState) {
        if (currentState === targetState) {
            // Restart auto-hide timer if re-triggering while already auto-popped
            if (targetState === stateAutoPopped) {
                _autoHideTimer.interval = root.autoHideInterval;
                _autoHideTimer.restart();
            }
            return;
        }

        var oldState = currentState;
        currentState = targetState;
        isExpanded = (targetState !== stateIdle);

        // Auto-hide timer is active ONLY in stateAutoPopped
        if (targetState === stateAutoPopped) {
            _autoHideTimer.interval = root.autoHideInterval;
            _autoHideTimer.restart();
        } else {
            _autoHideTimer.stop();
        }

        root.stateChanged(oldState, targetState);
    }
}
