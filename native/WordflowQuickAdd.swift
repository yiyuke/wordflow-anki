import AppKit
import Darwin
import Foundation

private final class QuickAddWindow: NSWindow {
    var submitHandler: (() -> Void)?
    var deckHandler: (() -> Void)?
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
        if modifiers.contains(.command), key == "d" {
            deckHandler?()
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
    private var deckButton: NSPopUpButton!
    private var addButton: NSButton!
    private var pinButton: NSButton!
    private var statusLabel: NSTextField!
    private var progress: NSProgressIndicator!
    private var keyMonitor: Any?
    private var showSignalSource: DispatchSourceSignal?
    private var previousApplication: NSRunningApplication?
    private var isLoadingDecks = false
    private var isSubmitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        installKeyboardMonitor()
        installShowSignalHandler()
        showWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        showSignalSource?.cancel()
        removePIDFile()
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
            contentRect: NSRect(x: 0, y: 0, width: 476, height: 350),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wordflow Quick Add"
        window.minSize = NSSize(width: 440, height: 330)
        window.maxSize = NSSize(width: 640, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("WordflowQuickAddWindowV2")
        window.submitHandler = { [weak self] in self?.submit(returnAfterSave: true) }
        window.deckHandler = { [weak self] in self?.showDeckMenu() }
        window.pinHandler = { [weak self] in self?.togglePin() }
        window.closeHandler = { [weak self] in self?.hideWindow() }

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let title = label("快速添加到 Anki", size: 21, weight: .bold, color: .labelColor)
        let subtitle = label("打开窗口：⌥⇧W", size: 13, weight: .semibold, color: .controlAccentColor)
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        pinButton = NSButton(checkboxWithTitle: "置顶", target: self, action: #selector(pinClicked))
        pinButton.font = .systemFont(ofSize: 13, weight: .medium)
        pinButton.contentTintColor = .labelColor
        pinButton.toolTip = "始终显示在其他窗口上方（⌘P）"
        pinButton.setAccessibilityIdentifier("pinButton")

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [titleStack, headerSpacer, pinButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let wordLabel = label("单词或短语", size: 13, weight: .semibold, color: .labelColor)
        let wordHeaderSpacer = NSView()
        wordHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let deckLabel = label("保存到", size: 12, weight: .medium, color: .secondaryLabelColor)
        deckButton = NSPopUpButton(frame: .zero, pullsDown: false)
        deckButton.controlSize = .small
        deckButton.font = .systemFont(ofSize: 12, weight: .medium)
        deckButton.target = self
        deckButton.action = #selector(deckChanged)
        deckButton.addItem(withTitle: "读取牌组…")
        deckButton.isEnabled = false
        deckButton.setAccessibilityIdentifier("deckButton")
        deckButton.setAccessibilityLabel("保存到 Anki 牌组")
        deckButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 138).isActive = true
        deckButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210).isActive = true
        let deckControl = NSStackView(views: [deckLabel, deckButton])
        deckControl.orientation = .horizontal
        deckControl.alignment = .centerY
        deckControl.spacing = 6
        let wordHeader = NSStackView(views: [wordLabel, wordHeaderSpacer, deckControl])
        wordHeader.orientation = .horizontal
        wordHeader.alignment = .centerY
        wordHeader.spacing = 10
        wordField = NSTextField()
        wordField.placeholderString = "例如：serendipity"
        wordField.font = .systemFont(ofSize: 16)
        wordField.delegate = self
        wordField.focusRingType = .default
        wordField.setAccessibilityIdentifier("wordField")

        let contextLabel = label("例句或上下文（可选）", size: 13, weight: .semibold, color: .labelColor)
        contextView = ContextTextView()
        contextView.font = .systemFont(ofSize: 15)
        contextView.isRichText = false
        contextView.isAutomaticQuoteSubstitutionEnabled = false
        contextView.isAutomaticDashSubstitutionEnabled = false
        contextView.textContainerInset = NSSize(width: 8, height: 7)
        contextView.setAccessibilityLabel("例句或上下文，可选")
        contextView.setAccessibilityIdentifier("contextField")
        contextView.focusWordHandler = { [weak self] in self?.focusWord() }
        contextView.focusNextHandler = { [weak self] in self?.focusAddButton() }
        contextView.submitHandler = { [weak self] in self?.submit(returnAfterSave: true) }

        let contextScroll = NSScrollView()
        contextScroll.borderType = .bezelBorder
        contextScroll.hasVerticalScroller = true
        contextScroll.autohidesScrollers = true
        contextScroll.documentView = contextView
        contextScroll.translatesAutoresizingMaskIntoConstraints = false
        contextScroll.heightAnchor.constraint(equalToConstant: 82).isActive = true

        progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        progress.isHidden = true

        statusLabel = label("", size: 13, weight: .medium, color: .secondaryLabelColor)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let statusSpacer = NSView()
        statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let statusRow = NSStackView(views: [progress, statusLabel, statusSpacer])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 7
        statusRow.detachesHiddenViews = true
        statusRow.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let hint = label("Tab 移动 · ⌘D 牌组 · ⌘↩ 保存返回 · Esc 返回", size: 12, weight: .medium, color: .secondaryLabelColor)
        addButton = NSButton(title: "加入 Anki", target: self, action: #selector(addClicked))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .large
        addButton.font = .systemFont(ofSize: 14, weight: .semibold)
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

        let stack = NSStackView(views: [header, wordHeader, wordField, contextLabel, contextScroll, statusRow, footer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(18, after: header)
        stack.setCustomSpacing(5, after: wordHeader)
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
            wordHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordField.heightAnchor.constraint(equalToConstant: 36),
            contextScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        wordField.nextKeyView = contextView
        contextView.nextKeyView = addButton
        addButton.nextKeyView = wordField
        applyPin(defaults.bool(forKey: "windowPinned"))
    }

    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isVisible, event.window === self.window else {
                return event
            }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

            if event.keyCode == 53 {
                self.hideWindow()
                return nil
            }
            if modifiers.contains(.command), key == "p" {
                self.togglePin()
                return nil
            }
            if modifiers.contains(.command), key == "d" {
                self.showDeckMenu()
                return nil
            }
            if modifiers.contains(.command), key == "q" {
                NSApp.terminate(nil)
                return nil
            }
            if modifiers.contains(.command), event.keyCode == 36 || event.keyCode == 76 {
                self.submit(returnAfterSave: true)
                return nil
            }
            return event
        }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }

    private func installShowSignalHandler() {
        Darwin.signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            self?.showWindow()
        }
        source.resume()
        showSignalSource = source
        writePIDFile()
    }

    private func pidFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Wordflow", isDirectory: true)
            .appendingPathComponent("quick-add.pid")
    }

