import AppKit
import SwiftUI
import SalaryDomain
import SalaryShared
import SalaryCore
import SalaryPresentation

/// Offscreen rendering of the UI, used to eyeball every state without needing
/// screen-recording or accessibility permissions.
///
///     SalaryTicker.app/Contents/MacOS/SalaryTicker --render-shots <dir>
///
/// Renders into `<dir>` and exits before any window or status item is created.
///
/// Uses `NSHostingView.cacheDisplay` rather than SwiftUI's `ImageRenderer`: the settings
/// form is built from AppKit-backed controls (`Form`, `DatePicker`, `Toggle`) which
/// `ImageRenderer` draws as blank. Caching our own view hierarchy renders the real thing.
@MainActor
enum PreviewShot {

    static func runIfRequested() {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--render-icons"), flag + 1 < args.count {
            renderIcons(into: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }
        if let flag = args.firstIndex(of: "--render-appicon"), flag + 1 < args.count {
            renderIconSet(into: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }
        guard let flag = args.firstIndex(of: "--render-shots"), flag + 1 < args.count else { return }

        let directory = URL(fileURLWithPath: args[flag + 1])
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for scene in scenes() {
            let path = directory.appendingPathComponent("\(scene.name).png")
            if let data = capture(scene.view, dark: scene.dark) {
                try? data.write(to: path)
                print("rendered \(scene.name).png")
            } else {
                print("FAILED \(scene.name).png")
            }
        }
        exit(0)
    }

    // MARK: Scenes

    private struct Scene {
        let name: String
        let view: AnyView
        var dark: Bool = false
    }

    private static func scenes() -> [Scene] {
        let today = Calendar.current.component(.weekday, from: Date())

        var dayOff = SalaryConfig.default
        dayOff.workdays.remove(today)

        var afterWork = SalaryConfig.default
        afterWork.workStart = TimeOfDay(0, 1)
        afterWork.workEnd = TimeOfDay(0, 2)

        var broken = SalaryConfig.default
        broken.monthlySalary = 0

        // A month with a half-day Saturday and both kinds of leave marked.
        var mixedMonth = SalaryConfig.default
        mixedMonth.workdays.insert(7)
        mixedMonth.halfDays.insert(7)
        let dayOfMonth = Calendar.current.component(.day, from: Date())
        let ym = Calendar.current.dateComponents([.year, .month], from: Date())
        if let year = ym.year, let month = ym.month {
            mixedMonth.dayOverrides = [
                DayKey(year: year, month: month, day: max(1, dayOfMonth - 2)): .paidLeave,
                DayKey(year: year, month: month, day: min(28, dayOfMonth + 3)): .unpaidLeave,
            ]
        }

        // A realistic day that already ended an hour ago, so overtime is visibly running
        // without the degenerate rates a one-minute day would produce.
        var overtime = SalaryConfig.default
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let endHour = max(1, (now.hour ?? 12) - 1)
        overtime.workStart = TimeOfDay(max(0, endHour - 8), now.minute ?? 0)
        overtime.workEnd = TimeOfDay(endHour, now.minute ?? 0)
        overtime.lunchEnabled = false
        overtime.overtimeEnabled = true
        overtime.overtimeMultiplier = 1.5

        var withGoals = SalaryConfig.default
        withGoals.goals = [
            SavingsGoal(name: "AirPods Pro", amount: 1_100,
                        startedAt: Date().addingTimeInterval(-3 * 86_400)),
            SavingsGoal(name: "Kyoto trip", amount: 9_000,
                        startedAt: Date().addingTimeInterval(-10 * 86_400)),
        ]

        var lunch = SalaryConfig.default
        lunch.lunchStart = TimeOfDay(0, 0)
        lunch.lunchEnd = TimeOfDay(23, 30)   // forces the "lunch" branch at any hour

        var scenes: [Scene] = [
            Scene(name: "panel-working", view: panel(config: .default)),
            Scene(name: "panel-working-dark", view: panel(config: .default), dark: true),
            Scene(name: "panel-lunch", view: panel(config: lunch)),
            Scene(name: "panel-dayoff", view: panel(config: dayOff)),
            Scene(name: "panel-afterwork", view: panel(config: afterWork)),
            Scene(name: "panel-misconfigured", view: panel(config: broken)),
            Scene(name: "panel-overtime", view: panel(config: overtime)),
            Scene(name: "panel-goals", view: panel(config: withGoals)),
            Scene(name: "settings-goals", view: settings(config: withGoals, tab: .goals)),
            Scene(name: "settings-salary", view: settings(tab: .salary)),
            Scene(name: "settings-salary-mixed", view: settings(config: mixedMonth, tab: .salary)),
            Scene(name: "settings-salary-next", view: settings(config: mixedMonth, tab: .salary, monthOffset: 1)),
            Scene(name: "settings-schedule", view: settings(tab: .schedule)),
            Scene(name: "settings-general", view: settings(tab: .general)),
            Scene(name: "settings-dark", view: settings(tab: .schedule), dark: true),
        ]

        // One panel and one settings page per language, so a translation that overflows
        // its row is visible before it ships.
        for language in AppLanguage.allCases {
            var localized = SalaryConfig.default
            localized.language = language
            scenes.append(Scene(name: "panel-\(language.rawValue)", view: panel(config: localized)))
            scenes.append(Scene(name: "settings-\(language.rawValue)", view: settings(config: localized)))
        }
        return scenes
    }

    private static func panel(config: SalaryConfig) -> AnyView {
        AnyView(MenuPanelView(viewModel: makeViewModel(config: config)))
    }

    private static func settings(
        config: SalaryConfig = .default,
        tab: SettingsView.Tab = .salary,
        monthOffset: Int = 0
    ) -> AnyView {
        let viewModel = makeViewModel(config: config)
        if monthOffset != 0 { viewModel.stepMonth(by: monthOffset) }
        return AnyView(SettingsView(viewModel: viewModel, pinnedTab: tab))
    }

    /// A throwaway defaults suite so rendering never touches the user's real settings.
    private static func makeViewModel(config: SalaryConfig) -> TickerViewModel {
        let viewModel = TickerViewModel(
            container: .preview(suiteName: "com.steve.salaryticker.preview")
        )
        viewModel.config = config
        viewModel.refresh()
        return viewModel
    }

    // MARK: Icons

    /// Each candidate at full size and at the size that actually decides it.
    private static func renderIcons(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for candidate in IconCandidate.allCases {
            for side in [1024, 128, 32] {
                let name = "icon-\(candidate.rawValue)-\(side).png"
                guard let data = renderIcon(candidate.view, side: side) else {
                    print("FAILED \(name)")
                    continue
                }
                try? data.write(to: directory.appendingPathComponent(name))
                print("rendered \(name)")
            }
        }
    }

    /// `ImageRenderer` rather than `cacheDisplay` here: the icon is pure SwiftUI drawing,
    /// which `ImageRenderer` handles well, and — decisively — it keeps the alpha channel.
    /// A cached display gives back an opaque bitmap, which would put a black square behind
    /// the squircle's rounded corners.
    private static func renderIcon(_ view: some View, side: Int) -> Data? {
        let renderer = ImageRenderer(
            content: view.frame(width: CGFloat(side), height: CGFloat(side))
        )
        renderer.scale = 1
        renderer.isOpaque = false

        guard let cgImage = renderer.cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: side, height: side)
        return rep.representation(using: .png, properties: [:])
    }

