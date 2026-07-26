import AppKit
import Darwin
import Foundation

@MainActor
private enum Copy {
    static var preference = "auto"

    static let systemLanguageCode: String = {
        let override = ProcessInfo.processInfo.environment["WORDFLOW_UI_LANGUAGE"]?.lowercased()
        if override == "zh" || override == "en" { return override! }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
    }()
    static var languageCode: String {
        preference == "zh" || preference == "en" ? preference : systemLanguageCode
    }
    static var isChinese: Bool { languageCode == "zh" }

    static func text(_ chinese: String, _ english: String) -> String {
        isChinese ? chinese : english
    }
}

private enum Brand {
    static let primary = NSColor(
        name: NSColor.Name("WordflowPrimary"),
        dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(
                srgbRed: isDark ? 23.0 / 255.0 : 6.0 / 255.0,
                green: isDark ? 178.0 / 255.0 : 118.0 / 255.0,
                blue: isDark ? 106.0 / 255.0 : 71.0 / 255.0,
                alpha: 1
            )
        }
    )

    static let selectionBackground = NSColor(
        name: NSColor.Name("WordflowSelectionBackground"),
        dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(
                srgbRed: isDark ? 29.0 / 255.0 : 232.0 / 255.0,
                green: isDark ? 74.0 / 255.0 : 245.0 / 255.0,
                blue: isDark ? 53.0 / 255.0 : 237.0 / 255.0,
                alpha: 1
            )
        }
    )
}

