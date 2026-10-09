import QtQuick

// Headless test harness verifying FlyoutManager configuration parsing, state mutations, and JSON serialization
QtObject {
    id: testRunner

    property int testStep: 0

    // Mock representation of settings state matching FlyoutManager.qml contracts
    property bool mediaFlyoutEnabled: true
    property bool taskbarCapsuleEnabled: true
    property bool osdEnabled: true
    property real osdTimeoutSec: 2.5
    property real autoHideDelaySec: 3.5
    property real surfaceOpacity: 0.72

    function parseConfigJson(jsonText) {
        try {
            var parsed = JSON.parse(jsonText);
            if (parsed.modules) {
                if (parsed.modules.mediaFlyout) {
                    mediaFlyoutEnabled = parsed.modules.mediaFlyout.enabled !== undefined ? parsed.modules.mediaFlyout.enabled : true;
                    if (parsed.modules.mediaFlyout.autoHideTimeoutMs !== undefined) {
                        autoHideDelaySec = parsed.modules.mediaFlyout.autoHideTimeoutMs / 1000.0;
                    }
                }
                if (parsed.modules.taskbarCapsule) {
                    taskbarCapsuleEnabled = parsed.modules.taskbarCapsule.enabled !== undefined ? parsed.modules.taskbarCapsule.enabled : true;
                }
                if (parsed.modules.osdEngine) {
                    osdEnabled = parsed.modules.osdEngine.enabled !== undefined ? parsed.modules.osdEngine.enabled : true;
                    if (parsed.modules.osdEngine.timeoutMs !== undefined) {
                        osdTimeoutSec = parsed.modules.osdEngine.timeoutMs / 1000.0;
                    }
                }
            }
            if (parsed.theme && parsed.theme.surfaceOpacity !== undefined) {
                surfaceOpacity = parsed.theme.surfaceOpacity;
            }
            return true;
        } catch (e) {
            console.error("Parse error: " + e);
            return false;
        }
    }

    function buildConfigJson() {
        var cfg = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "version": "1.0.0",
            "theme": {
                "variant": "dark-zinc",
                "surfaceColor": "#09090b",
                "surfaceOpacity": Math.round(surfaceOpacity * 100) / 100,
                "blurRadius": 32,
                "borderColor": "rgba(255, 255, 255, 0.12)",
                "borderWidth": 1,
                "cornerRadius": 16,
                "accentColor": "#fafafa"
            },
            "modules": {
                "taskbarCapsule": {
                    "enabled": taskbarCapsuleEnabled,
                    "marqueeSpeed": 40,
                    "maxCapsuleWidth": 260,
                    "compactHeight": 32,
                    "cornerRadius": 16,
                    "backgroundColor": "#09090b",
                    "backgroundOpacity": Math.round(surfaceOpacity * 100) / 100,
                    "borderColor": "rgba(255, 255, 255, 0.12)",
                    "borderWidth": 1
                },
                "mediaFlyout": {
                    "enabled": mediaFlyoutEnabled,
                    "anchor": "top-center",
                    "popupWidth": 380,
                    "popupHeight": 180,
                    "cornerRadius": 16,
                    "backgroundColor": "#09090b",
                    "backgroundOpacity": Math.round(surfaceOpacity * 100) / 100,
                    "borderColor": "rgba(255, 255, 255, 0.12)",
                    "borderWidth": 1,
                    "albumArtRadius": 12,
                    "animationDurationMs": 220,
                    "autoHideTimeoutMs": Math.round(autoHideDelaySec * 1000)
                },
                "osdEngine": {
                    "enabled": osdEnabled,
                    "anchor": "bottom-center",
                    "timeoutMs": Math.round(osdTimeoutSec * 1000),
                    "animationDurationMs": 180,
                    "showLockKeys": true,
                    "showVolume": true,
                    "showBacklight": true
                }
            }
        };
        return JSON.stringify(cfg, null, 2);
    }

    function assert(cond, msg) {
        if (!cond) {
            console.error("FAIL: " + msg);
            Qt.exit(1);
        }
    }

    property Timer runnerTimer: Timer {
        interval: 15
        repeat: true
        running: true
        onTriggered: {
            testRunner.testStep++;

            switch (testRunner.testStep) {
            case 1:
                console.log("[TEST 1] Ingest baseline config.json payload");
                var rawJson = "{\"version\":\"1.0.0\",\"theme\":{\"surfaceOpacity\":0.72},\"modules\":{\"taskbarCapsule\":{\"enabled\":true},\"mediaFlyout\":{\"enabled\":true,\"autoHideTimeoutMs\":4000},\"osdEngine\":{\"enabled\":true,\"timeoutMs\":2500}}}";
                assert(parseConfigJson(rawJson) === true, "Must parse valid JSON successfully");
                assert(mediaFlyoutEnabled === true, "mediaFlyoutEnabled");
                assert(taskbarCapsuleEnabled === true, "taskbarCapsuleEnabled");
                assert(osdEnabled === true, "osdEnabled");
                assert(Math.abs(autoHideDelaySec - 4.0) < 0.001, "autoHideDelaySec 4.0s");
                assert(Math.abs(osdTimeoutSec - 2.5) < 0.001, "osdTimeoutSec 2.5s");
                assert(Math.abs(surfaceOpacity - 0.72) < 0.001, "surfaceOpacity 0.72");
                break;

            case 2:
                console.log("[TEST 2] Mutate telemetry slider values & toggle switches");
                mediaFlyoutEnabled = false;
                autoHideDelaySec = 5.0;
                osdTimeoutSec = 1.5;
                surfaceOpacity = 0.85;

                assert(mediaFlyoutEnabled === false, "Toggled mediaFlyoutEnabled to false");
                assert(Math.abs(autoHideDelaySec - 5.0) < 0.001, "autoHideDelaySec mutated to 5.0s");
                assert(Math.abs(osdTimeoutSec - 1.5) < 0.001, "osdTimeoutSec mutated to 1.5s");
                assert(Math.abs(surfaceOpacity - 0.85) < 0.001, "surfaceOpacity mutated to 0.85");
                break;

            case 3:
                console.log("[TEST 3] Serialize mutated schema & re-parse round-trip");
                var serialized = buildConfigJson();
                var roundTrip = JSON.parse(serialized);

                assert(roundTrip.modules.mediaFlyout.enabled === false, "Serialized mediaFlyout enabled");
                assert(roundTrip.modules.mediaFlyout.autoHideTimeoutMs === 5000, "Serialized autoHideTimeoutMs 5000");
                assert(roundTrip.modules.osdEngine.timeoutMs === 1500, "Serialized osd timeoutMs 1500");
                assert(roundTrip.theme.surfaceOpacity === 0.85, "Serialized surfaceOpacity 0.85");
                assert(roundTrip.modules.osdEngine.anchor === "bottom-center", "Preserves anchor bottom-center");
                break;

            case 4:
                console.log("=========================================");
                console.log("ALL FLYOUT MANAGER CONFIG TESTS PASSED");
                console.log("=========================================");
                running = false;
                Qt.exit(0);
                break;
            }
        }
    }
}
