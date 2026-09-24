# CDC Wi-Fi Simulator (macOS)

macOS desktop simulator for SDK integration testing. Issue [#2](https://github.com/simonmecho/wifi-transfer-sdk/issues/2).

## Scope

**S1 (#2)**
- WebSocket server on port **8490**
- Handles `basic auth request` → responds `basic auth response` with `status: success|error`
- Sends `vin auth request`, validates the MD5-prefix digest in `vin auth response`, and sends `list: null` on mismatch
- Logs `status notify` messages
- GUI / CLI to send `transfer request by push`

**S2 (#3)**
- mDNS/DNS-SD publishes `_drec._tcp` (WebSocket port 8490)
- WebDAV server on port **49150** with CDC Basic Auth (`md5(SSID+password)` first 8 hex chars)
- GET serves mp4 files with `Content-Length` from configurable `Fixtures/videos` root; HEAD is rejected like the production CDC
- GUI configures Wi-Fi SSID/password and video root path

**S3 (#5)**
- GUI test file builder (filename + size KB) with one-click generation into video root
- Preset scenarios: normal / empty list / VIN validation failure / CDC cancel / slow download / WebDAV failure / WebSocket disconnect / UserCancel notify failure / large file / multi-file
- Live logs with WebSocket vs WebDAV filters; WS transfer + movie path protocol handling
- Push disabled until at least one SDK WebSocket client is connected

## Build & run

```bash
cd simulator
swift build
swift run CDCSimulator
```

Headless server (CI / smoke tests):

```bash
swift test
swift run cdc-server
swift Scripts/ws_smoke_test.swift
swift Scripts/ws_auth_negative_smoke_test.swift   # stale cdc123 must be rejected
swift Scripts/webdav_smoke_test.swift ChinaNet-SXGE-5G Sm_20090524 sample_front.mp4
```

CLI push (after server starts):

```bash
swift run CDCSimulator --push sample_front.mp4
```

## Default auth credentials

WebSocket auth matches production SDK `DefaultAuthCredentialProvider`:

- id: `md5(SSID)` hex, first 8 chars
- pass: `md5(Wi-Fi password)` hex, first 8 chars
- default SSID/password (`ChinaNet-SXGE-5G` / `Sm_20090524`) → id `1357f7d3`, pass `b6d4d16a`

WebDAV continues to use `md5(SSID + password)` hex, first 8 chars.

VIN Auth uses the configurable VIN in Settings. A successful response must return
`md5(VIN)` as lowercase hex, first 8 chars. A mismatched success digest causes the
simulator to send `transfer request by push` with an explicit `list: null`.

Failure scenarios are deliberately bounded and explicit:

- **Slow download** delays the WebDAV GET response for 10 seconds so the DemoApp can cancel an active transfer.
- **WebDAV failure** returns HTTP 503 for GET.
- **WebSocket disconnect** closes the control channel when the first transfer request arrives.
- **UserCancel notify failure** closes the WebSocket when GET starts and keeps GET pending for 10 seconds; cancel from the DemoApp during that window to exercise the failed `error/UserCancel` send path.

## Protocol reference

See [wifi-transfer-sdk/shared/protocol/commands.json](https://github.com/simonmecho/wifi-transfer-sdk/blob/main/wifi-transfer-repo/shared/protocol/commands.json).
