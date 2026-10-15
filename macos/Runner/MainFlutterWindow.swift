import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var scopedFolders: [String: URL] = [:]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(name: "dukan/folder_access", binaryMessenger: flutterViewController.engine.binaryMessenger)
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
