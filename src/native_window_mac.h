#ifndef SHELL_BROWSER_NATIVE_WINDOW_MAC_H_
#define SHELL_BROWSER_NATIVE_WINDOW_MAC_H_

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <string>

namespace electron {

/**
 * Handles AppKit NSWindowRestoration for Electron BrowserWindow.
 * Bridges macOS Mission Control Spaces and geometry preservation
 * across application restarts without private APIs.
 */
class NativeWindowMacRestoration {
 public:
  static void RegisterWindow(NSWindow* window, const std::string& identifier);
  static NSData* EncodeState(NSWindow* window);
  static bool RestoreState(NSWindow* window, NSData* data);
};

}  // namespace electron

#endif  // SHELL_BROWSER_NATIVE_WINDOW_MAC_H_
