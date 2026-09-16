import Cocoa
import FlutterMacOS
import CoreImage

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    #if DEBUG
    // Development-only readback of Flutter's registered native texture.
    // RepaintBoundary screenshots omit external textures on some macOS hosts.
    let capture = FlutterMethodChannel(name: "skyway/texture_capture",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    capture.setMethodCallHandler { call, result in
      guard call.method == "capture", let id = call.arguments as? Int64,
            id != 0, let pointer = UnsafeRawPointer(bitPattern: Int(id)),
            let texture = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? FlutterTexture,
            let pixels = texture.copyPixelBuffer()?.takeRetainedValue() else {
        result(FlutterError(code: "capture", message: "Texture unavailable", details: nil))
        return
      }
      let image = CIImage(cvPixelBuffer: pixels)
      guard let cg = CIContext().createCGImage(image, from: image.extent),
            let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        result(FlutterError(code: "capture", message: "Readback failed", details: nil))
        return
      }
      result(FlutterStandardTypedData(bytes: png))
    }
    #endif

    super.awakeFromNib()
  }
}