    private func writePIDFile() {
        guard let url = pidFileURL() else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "\(ProcessInfo.processInfo.processIdentifier)\n".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // The launch path remains usable even if the optional activation PID cannot be saved.
        }
    }

    private func removePIDFile() {
        guard let url = pidFileURL(),
              let stored = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              stored == "\(ProcessInfo.processInfo.processIdentifier)" else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func rememberPreviousApplication() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        previousApplication = frontmost
    }

    private func showWindow() {
        rememberPreviousApplication()
        if !isSubmitting {
            statusLabel.stringValue = ""
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusWord()
        loadDecks()
    }

    private func hideWindow() {
        window.orderOut(nil)
        if let previousApplication, !previousApplication.isTerminated {
            if #available(macOS 14.0, *) {
                previousApplication.activate(options: [.activateAllWindows])
            } else {
                previousApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
        }
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

    private func showDeckMenu() {
        guard deckButton.isEnabled else {
            NSSound.beep()
            return
        }
        window.makeFirstResponder(deckButton)
        deckButton.performClick(nil)
    }

    private func selectedDeck() -> String {
        deckButton.selectedItem?.title ?? "Vocabulary Inbox"
    }

    private func serviceRequest(path: String, method: String = "GET", payload: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "http://127.0.0.1:8766\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("wordflow-local", forHTTPHeaderField: "X-Wordflow-Client")
        if let payload {
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        }
        request.timeoutInterval = 15
        return request
    }

    private func loadDecks() {
        guard !isLoadingDecks, let request = serviceRequest(path: "/api/decks") else { return }
        isLoadingDecks = true
        Task {
            defer { isLoadingDecks = false }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard http?.statusCode == 200,
                      json?["ok"] as? Bool == true,
                      let decks = json?["decks"] as? [String],
                      !decks.isEmpty else {
                    throw NSError(
                        domain: "Wordflow",
                        code: http?.statusCode ?? -1,
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String ?? "无法读取牌组"]
                    )
                }
                let selected = json?["selected"] as? String ?? decks[0]
                deckButton.removeAllItems()
                deckButton.addItems(withTitles: decks)
                deckButton.selectItem(withTitle: selected)
                deckButton.isEnabled = true
            } catch {
                if deckButton.numberOfItems == 0 || deckButton.itemTitles == ["读取牌组…"] {
                    deckButton.removeAllItems()
                    deckButton.addItem(withTitle: "Vocabulary Inbox")
                }
                deckButton.isEnabled = false
                statusLabel.textColor = .systemRed
                statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func deckChanged() {
        let deck = selectedDeck()
        focusWord()
        guard let request = serviceRequest(
            path: "/api/decks/select",
            method: "POST",
            payload: ["deck": deck]
        ) else { return }
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard http?.statusCode == 200, json?["ok"] as? Bool == true else {
                    throw NSError(
                        domain: "Wordflow",
                        code: http?.statusCode ?? -1,
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String ?? "牌组选择未保存"]
                    )
                }
            } catch {
                statusLabel.textColor = .systemRed
                statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === wordField else { return false }
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.insertTab(_:)) {
            focusContext()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submit(returnAfterSave: false)
            return true
        }
        return false
    }

    @objc private func addClicked() {
        submit(returnAfterSave: false)
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

    private func submit(returnAfterSave: Bool) {
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
        progress.isHidden = false
        progress.startAnimation(nil)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "正在生成词卡…"

        let payload: [String: Any] = [
            "text": word,
            "context": contextView.string.trimmingCharacters(in: .whitespacesAndNewlines),
            "deck": selectedDeck(),
            "source_title": "Wordflow 快速添加",
            "source_url": "",
            "source_type": "native-manual"
        ]

        guard let url = URL(string: "http://127.0.0.1:8766/api/capture") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("wordflow-local", forHTTPHeaderField: "X-Wordflow-Client")
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
                let savedDeck = json?["deck"] as? String ?? selectedDeck()
                finishSubmission(
                    message: duplicate
                        ? "“\(savedWord)” 已存在于 \(savedDeck)"
                        : "已加入 \(savedDeck)：\(savedWord)",
                    success: true
                )
                if !duplicate {
                    wordField.stringValue = ""
                    contextView.string = ""
                }
                if returnAfterSave {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                        self?.hideWindow()
                    }
                } else {
                    focusWord()
                }
            } catch {
                finishSubmission(message: error.localizedDescription, success: false)
            }
        }
    }

    private func finishSubmission(message: String, success: Bool) {
        isSubmitting = false
        progress.stopAnimation(nil)
        progress.isHidden = true
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
