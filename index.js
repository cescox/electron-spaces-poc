const { app } = require('electron');
const path = require('path');
const fs = require('fs');

const native = require('./build/Release/native_window_mac');

function getStateFile() {
  if (!app || typeof app.getPath !== 'function') return null;
  return path.join(app.getPath('userData'), 'WindowRestoration', 'session.json');
}

const activeWindows = new Map();

/**
 * Proposed Electron API:
 * In Electron core, this will be handled automatically when
 * `options.restorationIdentifier` is set on BrowserWindow.
 */
function enableRestoration(win, restorationIdentifier) {
  if (process.platform !== 'darwin' || !restorationIdentifier) return;

  activeWindows.set(restorationIdentifier, win);

  const handle = win.getNativeWindowHandle();
  native.setRestorationIdentifier(handle, restorationIdentifier);

  const stateFile = getStateFile();
  if (stateFile && fs.existsSync(stateFile)) {
    try {
      const stateStore = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      if (stateStore[restorationIdentifier]) {
        const buf = Buffer.from(stateStore[restorationIdentifier], 'base64');
        const restored = native.restoreState(handle, buf);
        win.__restoredFromState = restored;
      }
    } catch (e) {
      console.warn(`[Restoration] Failed to restore '${restorationIdentifier}':`, e.message);
    }
  }

  win.on('closed', () => {
    activeWindows.delete(restorationIdentifier);
  });
}

function flushSessionState() {
  if (process.platform !== 'darwin') return;
  const stateFile = getStateFile();
  if (!stateFile) return;

  const stateStore = {};
  for (const [id, win] of activeWindows.entries()) {
    if (!win.isDestroyed()) {
      const buf = native.getRestorableState(win.getNativeWindowHandle());
      if (buf) {
        stateStore[id] = buf.toString('base64');
      }
    }
  }

  try {
    fs.mkdirSync(path.dirname(stateFile), { recursive: true });
    fs.writeFileSync(stateFile, JSON.stringify(stateStore, null, 2));
  } catch (e) {
    console.warn('[Restoration] Failed to flush state:', e.message);
  }
}

if (app && typeof app.on === 'function') {
  app.on('before-quit', flushSessionState);
}

module.exports = {
  enableRestoration,
  getRestorableState: (win) => native.getRestorableState(win.getNativeWindowHandle()),
  restoreState: (win, buf) => native.restoreState(win.getNativeWindowHandle(), buf),
};
