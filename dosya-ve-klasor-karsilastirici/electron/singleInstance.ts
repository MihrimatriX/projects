import { app, BrowserWindow } from "electron";

export function enforceSingleInstance(onSecondInstance: () => void): boolean {
  const gotLock = app.requestSingleInstanceLock();
  if (!gotLock) {
    app.quit();
    return false;
  }
  app.on("second-instance", () => {
    const win = BrowserWindow.getAllWindows()[0];
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
    onSecondInstance();
  });
  return true;
}
