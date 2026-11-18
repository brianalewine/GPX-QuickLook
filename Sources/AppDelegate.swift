import Cocoa
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Open GPX…", action: #selector(openFile), keyEquivalent: "o")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit GPX QuickLook", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        if windows.isEmpty { showWelcome() }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for file in filenames { open(URL(fileURLWithPath: file)) }
        sender.reply(toOpenOrPrint: .success)
    }
    @objc private func openFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.init(filenameExtension: "gpx") ?? .xml]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach(open) }
    }
    private func open(_ url: URL) {
        let controller = TrackViewController()
        do { try controller.show(url) } catch { controller.showError(error) }
        makeWindow(controller, title: url.lastPathComponent)
    }
    private func makeWindow(_ controller: NSViewController, title: String) {
        let window = NSWindow(contentViewController: controller)
        window.title = title; window.setContentSize(NSSize(width: 960, height: 680)); window.center()
        window.makeKeyAndOrderFront(nil); windows.append(window)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func showWelcome() {
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 680))
        let label = NSTextField(wrappingLabelWithString: "GPX QuickLook\n\nSelect a GPX file in Finder and press Space.\nOr open a file here to explore its track.\n\nDrag to pan · Scroll or use + / − to zoom\nMap tiles require an internet connection.")
        label.font = .systemFont(ofSize: 21); label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let button = NSButton(title: "Open GPX…", target: self, action: #selector(openFile)); button.bezelStyle = .rounded; button.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label); controller.view.addSubview(button)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor), label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor, constant: -35), button.centerXAnchor.constraint(equalTo: label.centerXAnchor), button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 25)])
        makeWindow(controller, title: "GPX QuickLook")
    }
}
