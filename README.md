# CDC Wi-Fi Simulator (macOS)

macOS desktop simulator for SDK integration testing. Issue [#2](https://github.com/simonmecho/wifi-transfer-sdk/issues/2).

## Scope

**S1 (#2)**
- WebSocket server on port **8490**
- Handles `basic auth request` → responds `basic auth response` with `status: ok|error`
- Logs `status notify` messages
- GUI / CLI to send `transfer request by push`

**S2 (#3)**
- mDNS/DNS-SD publishes `_drec._tcp` (WebSocket port 8490)
- WebDAV server on port **49150** with CDC Basic Auth (`md5(SSID+password)` first 8 hex chars)
- GET serves mp4/json files from configurable `Fixtures/videos` root
- GUI configures Wi-Fi SSID/password and video root path

**S3 (#5)**
- GUI test file builder (filename + size KB) with one-click generation into video root
- Preset scenarios: normal transfer / empty fileList / CDC cancel / large file / multi-file
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
swift run cdc-server
swift Scripts/ws_smoke_test.swift
swift Scripts/webdav_smoke_test.swift ChinaNet-SXGE-5G Sm_20090524 sample_front.mp4
```

CLI push (after server starts):

```bash
swift run CDCSimulator --push sample_front.mp4,sample_front.json
```

## Default auth credentials

Matches production SDK `DefaultAuthCredentialProvider`:

- id: `cdc`
- pass: `md5(SSID + password)` hex, first 8 chars (same token for WebDAV and WebSocket)
- default SSID/password (`ChinaNet-SXGE-5G` / `Sm_20090524`) → pass `006d1135`

## Protocol reference

See [wifi-transfer-sdk/shared/protocol/commands.json](https://github.com/simonmecho/wifi-transfer-sdk/blob/main/wifi-transfer-repo/shared/protocol/commands.json).