private final class InputSurfaceView: NSView {
    var isFocused = false {
        didSet {
            guard oldValue != isFocused else { return }
            needsDisplay = true
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = NSColor(
            calibratedWhite: isDark ? 0.16 : 0.96,
            alpha: 1
        ).cgColor
        layer?.borderColor = (
            isFocused
                ? Brand.primary.withAlphaComponent(isDark ? 0.9 : 0.62)
                : NSColor(
                    srgbRed: isDark ? 0.28 : 0.82,
                    green: isDark ? 0.33 : 0.84,
                    blue: isDark ? 0.40 : 0.87,
                    alpha: 1
                )
        ).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 9
        layer?.masksToBounds = true
    }
}

private final class QuickAddWindow: NSWindow {
    var submitHandler: (() -> Void)?
    var deckHandler: (() -> Void)?
    var pinHandler: (() -> Void)?
    var closeHandler: (() -> Void)?
    var selectAllHandler: (() -> Bool)?

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
        if modifiers.contains(.command), key == "a", selectAllHandler?() == true {
            return
        }
        if modifiers.contains(.command) && (event.keyCode == 36 || event.keyCode == 76) {
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
    var focusChangedHandler: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusChangedHandler?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { focusChangedHandler?(false) }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) && (event.keyCode == 36 || event.keyCode == 76) {
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
    private let defaultContentSize = NSSize(width: 468, height: 379)
    private var window: QuickAddWindow!
    private var wordField: NSTextField!
    private var contextView: ContextTextView!
    private var wordSurface: InputSurfaceView!
    private var contextSurface: InputSurfaceView!
    private var deckButton: NSPopUpButton!
    private var addButton: NSButton!
    private var pinButton: NSButton!
    private var languageButton: NSPopUpButton!
    private var statusLabel: NSTextField!
    private var progress: NSProgressIndicator!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var wordLabel: NSTextField!
    private var deckLabel: NSTextField!
    private var contextLabel: NSTextField!
    private var hintLabel: NSTextField!
    private var keyMonitor: Any?
    private var showSignalSource: DispatchSourceSignal?
    private var previousApplication: NSRunningApplication?
    private var availableDecks: [String] = []
    private var activeDeck = "Vocabulary Inbox"
    private var statusGeneration = 0
    private var isLoadingDecks = false
    private var isLoadingLanguage = false
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
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wordflow Quick Add"
        window.minSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: defaultContentSize)
        ).size
        window.maxSize = NSSize(width: 660, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("WordflowQuickAddWindowV3")
        window.submitHandler = { [weak self] in self?.submit(returnAfterSave: true) }
        window.deckHandler = { [weak self] in self?.showDeckMenu() }
        window.pinHandler = { [weak self] in self?.togglePin() }
        window.closeHandler = { [weak self] in self?.hideWindow() }
        window.selectAllHandler = { [weak self] in self?.selectAllInFocusedInput() ?? false }

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        titleLabel = label(Copy.text("快速添加到 Anki", "Quick Add to Anki"), size: 21, weight: .bold, color: .labelColor)
        subtitleLabel = label(Copy.text("打开窗口：⌥⇧W", "Open window: ⌥⇧W"), size: 13, weight: .semibold, color: Brand.primary)
        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        pinButton = NSButton(
            image: NSImage(systemSymbolName: "pin", accessibilityDescription: nil) ?? NSImage(),
            target: self,
            action: #selector(pinClicked)
        )
        pinButton.setButtonType(.momentaryChange)
        pinButton.isBordered = false
        pinButton.focusRingType = .none
        pinButton.imagePosition = .imageOnly
        pinButton.imageScaling = .scaleProportionallyDown
        pinButton.setAccessibilityIdentifier("pinButton")
        pinButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        pinButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        languageButton = NSPopUpButton(frame: .zero, pullsDown: false)
        languageButton.controlSize = .small
        languageButton.font = .systemFont(ofSize: 12, weight: .medium)
        languageButton.target = self
        languageButton.action = #selector(languageChanged)
        languageButton.setAccessibilityIdentifier("languageButton")
        languageButton.widthAnchor.constraint(equalToConstant: 82).isActive = true
        configureLanguageButton()

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [titleStack, headerSpacer, languageButton, pinButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        wordLabel = label(Copy.text("单词或短语", "Word or phrase"), size: 14, weight: .semibold, color: .labelColor)
        let wordHeaderSpacer = NSView()
        wordHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        deckLabel = label(Copy.text("牌组", "Deck"), size: 14, weight: .semibold, color: .labelColor)
        deckButton = NSPopUpButton(frame: .zero, pullsDown: true)
        deckButton.controlSize = .regular
        deckButton.font = .systemFont(ofSize: 14, weight: .medium)
        deckButton.addItem(withTitle: Copy.text("读取牌组…", "Loading decks…"))
        deckButton.isEnabled = false
        deckButton.setAccessibilityIdentifier("deckButton")
        deckButton.setAccessibilityLabel(Copy.text("保存到 Anki 牌组", "Save to Anki deck"))
        deckButton.toolTip = Copy.text(
            "这里列出 Anki 中的真实牌组，并记住上次选择",
            "Lists your actual Anki decks and remembers the last choice"
        )
        deckButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 164).isActive = true
        deckButton.widthAnchor.constraint(lessThanOrEqualToConstant: 230).isActive = true
        deckButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let deckControl = NSStackView(views: [deckLabel, deckButton])
        deckControl.orientation = .horizontal
        deckControl.alignment = .centerY
        deckControl.spacing = 9
        let wordHeader = NSStackView(views: [wordLabel, wordHeaderSpacer, deckControl])
        wordHeader.orientation = .horizontal
        wordHeader.alignment = .centerY
        wordHeader.spacing = 16
        wordField = NSTextField()
        wordField.placeholderString = Copy.text("例如：serendipity", "e.g. serendipity")
        wordField.font = .systemFont(ofSize: 16)
        wordField.delegate = self
        wordField.isBezeled = false
        wordField.drawsBackground = false
        wordField.focusRingType = .none
        wordField.usesSingleLineMode = true
        wordField.setAccessibilityIdentifier("wordField")
        wordField.translatesAutoresizingMaskIntoConstraints = false

        wordSurface = InputSurfaceView()
        wordSurface.translatesAutoresizingMaskIntoConstraints = false
        wordSurface.addSubview(wordField)
        NSLayoutConstraint.activate([
            wordField.leadingAnchor.constraint(equalTo: wordSurface.leadingAnchor, constant: 12),
            wordField.trailingAnchor.constraint(equalTo: wordSurface.trailingAnchor, constant: -12),
            wordField.centerYAnchor.constraint(equalTo: wordSurface.centerYAnchor)
        ])

        contextLabel = label(Copy.text("例句或上下文（可选）", "Example or context (optional)"), size: 14, weight: .semibold, color: .labelColor)
        contextView = ContextTextView()
        contextView.font = .systemFont(ofSize: 15)
        contextView.isRichText = false
        contextView.drawsBackground = false
        contextView.isAutomaticQuoteSubstitutionEnabled = false
        contextView.isAutomaticDashSubstitutionEnabled = false
        contextView.textContainerInset = NSSize(width: 10, height: 9)
        contextView.setAccessibilityLabel(Copy.text("例句或上下文，可选", "Example or context, optional"))
        contextView.setAccessibilityIdentifier("contextField")
        contextView.focusWordHandler = { [weak self] in self?.focusWord() }
        contextView.focusNextHandler = { [weak self] in self?.focusAddButton() }
        contextView.submitHandler = { [weak self] in self?.submit(returnAfterSave: true) }
        contextView.focusChangedHandler = { [weak self] focused in
            self?.contextSurface.isFocused = focused
        }
        applyTextBranding(to: contextView)

        let contextScroll = NSScrollView()
        contextScroll.borderType = .noBorder
        contextScroll.focusRingType = .none
        contextScroll.drawsBackground = false
        contextScroll.hasVerticalScroller = true
        contextScroll.autohidesScrollers = true
        contextScroll.documentView = contextView
        contextScroll.translatesAutoresizingMaskIntoConstraints = false

        contextSurface = InputSurfaceView()
        contextSurface.translatesAutoresizingMaskIntoConstraints = false
        contextSurface.addSubview(contextScroll)
        NSLayoutConstraint.activate([
            contextScroll.leadingAnchor.constraint(equalTo: contextSurface.leadingAnchor, constant: 1),
            contextScroll.trailingAnchor.constraint(equalTo: contextSurface.trailingAnchor, constant: -1),
            contextScroll.topAnchor.constraint(equalTo: contextSurface.topAnchor, constant: 1),
            contextScroll.bottomAnchor.constraint(equalTo: contextSurface.bottomAnchor, constant: -1)
        ])

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

        hintLabel = label(Copy.text(
            "↓/Tab 移动 · ⌘D 牌组 · ⌘↩ 保存切回 · Esc 关闭",
            "Tab move · ⌘D deck · ⌘↩ return · Esc close"
        ), size: 12, weight: .medium, color: .secondaryLabelColor)
        addButton = NSButton(title: Copy.text("加入 Anki", "Add to Anki"), target: self, action: #selector(addClicked))
        addButton.bezelStyle = .rounded
        addButton.bezelColor = Brand.primary
        addButton.controlSize = .large
        addButton.font = .systemFont(ofSize: 14, weight: .semibold)
        addButton.focusRingType = .none
        addButton.keyEquivalent = "\r"
        addButton.keyEquivalentModifierMask = [.command]
        addButton.setAccessibilityIdentifier("addButton")
        addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true

        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [hintLabel, footerSpacer, addButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12

        let stack = NSStackView(views: [header, wordHeader, wordSurface, contextLabel, contextSurface, statusRow, footer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(20, after: header)
        stack.setCustomSpacing(9, after: wordHeader)
        stack.setCustomSpacing(18, after: wordSurface)
        stack.setCustomSpacing(9, after: contextLabel)
        stack.setCustomSpacing(10, after: contextSurface)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordSurface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            wordSurface.heightAnchor.constraint(equalToConstant: 42),
            contextSurface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            contextSurface.heightAnchor.constraint(equalToConstant: 88),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        wordField.nextKeyView = contextView
        contextView.nextKeyView = addButton
        addButton.nextKeyView = wordField
        applyPin(defaults.bool(forKey: "windowPinned"))
        applyLanguage()
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
            if modifiers.contains(.command), key == "a", self.selectAllInFocusedInput() {
                return nil
            }
            if modifiers.contains(.command), key == "q" {
                NSApp.terminate(nil)
                return nil
            }
            if modifiers.contains(.command) && (event.keyCode == 36 || event.keyCode == 76) {
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

    private func shortMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains("Anki 启动失败") || message.localizedCaseInsensitiveContains("could not open Anki") {
            return Copy.text("Anki 启动失败，请手动打开", "Could not open Anki")
        }
        if message.contains("AnkiConnect") || message.contains("Anki 未连接") || message.contains("连接中断")
            || message.localizedCaseInsensitiveContains("Anki is not connected") {
            return Copy.text("Anki 未连接，请稍后重试", "Anki is not connected")
        }
        if message.contains("OPENAI_API_KEY") || message.localizedCaseInsensitiveContains("API Key") {
            return Copy.text("请先配置 OpenAI API Key", "Set up your OpenAI API key first")
        }
        if message.localizedCaseInsensitiveContains("OpenAI") || message.contains("网络连接失败")
            || message.localizedCaseInsensitiveContains("network error") {
            return Copy.text("网络连接失败，请稍后重试", "Network error — try again")
        }
        if message.localizedCaseInsensitiveContains("could not connect") || message.contains("无法连接本地服务")
            || message.localizedCaseInsensitiveContains("local service") {
            return Copy.text("Wordflow 服务未连接", "Wordflow service is not connected")
        }
        if message.contains("牌组不存在") || message.localizedCaseInsensitiveContains("deck does not exist") {
            return Copy.text("Anki 牌组不存在", "Anki deck not found")
        }
        let limit = Copy.isChinese ? 42 : 58
        guard message.count > limit else { return message }
        return String(message.prefix(limit - 1)) + "…"
    }

    private func showStatus(
        _ message: String,
        color: NSColor = .secondaryLabelColor,
        clearAfter delay: TimeInterval? = nil
    ) {
        statusGeneration += 1
        let generation = statusGeneration
        statusLabel.textColor = color
        statusLabel.stringValue = message
        guard let delay, !message.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.statusGeneration == generation else { return }
            self.statusLabel.stringValue = ""
        }
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
        if !window.isVisible {
            restoreDefaultWindowSize()
        }
        if !isSubmitting {
            showStatus("")
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusWord()
        loadLanguageSetting()
        loadDecks()
    }

    private func restoreDefaultWindowSize() {
        let desiredSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: defaultContentSize)
        ).size
        var frame = window.frame
        let top = frame.maxY
        frame.size = desiredSize
        frame.origin.y = top - desiredSize.height
        if let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        }
        window.setFrame(frame, display: false)
    }

    private func hideWindow() {
        window.orderOut(nil)
        activatePreviousApplication()
    }

    private func activatePreviousApplication() {
        window.resignKey()
        NSApp.deactivate()
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
        wordSurface.isFocused = true
        contextSurface.isFocused = false
        if let editor = wordField.currentEditor() as? NSTextView {
            applyTextBranding(to: editor)
        }
    }

    private func focusContext() {
        window.makeFirstResponder(contextView)
        wordSurface.isFocused = false
        contextSurface.isFocused = true
    }

    private func focusAddButton() {
        window.makeFirstResponder(addButton)
        wordSurface.isFocused = false
        contextSurface.isFocused = false
    }

    private func applyTextBranding(to textView: NSTextView) {
        textView.insertionPointColor = Brand.primary
        textView.selectedTextAttributes = [
            .backgroundColor: Brand.selectionBackground,
            .foregroundColor: NSColor.labelColor,
        ]
    }

    private func selectAllInFocusedInput() -> Bool {
        if let editor = window.firstResponder as? NSTextView,
           editor === contextView || editor === wordField.currentEditor() {
            editor.selectAll(nil)
            return true
        }
        if window.firstResponder === wordField {
            wordField.selectText(nil)
            return true
        }
        return false
    }

    private func configureLanguageButton() {
        let selected = Copy.preference
        languageButton.removeAllItems()
        let choices = [
            ("auto", Copy.text("自动", "Auto")),
            ("zh", "中文"),
            ("en", "English"),
        ]
        for (value, title) in choices {
            languageButton.addItem(withTitle: title)
            languageButton.lastItem?.representedObject = value
        }
        if let item = languageButton.itemArray.first(where: { ($0.representedObject as? String) == selected }) {
            languageButton.select(item)
        }
        languageButton.toolTip = Copy.text("界面与词卡解释语言", "Interface and card language")
        languageButton.setAccessibilityLabel(Copy.text("语言", "Language"))
    }

    private func applyLanguage() {
        window.title = Copy.text("Wordflow 快速添加", "Wordflow Quick Add")
        titleLabel.stringValue = Copy.text("快速添加到 Anki", "Quick Add to Anki")
        subtitleLabel.stringValue = Copy.text("打开窗口：⌥⇧W", "Open window: ⌥⇧W")
        wordLabel.stringValue = Copy.text("单词或短语", "Word or phrase")
        deckLabel.stringValue = Copy.text("牌组", "Deck")
        contextLabel.stringValue = Copy.text("例句或上下文（可选）", "Example or context (optional)")
        hintLabel.stringValue = Copy.text(
            "↓/Tab 移动 · ⌘D 牌组 · ⌘↩ 保存切回 · Esc 关闭",
            "Tab move · ⌘D deck · ⌘↩ return · Esc close"
        )
        wordField.placeholderString = Copy.text("例如：serendipity", "e.g. serendipity")
        contextView.setAccessibilityLabel(Copy.text("例句或上下文，可选", "Example or context, optional"))
        deckButton.setAccessibilityLabel(Copy.text("保存到 Anki 牌组", "Save to Anki deck"))
        deckButton.toolTip = Copy.text(
            "这里列出 Anki 中的真实牌组，并记住上次选择",
            "Lists your actual Anki decks and remembers the last choice"
        )
        pinButton.toolTip = Copy.text("始终显示在其他窗口上方（⌘P）", "Keep above other windows (⌘P)")
        pinButton.setAccessibilityLabel(Copy.text("置顶", "Pin"))
        addButton.title = Copy.text("加入 Anki", "Add to Anki")
        configureLanguageButton()
        updatePinAppearance()
    }

    private func loadLanguageSetting() {
        guard !isLoadingLanguage, let request = serviceRequest(path: "/api/settings") else { return }
        isLoadingLanguage = true
        Task {
            defer { isLoadingLanguage = false }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard http?.statusCode == 200,
                      json?["ok"] as? Bool == true,
                      let language = json?["language"] as? String,
                      ["auto", "zh", "en"].contains(language) else {
                    return
                }
                if Copy.preference != language {
                    Copy.preference = language
                    applyLanguage()
                }
            } catch {
                // Automatic system language remains available while the local service is offline.
            }
        }
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
        activeDeck
    }

    private func configureDeckButton(decks: [String], selected: String, enabled: Bool = true) {
        availableDecks = decks
        activeDeck = selected
        deckButton.removeAllItems()

        let displayItem = NSMenuItem(title: selected, action: nil, keyEquivalent: "")
        displayItem.state = .on
        deckButton.menu?.addItem(displayItem)
        deckButton.menu?.addItem(.separator())

        for deck in decks {
            let item = NSMenuItem(title: deck, action: #selector(deckChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = deck
            item.state = deck == selected ? .on : .off
            deckButton.menu?.addItem(item)
        }
        deckButton.isEnabled = enabled
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
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String
                            ?? Copy.text("无法读取牌组", "Could not load Anki decks")]
                    )
                }
                let selected = json?["selected"] as? String ?? decks[0]
                configureDeckButton(decks: decks, selected: selected)
            } catch {
                let fallback = availableDecks.isEmpty ? [activeDeck] : availableDecks
                configureDeckButton(decks: fallback, selected: activeDeck, enabled: false)
                showStatus(shortMessage(for: error), color: .systemRed, clearAfter: 10)
            }
        }
    }

    @objc private func deckChosen(_ sender: NSMenuItem) {
        guard let deck = sender.representedObject as? String else { return }
        configureDeckButton(decks: availableDecks, selected: deck)
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
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String
                            ?? Copy.text("牌组选择未保存", "Could not save the deck choice")]
                    )
                }
            } catch {
                showStatus(shortMessage(for: error), color: .systemRed, clearAfter: 10)
            }
        }
    }

    @objc private func languageChanged() {
        guard let language = languageButton.selectedItem?.representedObject as? String else { return }
        Copy.preference = language
        applyLanguage()
        focusWord()
        guard let request = serviceRequest(
            path: "/api/settings/language",
            method: "POST",
            payload: ["language": language]
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
                        userInfo: [NSLocalizedDescriptionKey: Copy.text("语言设置未保存", "Could not save the language")]
                    )
                }
            } catch {
                showStatus(shortMessage(for: error), color: .systemRed, clearAfter: 10)
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
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            submit(returnAfterSave: modifiers.contains(.command))
            return true
        }
        return false
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === wordField else { return }
        wordSurface.isFocused = true
        contextSurface.isFocused = false
        if let editor = wordField.currentEditor() as? NSTextView {
            applyTextBranding(to: editor)
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === wordField else { return }
        wordSurface.isFocused = false
    }

    @objc private func addClicked() {
        let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        submit(returnAfterSave: modifiers.contains(.command))
    }

    @objc private func pinClicked() {
        togglePin()
    }

    private func togglePin() {
        applyPin(window.level != .floating)
    }

    private func updatePinAppearance() {
        let pinned = window.level == .floating
        let symbol = pinned ? "pin.fill" : "pin"
        let description = Copy.text(
            pinned ? "已置顶" : "未置顶",
            pinned ? "Pinned" : "Not pinned"
        )
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        pinButton.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: description
        )?.withSymbolConfiguration(configuration)
        pinButton.contentTintColor = pinned ? Brand.primary : .secondaryLabelColor
        pinButton.setAccessibilityValue(description)
    }

    private func applyPin(_ pinned: Bool) {
        window.level = pinned ? .floating : .normal
        window.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
        pinButton.state = .off
        updatePinAppearance()
        defaults.set(pinned, forKey: "windowPinned")
    }

    private func submit(returnAfterSave: Bool) {
        guard !isSubmitting else { return }
        let word = wordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            showStatus(Copy.text("请先输入一个单词或短语", "Enter a word or phrase first"), color: .systemRed, clearAfter: 10)
            NSSound.beep()
            focusWord()
            return
        }

        isSubmitting = true
        setControlsEnabled(false)
        progress.isHidden = false
        progress.startAnimation(nil)
        showStatus(Copy.text("正在生成词卡…", "Creating your card…"))

        let payload: [String: Any] = [
            "text": word,
            "context": contextView.string.trimmingCharacters(in: .whitespacesAndNewlines),
            "deck": selectedDeck(),
            "language": Copy.languageCode,
            "source_title": Copy.text("Wordflow 快速添加", "Wordflow Quick Add"),
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
                        userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String
                            ?? Copy.text("加入失败", "Could not add the card")]
                    )
                }
                let duplicate = json?["duplicate"] as? Bool ?? false
                let card = json?["card"] as? [String: Any]
                let savedWord = card?["word"] as? String ?? word
                let savedDeck = json?["deck"] as? String ?? selectedDeck()
                finishSubmission(
                    message: duplicate
                        ? Copy.text("“\(savedWord)” 已存在于 \(savedDeck)", "“\(savedWord)” already exists in \(savedDeck)")
                        : Copy.text("已加入 \(savedDeck)：\(savedWord)", "Added to \(savedDeck): \(savedWord)"),
                    success: true
                )
                if !duplicate {
                    wordField.stringValue = ""
                    contextView.string = ""
                }
                if returnAfterSave {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                        self?.activatePreviousApplication()
                    }
                } else {
                    focusWord()
                }
            } catch {
                finishSubmission(message: shortMessage(for: error), success: false)
            }
        }
    }

    private func finishSubmission(message: String, success: Bool) {
        isSubmitting = false
        progress.stopAnimation(nil)
        progress.isHidden = true
        setControlsEnabled(true)
        showStatus(
            message,
            color: success ? .systemGreen : .systemRed,
            clearAfter: success ? 6 : 10
        )
    }

    private func setControlsEnabled(_ enabled: Bool) {
        wordField.isEnabled = enabled
        contextView.isEditable = enabled
        addButton.isEnabled = enabled
        languageButton.isEnabled = enabled
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
