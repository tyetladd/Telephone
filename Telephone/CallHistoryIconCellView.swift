import Cocoa

final class CallHistoryIconCellView: NSTableCellView {
    private var didUnbind = false

    override var objectValue: Any? {
        didSet {
            super.objectValue = objectValue
            if !didUnbind {
                unbind(.hidden)
                imageView?.unbind(.hidden)
                didUnbind = true
            }
            guard let record = objectValue as? PresentationCallHistoryRecord else {
                imageView?.isHidden = true
                return
            }
            isHidden = false
            imageView?.isHidden = false
            if record.isMessage {
                let name = record.isIncoming ? "bubble.left" : "bubble.left.fill"
                imageView?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
                imageView?.contentTintColor = record.isIncoming ? .secondaryLabelColor : .labelColor
            } else if record.isIncoming {
                imageView?.image = NSImage(systemSymbolName: "phone.arrow.down.left", accessibilityDescription: nil)
                imageView?.contentTintColor = record.isMissed ? .systemRed : .secondaryLabelColor
            } else {
                imageView?.image = NSImage(systemSymbolName: "phone.arrow.up.right", accessibilityDescription: nil)
                imageView?.contentTintColor = .secondaryLabelColor
            }
        }
    }
}
