import AppKit
import Foundation

private final class QuickAddWindow: NSWindow {
    var submitHandler: (() -> Void)?
    var pinHandler: (() -> Void)?
    var closeHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.keyCode == 53 {
            closeHandler?()
            return
        }
        if modifiers.contains(.command), key == "p" {
            pinHandler?()
            return
        }
        if modifiers.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
            submitHandler?()
            return
        }
        super.keyDown(with: event)
    }
}
private final class ContextTextView: NSTextView {
    var focusWordHandler: (() -> Void)?
    var focusNextHandler: (() -> Void)?
    var submitHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
            submitHandler?()
            return
        }
        if event.keyCode == 48 {
            if modifiers.contains(.shift) {
                focusWordHandler?()
            } else {
                focusNextHandler?()
            }
            return
        }
        if event.keyCode == 126, selectedRange().location == 0 {
            focusWordHandler?()
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    private let defaults = UserDefaults.standard
    private var window: QuickAddWindow!
    private var wordField: NSTextField!
    private var contextView: ContextTextView!
    private var addButton: NSButton!
    private var pinButton: NSButton!
    private var statusLabel: NSTextField!
    private var progress: NSProgressIndicator!
    private var isSubmitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    private func buildWindow() {
        window = QuickAddWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 330),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wordflow Quick Add"
        window.minSize = NSSize(width: 420, height: 300)
        window.maxSize = NSSize(width: 640, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("WordflowQuickAddWindow")
        window.submitHandler = { [weak self] in self?.submit() }
        window.pinHandler = { [weak self] in self?.togglePin() }
        window.closeHandler = { [weak self] in self?.hideWindow() }

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let title = label("快速添加到 Anki", size: 20, weight: .semibold, color: .labelColor)
        let subtitle = label("输入单词，可选填看到它的原句", size: 12, weight: .regular, color: .secondaryLabelColor)
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        pinButton = NSButton(checkboxWithTitle: "置顶", target: self, action: #selector(pinClicked))
        pinButton.toolTip = "始终显示在其他窗口上方（⌘P）"
        pinButton.setAccessibilityIdentifier("pinButton")

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [titleStack, headerSpacer, pinButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let wordLabel = label("单词或短语", size: 12, weight: .medium, color: .secondaryLabelColor)
        wordField = NSTextField()
        wordField.placeholderString = "例如：serendipity"
        wordField.font = .systemFont(ofSize: 15)
        wordField.delegate = self
        wordField.focusRingType = .default
        wordField.setAccessibilityIdentifier("wordField")

        let contextLabel = label("上下文（可选）", size: 12, weight: .medium, color: .secondaryLabelColor)
        contextView = ContextTextView()
        contextView.font = .systemFont(ofSize: 14)
        contextView.isRichText = false
        contextView.isAutomaticQuoteSubstitutionEnabled = false
        contextView.isAutomaticDashSubstitutionEnabled = false
        contextView.textContainerInset = NSSize(width: 8, height: 7)
        contextView.setAccessibilityLabel("上下文，可选")
        contextView.setAccessibilityIdentifier("contextField")
        contextView.focusWordHandler = { [weak self] in self?.focusWord() }
        contextView.focusNextHandler = { [weak self] in self?.focusAddButton() }
        contextView.submitHandler = { [weak self] in self?.submit() }

        let contextScroll = NSScrollView()
        contextScroll.borderType = .bezelBorder
        contextScroll.hasVerticalScroller = true
        contextScroll.autohidesScrollers = true
        contextScroll.documentView = contextView
        contextScroll.translatesAutoresizingMaskIntoConstraints = false
        contextScroll.heightAnchor.constraint(equalToConstant: 76).isActive = true

        progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false

        statusLabel = label("", size: 12, weight: .regular, color: .secondaryLabelColor)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let statusSpacer = NSView()
        statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let statusRow = NSStackView(views: [progress, statusLabel, statusSpacer])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 7
        statusRow.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let hint = label("↓ / Tab 切换  ·  ⌘↩ 保存  ·  Esc 关闭", size: 11, weight: .regular, color: .tertiaryLabelColor)
        addButton = NSButton(title: "加入 Anki", target: self, action: #selector(addClicked))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .large
        addButton.keyEquivalent = "\r"
        addButton.keyEquivalentModifierMask = [.command]
        addButton.setAccessibilityIdentifier("addButton")
        addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true

        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [hint, footerSpacer, addButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12

        let stack = NSStackView(views: [header, wordLabel, wordField, contextLabel, contextScroll, statusRow, footer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(18, after: header)
        stack.setCustomSpacing(5, after: wordLabel)
        stack.setCustomSpacing(12, after: wordField)
        stack.setCustomSpacing(5, after: contextLabel)
        stack.setCustomSpacing(9, after: contextScroll)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordField.heightAnchor.constraint(equalToConstant: 34),
            contextScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        wordField.nextKeyView = contextView
        contextView.nextKeyView = addButton
        addButton.nextKeyView = wordField
        applyPin(defaults.bool(forKey: "windowPinned"))
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }

    private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusWord()
    }

    private func hideWindow() {
        window.orderOut(nil)
    }

    private func focusWord() {
        window.makeFirstResponder(wordField)
    }

    private func focusContext() {
        window.makeFirstResponder(contextView)
    }

    private func focusAddButton() {
        window.makeFirstResponder(addButton)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === wordField else { return false }
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.insertTab(_:)) {
            focusContext()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit()
            return true
        }
        return false
    }

    @objc private func addClicked() {
        submit()
    }

    @objc private func pinClicked() {
        applyPin(pinButton.state == .on)
    }

    private func togglePin() {
        applyPin(window.level != .floating)
    }

    private func applyPin(_ pinned: Bool) {
        window.level = pinned ? .floating : .normal
        window.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
        pinButton.state = pinned ? .on : .off
        defaults.set(pinned, forKey: "windowPinned")
    }

    private func submit() {
        guard !isSubmitting else { return }
        let word = wordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "请先输入一个单词或短语"
            NSSound.beep()
            focusWord()
            return
        }

        isSubmitting = true
        setControlsEnabled(false)
        progress.startAnimation(nil)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "正在生成词卡…"

        let payload: [String: Any] = [
            "text": word,
            "context": contextView.string.trimmingCharacters(in: .whitespacesAndNewlines),
            "source_title": "Wordflow 快速添加",
            "source_url": "",
            "source_type": "native-manual"
        ]

        guard let url = URL(string: "http://127.0.0.1:8766/api/capture") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 120

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard http?.statusCode == 200, json?["ok"] as? Bool == true else {
                    throw NSError(
                        domain: "Wordflow",
                        code: http?.statusCode ?? -1,
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String ?? "加入失败"]
                    )
                }
                let duplicate = json?["duplicate"] as? Bool ?? false
                let card = json?["card"] as? [String: Any]
                let savedWord = card?["word"] as? String ?? word
                finishSubmission(message: duplicate ? "“\(savedWord)” 已经在 Anki 里" : "已加入：\(savedWord)", success: true)
                if !duplicate {
                    wordField.stringValue = ""
                    contextView.string = ""
                }
                focusWord()
            } catch {
                finishSubmission(message: error.localizedDescription, success: false)
            }
        }
    }

    private func finishSubmission(message: String, success: Bool) {
        isSubmitting = false
        progress.stopAnimation(nil)
        setControlsEnabled(true)
        statusLabel.textColor = success ? .systemGreen : .systemRed
        statusLabel.stringValue = message
    }

    private func setControlsEnabled(_ enabled: Bool) {
        wordField.isEnabled = enabled
        contextView.isEditable = enabled
        addButton.isEnabled = enabled
    }
}

@main
private struct WordflowQuickAdd {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
