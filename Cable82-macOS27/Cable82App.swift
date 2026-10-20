import SwiftUI
import Combine
import AppKit
import Darwin

@main
struct Cable82App: App {
    @StateObject private var server = Cable82Server()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(server)
                .frame(minWidth: 560, minHeight: 620)
                .onAppear { server.start() }
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class Cable82Server: ObservableObject {
    @Published var status = "STARTING SERVER…"
    @Published var url = "http://127.0.0.1:1982"
    @Published var detail = ""
    @Published var channelsFolder: URL
    private var process: Process?
    let dataFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Cable82", isDirectory: true)
    private let channelsKey = "Cable82ChannelsFolder"

    init() {
        let defaultURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Cable82/channels", isDirectory: true)
        if let saved = UserDefaults.standard.string(forKey: channelsKey), !saved.isEmpty {
            channelsFolder = URL(fileURLWithPath: saved, isDirectory: true)
        } else { channelsFolder = defaultURL }
    }

    var musicFolder: URL { dataFolder.appendingPathComponent("music", isDirectory: true) }
    var defaultChannelsFolder: URL { dataFolder.appendingPathComponent("channels", isDirectory: true) }

    func start() {
        guard process == nil else { return }
        try? FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: musicFolder, withIntermediateDirectories: true)
        guard channelsLocationAvailable() else {
            status = "CHANNELS DRIVE NOT FOUND"
            detail = "Reconnect the drive or choose another channels folder."
            return
        }
        let candidates = [Bundle.main.resourceURL?.appendingPathComponent("runtime/node").path, "/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"].compactMap { $0 }
        guard let node = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            status = "NODE.JS NEEDED"; detail = "Install the Apple-silicon Node.js package, then reopen Cable82."; return
        }
        guard let main = Bundle.main.url(forResource: "Main", withExtension: "js") else {
            status = "SERVER FILE MISSING"; detail = "Main.js was not copied into the app bundle."; return
        }
        let p = Process(); p.executableURL = URL(fileURLWithPath: node); p.arguments = [main.path]; p.currentDirectoryURL = main.deletingLastPathComponent()
        var env = ProcessInfo.processInfo.environment
        env["CABLE82_DATA"] = dataFolder.path
        env["CABLE82_CHANNELS"] = channelsFolder.path
        env["CABLE82_PORT"] = "1982"
        p.environment = env
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let text = String(data: h.availableData, encoding: .utf8) ?? ""
            guard !text.isEmpty else { return }
            DispatchQueue.main.async { self?.detail = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        p.terminationHandler = { [weak self] proc in DispatchQueue.main.async {
            guard let self else { return }
            self.process = nil
            if proc.terminationReason == .uncaughtSignal && proc.terminationStatus == SIGTERM { return }
            if self.detail.localizedCaseInsensitiveContains("EADDRINUSE") || self.detail.localizedCaseInsensitiveContains("address already in use") {
                self.status = "PORT 1982 ALREADY IN USE"
                self.detail = "Quit the other Cable82 server, then press Restart Server."
            } else {
                self.status = "SERVER STOPPED"
                if self.detail.isEmpty { self.detail = "Node exited with code \(proc.terminationStatus)" }
            }
        }}
        do { try p.run(); process = p; status = "SERVER RUNNING"; url = "http://\(Self.lanIPv4() ?? "127.0.0.1"):1982" }
        catch { status = "SERVER FAILED"; detail = error.localizedDescription }
    }

    private func channelsLocationAvailable() -> Bool {
        if channelsFolder.path == defaultChannelsFolder.path {
            do { try FileManager.default.createDirectory(at: channelsFolder, withIntermediateDirectories: true); return true } catch { return false }
        }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: channelsFolder.path, isDirectory: &isDir) && isDir.boolValue
    }

    func chooseChannelsFolder() {
        let panel = NSOpenPanel(); panel.title = "Choose Cable82 Channels Folder"; panel.message = "Choose the folder containing your channel folders."; panel.prompt = "Choose"; panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false; panel.canCreateDirectories = true
        if channelsLocationAvailable() { panel.directoryURL = channelsFolder }
        if panel.runModal() == .OK, let selected = panel.url {
            channelsFolder = selected; UserDefaults.standard.set(selected.path, forKey: channelsKey); restart()
        }
    }
    func useDefaultChannelsFolder() { channelsFolder = defaultChannelsFolder; UserDefaults.standard.removeObject(forKey: channelsKey); try? FileManager.default.createDirectory(at: channelsFolder, withIntermediateDirectories: true); restart() }
    func restart() { process?.terminate(); process = nil; DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.start() } }
    func openSite() { if let u = URL(string: url) { NSWorkspace.shared.open(u) } }
    func openUpload() { if let u = URL(string: url + "/upload.html") { NSWorkspace.shared.open(u) } }
    func openConfig() { if let u = URL(string: url + "/config") { NSWorkspace.shared.open(u) } }
    func openChannelsFolder() { if channelsLocationAvailable() { NSWorkspace.shared.open(channelsFolder) } else { status = "CHANNELS DRIVE NOT FOUND"; detail = "Reconnect the drive or choose another channels folder." } }
    func copyURL() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url, forType: .string) }

    static func lanIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?; guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }; defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = ptr.pointee; guard i.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: i.ifa_name); guard name == "en0" || name == "en1" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(i.ifa_addr, socklen_t(i.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 { let s = String(cString: host); if !s.hasPrefix("127.") { return s } }
        }; return nil
    }
}

struct ContentView: View {
    @EnvironmentObject var server: Cable82Server
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
            if let image = NSImage(named: "Cable82StatusIcon") { Image(nsImage: image).resizable().scaledToFit().frame(width: 170, height: 170) }
            Text("CABLE 82").font(.system(size: 36, weight: .black)).foregroundStyle(.white)
            Text(server.status).font(.title3.bold()).foregroundStyle(server.status == "SERVER RUNNING" ? .green : .orange)
            Text(server.url).font(.system(.title3, design: .monospaced)).foregroundStyle(.white).textSelection(.enabled)
            HStack { Button("Open Cable82") { server.openSite() }; Button("Configure Channels") { server.openConfig() }; Button("Bulk Upload") { server.openUpload() }; Button("Copy URL") { server.copyURL() } }
            HStack { Button("Open Channels Folder") { server.openChannelsFolder() }; Button("Change Channels Folder…") { server.chooseChannelsFolder() }; Button("Restart Server") { server.restart() } }
            Button("Use Default Channels Folder") { server.useDefaultChannelsFolder() }.disabled(server.channelsFolder.path == server.defaultChannelsFolder.path)
            VStack(spacing: 4) {
                Text("Channels: \(server.channelsFolder.path)").textSelection(.enabled)
                Text("Music: ~/Movies/Cable82/music")
            }.font(.system(.body, design: .monospaced)).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
            if !server.detail.isEmpty { Text(server.detail).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(3).multilineTextAlignment(.center).padding(.horizontal) }
            }.padding(28)
        }
        .preferredColorScheme(.dark)
    }
}
