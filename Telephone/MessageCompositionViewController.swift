import Cocoa

final class MessageCompositionViewController: NSViewController {
    var destination: String = ""
    var onSend: ((String) -> Void)?

    private let destinationLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView(frame: .zero)
    private let textView = NSTextView(frame: .zero)
    private let sendButton = NSButton(title: NSLocalizedString("Send", comment: "Send button"),
                                      target: nil,
                                      action: #selector(send(_:)))
    private let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: "Cancel button"),
                                        target: nil,
                                        action: #selector(cancelAction(_:)))

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sendButton.target = self
        cancelButton.target = self

        destinationLabel.stringValue = destination

        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        sendButton.bezelStyle = .rounded
        sendButton.keyEquivalent = "\r"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for v in [destinationLabel, scrollView, sendButton, cancelButton] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            destinationLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            destinationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            destinationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: destinationLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.heightAnchor.constraint(equalToConstant: 80),

            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            sendButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
    }

    @objc private func send(_ sender: Any) {
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        view.window?.close()
    }

    @objc private func cancelAction(_ sender: Any) {
        view.window?.close()
    }
}
