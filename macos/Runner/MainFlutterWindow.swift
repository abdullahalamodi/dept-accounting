import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var scopedFolders: [String: URL] = [:]

  override func awakeFromNib() {
    titleVisibility = .hidden
    isRestorable = false

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    var windowFrame = frameRect(forContentRect: NSRect(x: 0, y: 0, width: 1440, height: 900))
    if let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame {
      windowFrame.size.width = min(windowFrame.width, visibleFrame.width * 0.9)
      windowFrame.size.height = min(windowFrame.height, visibleFrame.height * 0.9)
      windowFrame.origin.x = visibleFrame.midX - windowFrame.width / 2
      windowFrame.origin.y = visibleFrame.midY - windowFrame.height / 2
    }
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(name: "dept_accounting/folder_access", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let arguments = call.arguments as? [String: String] else {
        result(FlutterError(code: "arguments", message: "Invalid folder arguments", details: nil)); return
      }
      do {
        switch call.method {
        case "bookmark":
          guard let path = arguments["path"] else { result(FlutterMethodNotImplemented); return }
          let url = URL(fileURLWithPath: path, isDirectory: true)
          let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          result(data.base64EncodedString())
        case "resolve":
          guard let encoded = arguments["bookmark"], let data = Data(base64Encoded: encoded) else { result(FlutterMethodNotImplemented); return }
          var stale = false
          let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
          if self.scopedFolders[url.path] == nil {
            guard url.startAccessingSecurityScopedResource() else {
              result(FlutterError(code: "folder_access", message: "Select the backup folder again", details: nil)); return
            }
            self.scopedFolders[url.path] = url
          }
          let refreshed = stale ? try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) : data
          result(["path": url.path, "bookmark": refreshed.base64EncodedString()])
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "folder_access", message: error.localizedDescription, details: nil)) }
    }

    super.awakeFromNib()
  }
}
