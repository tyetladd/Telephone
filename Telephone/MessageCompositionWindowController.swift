import Cocoa

final class MessageCompositionWindowController: NSWindowController {
    convenience init(viewController: MessageCompositionViewController) {
        let window = NSWindow(contentViewController: viewController)
        window.title = NSLocalizedString("Send Message", comment: "Send message window title")
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 200))
        self.init(window: window)
    }
}
