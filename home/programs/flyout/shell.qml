import Quickshell
import "core" as Core
import "ui" as UI

// Master Shell Entrypoint for FluentFlyout
// Instantiates shared StateMachine, MprisBridge, and OsdBridge foundation singletons,
// cleanly injecting dependencies into TaskbarCapsule, MediaFlyout, and SystemOsd.
Scope {
    id: rootScope

    // Shared foundation singletons
    Core.StateMachine {
        id: sharedFsm
    }

    Core.MprisBridge {
        id: sharedBridge
        stateMachine: sharedFsm
    }

    Core.OsdBridge {
        id: sharedOsdBridge
    }

    // Floating Taskbar Capsule
    UI.TaskbarCapsule {
        fsm: sharedFsm
        bridge: sharedBridge
    }

    // Interactive Media Flyout Card
    UI.MediaFlyout {
        fsm: sharedFsm
        bridge: sharedBridge
    }

    // Ephemeral System OSD (Volume, Brightness, Lock Keys)
    UI.SystemOsd {
        bridge: sharedOsdBridge
    }
}
