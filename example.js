const { app, BrowserWindow } = require('electron');
const { enableRestoration } = require('./index');

function createSampleWindow(id, title, color, defaultX) {
  const win = new BrowserWindow({
    width: 600,
    height: 420,
    x: defaultX,
    y: 180,
    title,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  enableRestoration(win, id);

  const isRestored = win.__restoredFromState === true;
  const statusBadge = isRestored
    ? `<span style="background: #22c55e; color: #000; padding: 4px 8px; border-radius: 4px; font-weight: bold;">✅ Restored to target Desktop by AppKit</span>`
    : `<span style="background: #eab308; color: #000; padding: 4px 8px; border-radius: 4px; font-weight: bold;">📍 Initial Launch</span>`;

  const html = `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            margin: 0;
            padding: 28px;
            background: ${color};
            color: #ffffff;
            line-height: 1.5;
          }
          h1 { margin: 0 0 10px 0; font-size: 20px; }
          .card {
            background: rgba(0, 0, 0, 0.28);
            border-radius: 8px;
            padding: 16px;
            margin-top: 14px;
          }
          code {
            background: rgba(255, 255, 255, 0.2);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: ui-monospace, Menlo, monospace;
          }
        </style>
      </head>
      <body>
        <h1>${title}</h1>
        <div style="margin-top: 8px;">${statusBadge}</div>
        <div class="card">
          <strong>Restoration Identifier:</strong> <code>${id}</code>
        </div>
        <div class="card">
          <strong>Testing instructions:</strong>
          <ol style="margin: 8px 0 0 0; padding-left: 20px;">
            <li>Drag this window to your desired macOS Desktop/Space.</li>
            <li>Drag the other window to a different Space.</li>
            <li>Quit with <code>Cmd + Q</code>.</li>
            <li>Relaunch: notice each window automatically returns to its respective Space.</li>
          </ol>
        </div>
      </body>
    </html>
  `;

  win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
  return win;
}

app.whenReady().then(() => {
  createSampleWindow('editor-workspace-alpha', 'Window Alpha (Move to Desktop 1)', '#1e3a8a', 120);
  createSampleWindow('editor-workspace-beta', 'Window Beta (Move to Desktop 2)', '#14532d', 760);
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
