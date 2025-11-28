import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    
    // Set default window size
    let defaultSize = NSSize(width: 1080, height: 800)
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    let newOrigin = NSPoint(
      x: screenFrame.midX - defaultSize.width / 2,
      y: screenFrame.midY - defaultSize.height / 2
    )
    let newFrame = NSRect(origin: newOrigin, size: defaultSize)
    self.setFrame(newFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
