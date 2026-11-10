# Electron macOS Spaces Restoration (Proof of Concept)

A minimal, working proof of concept demonstrating native macOS virtual desktop (Mission Control Spaces) window restoration for Electron applications using Apple's official `NSWindowRestoration` AppKit protocol.

Addresses the multi-year upstream request tracked in [microsoft/vscode#123517](https://github.com/microsoft/vscode/issues/123517) and [electron/electron#37494](https://github.com/electron/electron/issues/37494).

---

## The Problem

When multi-window Electron applications (such as Visual Studio Code) restart on macOS—whether after an in-app update, crash recovery, or clean relaunch—all windows collapse onto the currently active virtual desktop, losing their spatial arrangement across Mission Control Spaces.

While often assumed to be an intractable OS limitation requiring private APIs (`SkyLight.framework`) or external window-management daemons, **native macOS Space restoration has been fully supported by Apple since OS X 10.7 Lion via the public `NSWindowRestoration` AppKit protocol.**

### Root Cause

In `shell/browser/native_window_mac.mm`, Electron explicitly disables AppKit restoration:
```objc
[window setRestorable:NO];
```
This was done because AppKit's standard restoration lifecycle was historically treated as synchronous at launch (`application:willFinishLaunchingWithOptions:`), whereas Electron window instantiation is driven asynchronously by Node.js (`app.whenReady()`). Re-creating windows imperatively via `new BrowserWindow()` causes AppKit to treat them as brand new windows, placing them on the active Space.

However, Apple designed `NSWindowRestoration` with an asynchronous `completionHandler` specifically to accommodate runtimes that instantiate windows after launch. Bridging the two requires **fewer than 50 lines of C++** (+46 lines in `native_window_mac.{h,mm}`).

---

## The Proposed Solution: `restorationIdentifier`

Following Electron's existing macOS-specific `tabbingIdentifier` convention, we propose introducing:

```ts
new BrowserWindow({
  restorationIdentifier: 'editor-workspace-alpha'
})
```

### How It Works: The Asynchronous Bridge

`NSWindowRestoration` provides an asynchronous completion handler:
```objc
+ (void)restoreWindowWithIdentifier:(NSWindowRestorationIdentifier)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler;
```

This API bridges the impedance mismatch:
1. **Startup Restoration Interception:** When AppKit invokes `+restoreWindowWithIdentifier:...`, Electron stores the `completionHandler` block in an internal registry keyed by the identifier.
2. **Fulfillment:** When the JavaScript runtime calls `new BrowserWindow({ restorationIdentifier: "..." })`, Electron retrieves the pending `completionHandler` for that identifier and passes the newly created `NSWindow*` to AppKit (`completionHandler(native_window->GetNativeWindow(), nil)`). AppKit immediately places the window on its previously saved virtual desktop.
3. **Session State Methods (for VS Code):** In userland or session-managed applications (like VS Code's `windowsMainService`), exposing `win.getRestorableState()` and `win.restoreState()` allows persisting the native AppKit restoration buffer directly into existing session databases (`storage.json`).

---

## Repository Structure

```text
electron-spaces-poc/
├── src/
│   ├── native_window_mac.h    # C++ declaration matching Electron structure
│   └── native_window_mac.mm   # AppKit NSWindowRestoration bridge implementation
├── patches/
│   └── 0001-feat-macos-support-restoration-identifier.patch # Upstream patch for electron/electron (<50 LOC)
├── index.js                   # JavaScript API shim
├── example.js                 # Runnable 2-window demonstration
├── binding.gyp                # Node-gyp build specification
├── LICENSE                    # MIT
└── package.json
```

---

## How to Test

### 1. Build and Run

```bash
npm install
npm run build
npm start
```

### 2. Verification Steps

1. The app launches two windows: **Window Alpha** (Blue) and **Window Beta** (Green).
2. Move **Window Alpha** to **Desktop 1**.
3. Move **Window Beta** to **Desktop 2**.
4. Quit the application with **`Cmd + Q`**.
5. Relaunch with `npm start`.
6. Notice that macOS AppKit restores each window directly to its designated Desktop, displaying the green `✅ Restored to target Desktop by AppKit` badge.

---

## Security & Apple Guidelines Compliance

- **100% Public AppKit APIs:** Uses standard `NSWindowRestoration`, `encodeRestorableStateWithCoder:`, and `restoreStateWithCoder:` (standard macOS APIs since OS X 10.7 Lion).
- **macOS 15+ Sequoia Compatible:** Implements `_windowRestorationOptions` and strictly adopts `NSSecureCoding: YES` required by AppKit's `NSPersistentUIUnarchiver`.
- **No Private Frameworks:** Does NOT touch `SkyLight.framework` or undocumented `CGS*` calls.
- **SIP & Mac App Store Compatible:** Operates entirely within standard macOS sandbox and notarization boundaries.
