#include "native_window_mac.h"
#include <Cocoa/Cocoa.h>
#include <napi.h>

@interface SpacesArchiverDelegate : NSObject <NSKeyedArchiverDelegate>
@property(nonatomic, assign) NSWindow* window;
@end

@implementation SpacesArchiverDelegate
- (id)archiver:(NSKeyedArchiver*)archiver willEncodeObject:(id)object {
  if (object == self.window) return nil;
  if ([object isKindOfClass:[NSView class]]) return nil;
  return object;
}
@end

@interface SpacesKeyedUnarchiver : NSKeyedUnarchiver
@property(nonatomic) BOOL shouldRestoreSpace;
@end

@implementation SpacesKeyedUnarchiver
- (BOOL)requiresSecureCoding {
  return YES;
}

- (id)_windowRestorationOptions {
  if (self.shouldRestoreSpace) {
    return [[NSClassFromString(@"NSWindowRestorationOptions") alloc] init];
  }
  return nil;
}
@end

namespace electron {

void NativeWindowMacRestoration::RegisterWindow(NSWindow* window, const std::string& identifier) {
  if (!window) return;
  NSString* nsId = [NSString stringWithUTF8String:identifier.c_str()];
  [window setIdentifier:nsId];
  [window setRestorable:YES];
}

NSData* NativeWindowMacRestoration::EncodeState(NSWindow* window) {
  if (!window) return nil;
  @try {
    NSKeyedArchiver* encoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    SpacesArchiverDelegate* delegate = [[SpacesArchiverDelegate alloc] init];
    delegate.window = window;
    encoder.delegate = delegate;

    [window encodeRestorableStateWithCoder:encoder];
    [encoder finishEncoding];
    return encoder.encodedData;
  } @catch (NSException* exception) {
    NSLog(@"[NativeWindowMacRestoration] Encode failed: %@", exception.reason);
    return nil;
  }
}

bool NativeWindowMacRestoration::RestoreState(NSWindow* window, NSData* data) {
  if (!window || !data || [data length] == 0) return false;
  @try {
    NSError* error = nil;
    SpacesKeyedUnarchiver* decoder =
        [[SpacesKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    if (error || !decoder) return false;

    decoder.shouldRestoreSpace = YES;

    if (@available(macOS 15, *)) {
      // _windowRestorationOptions handles macOS 15+
    } else {
      [NSUserDefaults.standardUserDefaults registerDefaults:@{
        @"NSWindowRestoresWorkspaceAtLaunch" : @YES
      }];
    }

    [window restoreStateWithCoder:decoder];
    return true;
  } @catch (NSException* exception) {
    NSLog(@"[NativeWindowMacRestoration] Restore failed: %@", exception.reason);
    return false;
  }
}

}  // namespace electron

// ============================================================================
// Node-API Binding Interface
// ============================================================================

static NSWindow* GetNSWindow(Napi::Value handle) {
  auto buf = handle.As<Napi::Buffer<uint8_t>>();
  NSView* view = *reinterpret_cast<NSView* __strong*>(buf.Data());
  return [view window];
}

static Napi::Value SetRestorationIdentifier(const Napi::CallbackInfo& info) {
  Napi::Env env = info.Env();
  if (info.Length() < 2 || !info[0].IsBuffer() || !info[1].IsString()) {
    Napi::TypeError::New(env, "Expected (handle: Buffer, id: string)").ThrowAsJavaScriptException();
    return env.Null();
  }

  NSWindow* win = GetNSWindow(info[0]);
  if (!win) return Napi::Boolean::New(env, false);

  std::string idStr = info[1].As<Napi::String>().Utf8Value();
  electron::NativeWindowMacRestoration::RegisterWindow(win, idStr);
  return Napi::Boolean::New(env, true);
}

static Napi::Value GetRestorableState(const Napi::CallbackInfo& info) {
  Napi::Env env = info.Env();
  if (info.Length() < 1 || !info[0].IsBuffer()) return env.Null();

  NSWindow* win = GetNSWindow(info[0]);
  if (!win) return env.Null();

  NSData* data = electron::NativeWindowMacRestoration::EncodeState(win);
  if (!data) return env.Null();

  return Napi::Buffer<uint8_t>::Copy(env, static_cast<const uint8_t*>(data.bytes), data.length);
}

static Napi::Value RestoreState(const Napi::CallbackInfo& info) {
  Napi::Env env = info.Env();
  if (info.Length() < 2 || !info[0].IsBuffer() || !info[1].IsBuffer()) return Napi::Boolean::New(env, false);

  NSWindow* win = GetNSWindow(info[0]);
  if (!win) return Napi::Boolean::New(env, false);

  auto buf = info[1].As<Napi::Buffer<uint8_t>>();
  NSData* data = [NSData dataWithBytes:buf.Data() length:buf.Length()];

  bool ok = electron::NativeWindowMacRestoration::RestoreState(win, data);
  return Napi::Boolean::New(env, ok);
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("setRestorationIdentifier", Napi::Function::New(env, SetRestorationIdentifier));
  exports.Set("getRestorableState", Napi::Function::New(env, GetRestorableState));
  exports.Set("restoreState", Napi::Function::New(env, RestoreState));
  return exports;
}

NODE_API_MODULE(native_window_mac, Init)
