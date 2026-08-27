import AppKit
import Carbon.HIToolbox
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
    private let defaultContentSize = NSSize(width: 468, height: 361)
    private var window: QuickAddWindow!
    private var wordField: NSTextField!
    private var contextView: ContextTextView!
    private var wordSurface: InputSurfaceView!
    private var contextSurface: InputSurfaceView!
    private var deckButton: NSPopUpButton!
    private var addButton: NSButton!
    private var pinButton: NSButton!
    private var settingsButton: NSButton!
    private var updateButton: NSButton!
    private var titlebarAccessory: NSTitlebarAccessoryViewController?
    private var statusLabel: NSTextField!
    private var progress: NSProgressIndicator!
    private var titleLabel: NSTextField!
    private var wordLabel: NSTextField!
    private var deckLabel: NSTextField!
    private var contextLabel: NSTextField!
    private var keyMonitor: Any?
    private var globalHotKeyRef: EventHotKeyRef?
    private var globalHotKeyHandler: EventHandlerRef?
    private var showSignalSource: DispatchSourceSignal?
    private var previousApplication: NSRunningApplication?
    private var availableDecks: [String] = []
    private var activeDeck = "Vocabulary Inbox"
    private var statusGeneration = 0
    private var isLoadingDecks = false
    private var isLoadingLanguage = false
    private var isSubmitting = false
    private var learningMode = "full"
    private var updateAvailable = false
    private let latestManifestURL = URL(
        string: "https://raw.githubusercontent.com/yiyuke/wordflow-anki/main/extension/manifest.json"
    )!
    private let updatePageURL = URL(string: "https://github.com/yiyuke/wordflow-anki#install")!
    private let feedbackEndpoint = URL(string: "https://formspree.io/f/xbgjrpbq")!
    private let projectURL = URL(string: "https://github.com/yiyuke/wordflow-anki")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        installKeyboardMonitor()
        installGlobalHotKey()
        installShowSignalHandler()
        checkForUpdates()
        if !CommandLine.arguments.contains("--background") {
            showWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let globalHotKeyRef {
            UnregisterEventHotKey(globalHotKeyRef)
        }
        if let globalHotKeyHandler {
            RemoveEventHandler(globalHotKeyHandler)
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
        installTitlebarControls()

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        titleLabel = label(Copy.text("快速添加到 Anki", "Quick Add to Anki"), size: 21, weight: .bold, color: .labelColor)

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

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [titleLabel, headerSpacer, pinButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

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
            "选择 Anki 牌组（⌘D），并记住上次选择",
            "Choose an Anki deck (⌘D); the last choice is remembered"
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
        contextView.toolTip = Copy.text("Tab 或 ↓ 移动到这里", "Move here with Tab or ↓")
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

        addButton = NSButton(title: Copy.text("加入 Anki", "Add to Anki"), target: self, action: #selector(addClicked))
        addButton.bezelStyle = .rounded
        addButton.bezelColor = Brand.primary
        addButton.controlSize = .large
        addButton.font = .systemFont(ofSize: 14, weight: .semibold)
        addButton.focusRingType = .none
        addButton.keyEquivalent = "\r"
        addButton.keyEquivalentModifierMask = [.command]
        addButton.setAccessibilityIdentifier("addButton")
        addButton.toolTip = Copy.text("⌘↩ 保存并切回之前的 App", "⌘↩ Save and return to the previous app")
        addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true

        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [footerSpacer, addButton])
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

    private func installTitlebarControls() {
        settingsButton = titlebarButton(
            symbol: "gearshape",
            identifier: "settingsButton",
            action: #selector(settingsButtonClicked)
        )
        updateButton = titlebarButton(
            symbol: "questionmark.circle",
            identifier: "updateButton",
            action: #selector(updateButtonClicked)
        )

        let controls = NSStackView(views: [settingsButton, updateButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 4
        controls.frame = NSRect(x: 0, y: 0, width: 60, height: 28)
        controls.autoresizingMask = [.width, .height]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 68, height: 28))
        container.addSubview(controls)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = container
        window.addTitlebarAccessoryViewController(accessory)
        titlebarAccessory = accessory
    }

    private func titlebarButton(symbol: String, identifier: String, action: Selector) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(),
            target: self,
            action: action
        )
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.focusRingType = .none
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.setAccessibilityIdentifier(identifier)
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
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

    private func installGlobalHotKey() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let readStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard readStatus == noErr, hotKeyID.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.showWindow()
                }
                return noErr
            },
            1,
            &eventSpec,
            userData,
            &globalHotKeyHandler
        )
        guard handlerStatus == noErr else {
            fputs("[wordflow] Could not install the global hotkey handler: \(handlerStatus)\n", stderr)
            return
        }

        let hotKeyID = EventHotKeyID(signature: 0x57464C4F, id: 1) // WFLO
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_W),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &globalHotKeyRef
        )
        if registerStatus != noErr {
            fputs("[wordflow] Could not register Option-Shift-W: \(registerStatus)\n", stderr)
        }
    }

    private func checkForUpdates(showResult: Bool = false) {
        var request = URLRequest(url: latestManifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        request.setValue("Wordflow/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latestVersion = manifest["version"] as? String else {
                    throw URLError(.badServerResponse)
                }
                updateAvailable = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
                updateUpdateButtonAppearance()
                if showResult {
                    showStatus(
                        updateAvailable
                            ? Copy.text("发现新版本 \(latestVersion)", "Version \(latestVersion) is available")
                            : Copy.text("已经是最新版", "Wordflow is up to date"),
                        color: updateAvailable ? Brand.primary : .secondaryLabelColor,
                        clearAfter: 6
                    )
                }
            } catch {
                if showResult {
                    showStatus(
                        Copy.text("暂时无法检查更新", "Could not check for updates"),
                        color: .secondaryLabelColor,
                        clearAfter: 6
                    )
                }
            }
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func updateUpdateButtonAppearance() {
        let symbol = updateAvailable ? "arrow.down.circle.fill" : "questionmark.circle"
        updateButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
        updateButton.contentTintColor = updateAvailable ? Brand.primary : .secondaryLabelColor
        updateButton.toolTip = updateAvailable
            ? Copy.text("有新版本，点击查看更新", "An update is available")
            : Copy.text("帮助、反馈与检查更新", "Help, feedback, and updates")
        updateButton.setAccessibilityLabel(updateButton.toolTip ?? "")
    }

    @objc private func updateButtonClicked() {
        if updateAvailable {
            NSWorkspace.shared.open(updatePageURL)
            return
        }
        let menu = NSMenu()
        let checkItem = NSMenuItem(
            title: Copy.text("检查更新", "Check for Updates"),
            action: #selector(checkForUpdatesClicked),
            keyEquivalent: ""
        )
        checkItem.target = self
        menu.addItem(checkItem)

        let feedbackItem = NSMenuItem(
            title: Copy.text("帮助与反馈", "Help & Feedback"),
            action: #selector(openFeedback),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        let projectItem = NSMenuItem(
            title: Copy.text("项目主页", "Project Home"),
            action: #selector(openProjectHome),
            keyEquivalent: ""
        )
        projectItem.target = self
        menu.addItem(projectItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: updateButton.bounds.minY - 4), in: updateButton)
    }

    @objc private func checkForUpdatesClicked() {
        checkForUpdates(showResult: true)
    }

    @objc private func openFeedback() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = Copy.text("帮助与反馈", "Help & Feedback")
        let sendButton = alert.addButton(withTitle: Copy.text("提交反馈", "Submit Feedback"))
        sendButton.bezelColor = Brand.primary
        alert.addButton(withTitle: Copy.text("取消", "Cancel"))

        let category = NSPopUpButton(frame: .zero, pullsDown: false)
        category.addItems(withTitles: [
            Copy.text("功能建议", "Feature idea"),
            Copy.text("遇到问题", "Problem or bug"),
            Copy.text("安装帮助", "Installation help"),
            Copy.text("其他", "Other"),
        ])
        category.setAccessibilityLabel(Copy.text("反馈类型", "Feedback type"))

        let messageView = NSTextView()
        messageView.font = .systemFont(ofSize: 13)
        messageView.isRichText = false
        messageView.isAutomaticQuoteSubstitutionEnabled = false
        messageView.isAutomaticDashSubstitutionEnabled = false
        messageView.textContainerInset = NSSize(width: 8, height: 7)
        messageView.setAccessibilityLabel(Copy.text("反馈内容", "Feedback message"))
        let messageScroll = NSScrollView()
        messageScroll.borderType = .bezelBorder
        messageScroll.hasVerticalScroller = true
        messageScroll.autohidesScrollers = true
        messageScroll.documentView = messageView
        messageScroll.heightAnchor.constraint(equalToConstant: 112).isActive = true

        let form = NSStackView(views: [
            feedbackLabel(Copy.text("反馈类型", "Feedback type")),
            category,
            feedbackLabel(Copy.text("请告诉我发生了什么，或你希望改进什么", "What happened, or what would you improve?")),
            messageScroll,
        ])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 6
        form.translatesAutoresizingMaskIntoConstraints = false

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 184))
        accessory.addSubview(form)
        NSLayoutConstraint.activate([
            form.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            form.topAnchor.constraint(equalTo: accessory.topAnchor),
            form.bottomAnchor.constraint(lessThanOrEqualTo: accessory.bottomAnchor),
            category.widthAnchor.constraint(equalTo: form.widthAnchor),
            messageScroll.widthAnchor.constraint(equalTo: form.widthAnchor),
        ])
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = messageView

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let message = messageView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            showStatus(Copy.text("请先填写反馈内容", "Write a feedback message first"), color: .systemRed, clearAfter: 8)
            return
        }

        let categoryName = category.titleOfSelectedItem ?? Copy.text("其他", "Other")
        submitFeedback(category: categoryName, message: message)
    }

    private func submitFeedback(category: String, message: String) {
        showStatus(Copy.text("正在发送反馈…", "Sending feedback…"))

        Task {
            do {
                var request = URLRequest(url: feedbackEndpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = 15
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "type": category,
                    "message": message,
                ])

                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                showStatus(
                    Copy.text("反馈已发送，谢谢", "Feedback sent — thank you"),
                    color: .systemGreen,
                    clearAfter: 10
                )
            } catch {
                showStatus(
                    Copy.text("发送失败，请稍后重试", "Could not send. Try again later"),
                    color: .systemRed,
                    clearAfter: 10
                )
            }
        }
    }

    private func feedbackLabel(_ text: String, muted: Bool = false) -> NSTextField {
        let field = label(
            text,
            size: muted ? 11 : 12,
            weight: muted ? .regular : .semibold,
            color: muted ? .secondaryLabelColor : .labelColor
        )
        field.maximumNumberOfLines = 3
        field.lineBreakMode = .byWordWrapping
        return field
    }

    @objc private func openProjectHome() {
        NSWorkspace.shared.open(projectURL)
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

    @objc private func settingsButtonClicked() {
        let menu = NSMenu()

        let modeItem = NSMenuItem(title: Copy.text("学习模式", "Learning Mode"), action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        modeMenu.addItem(settingsChoice(
            title: Copy.text("完整学习", "Full Learning"),
            value: "full",
            selected: learningMode,
            action: #selector(learningModeChanged(_:))
        ))
        modeMenu.addItem(settingsChoice(
            title: Copy.text("考研阅读", "Exam Reading"),
            value: "exam",
            selected: learningMode,
            action: #selector(learningModeChanged(_:))
        ))
        menu.setSubmenu(modeMenu, for: modeItem)
        menu.addItem(modeItem)

        let languageItem = NSMenuItem(title: Copy.text("语言", "Language"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for (value, title) in [
            ("auto", Copy.text("自动", "Auto")),
            ("zh", "中文"),
            ("en", "English"),
        ] {
            languageMenu.addItem(settingsChoice(
                title: title,
                value: value,
                selected: Copy.preference,
                action: #selector(languageChanged(_:))
            ))
        }
        menu.setSubmenu(languageMenu, for: languageItem)
        menu.addItem(languageItem)
        menu.addItem(.separator())

        let shortcutsItem = NSMenuItem(title: Copy.text("键盘快捷键", "Keyboard Shortcuts"), action: nil, keyEquivalent: "")
        let shortcutsMenu = NSMenu()
        shortcutsMenu.autoenablesItems = false
        for title in [
            Copy.text("打开窗口　⌥⇧W", "Open window　⌥⇧W"),
            Copy.text("移动焦点　Tab / ↓", "Move focus　Tab / ↓"),
            Copy.text("选择牌组　⌘D", "Choose deck　⌘D"),
            Copy.text("置顶窗口　⌘P", "Pin window　⌘P"),
            Copy.text("保存并切回　⌘↩", "Save and return　⌘↩"),
            Copy.text("关闭窗口　Esc", "Close window　Esc"),
        ] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = true
            shortcutsMenu.addItem(item)
        }
        menu.setSubmenu(shortcutsMenu, for: shortcutsItem)
        menu.addItem(shortcutsItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: settingsButton.bounds.minY - 4), in: settingsButton)
    }

    private func settingsChoice(
        title: String,
        value: String,
        selected: String,
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = value
        item.state = value == selected ? .on : .off
        return item
    }

    private func applyLanguage() {
        window.title = Copy.text("Wordflow 快速添加", "Wordflow Quick Add")
        titleLabel.stringValue = Copy.text("快速添加到 Anki", "Quick Add to Anki")
        wordLabel.stringValue = Copy.text("单词或短语", "Word or phrase")
        deckLabel.stringValue = Copy.text("牌组", "Deck")
        contextLabel.stringValue = Copy.text("例句或上下文（可选）", "Example or context (optional)")
        wordField.placeholderString = Copy.text("例如：serendipity", "e.g. serendipity")
        contextView.setAccessibilityLabel(Copy.text("例句或上下文，可选", "Example or context, optional"))
        deckButton.setAccessibilityLabel(Copy.text("保存到 Anki 牌组", "Save to Anki deck"))
        deckButton.toolTip = Copy.text(
            "选择 Anki 牌组（⌘D），并记住上次选择",
            "Choose an Anki deck (⌘D); the last choice is remembered"
        )
        contextView.toolTip = Copy.text("Tab 或 ↓ 移动到这里", "Move here with Tab or ↓")
        settingsButton.toolTip = Copy.text("设置：学习模式、语言与快捷键", "Settings: learning mode, language, and shortcuts")
        settingsButton.setAccessibilityLabel(Copy.text("设置", "Settings"))
        pinButton.toolTip = Copy.text("始终显示在其他窗口上方（⌘P）", "Keep above other windows (⌘P)")
        pinButton.setAccessibilityLabel(Copy.text("置顶", "Pin"))
        addButton.title = Copy.text("加入 Anki", "Add to Anki")
        addButton.toolTip = Copy.text("⌘↩ 保存并切回之前的 App", "⌘↩ Save and return to the previous app")
        updateUpdateButtonAppearance()
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
                if let savedMode = json?["learning_mode"] as? String,
                   ["full", "exam"].contains(savedMode),
                   learningMode != savedMode {
                    learningMode = savedMode
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

    @objc private func languageChanged(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? String,
              ["auto", "zh", "en"].contains(language) else { return }
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

    @objc private func learningModeChanged(_ sender: NSMenuItem) {
        guard let selected = sender.representedObject as? String,
              ["full", "exam"].contains(selected) else { return }
        learningMode = selected
        focusWord()
        guard let request = serviceRequest(
            path: "/api/settings/learning-mode",
            method: "POST",
            payload: ["learning_mode": learningMode]
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
                        userInfo: [NSLocalizedDescriptionKey: Copy.text(
                            "学习模式未保存",
                            "Could not save the learning mode"
                        )]
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
            "learning_mode": learningMode,
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
        settingsButton.isEnabled = enabled
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