    /// Writes a complete `.iconset` folder for `iconutil`.
    private static func renderIconSet(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The names are what iconutil expects; the @2x entries are simply the next size up.
        let entries: [(name: String, side: Int)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024),
        ]
        for entry in entries {
            guard let data = renderIcon(IconCandidate.milledDollar.view, side: entry.side) else {
                print("FAILED \(entry.name)")
                continue
            }
            try? data.write(to: directory.appendingPathComponent("\(entry.name).png"))
        }
        print("wrote \(entries.count) images into \(directory.lastPathComponent)")
    }

    // MARK: Rendering

    private static func capture(_ view: AnyView, dark: Bool) -> Data? {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        // The real panel sits on the menu bar window's material; offscreen there is
        // nothing behind it, so dark-mode text would be white on transparent.
        let hosting = NSHostingView(
            rootView: AnyView(view.background(Color(nsColor: .windowBackgroundColor)))
        )
        hosting.appearance = appearance

        let size = hosting.fittingSize
        guard size.width > 1, size.height > 1 else { return nil }
        hosting.frame = NSRect(origin: .zero, size: size)

        // A hosting view only resolves materials and control appearance once it belongs
        // to a window, so give it an offscreen one.
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        // Let SwiftUI settle its first layout pass before we snapshot.
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        hosting.layoutSubtreeIfNeeded()
        hosting.display()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
