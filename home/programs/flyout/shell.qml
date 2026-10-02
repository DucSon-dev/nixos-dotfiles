import Quickshell

Scope {
    id: rootScope
    property bool isFlyoutExpanded: false

    TaskbarCapsule {
        expanded: rootScope.isFlyoutExpanded
        onToggleRequested: rootScope.isFlyoutExpanded = !rootScope.isFlyoutExpanded
    }

    MediaFlyout {
        isOpen: rootScope.isFlyoutExpanded
        onCloseRequested: rootScope.isFlyoutExpanded = false
        onOpenRequested: rootScope.isFlyoutExpanded = true
    }

    OsdFlyout {}
}
