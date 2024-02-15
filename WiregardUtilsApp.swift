import SwiftUI
import Cocoa

@main
struct WireguardUtilsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            //
            ContentView(viewModel: appDelegate.contentViewViewModel, toggleVPNAction: appDelegate.toggleVPN)
                            .frame(width: 800, height: 600)
                            .background(WindowAccessor())
        }
        .commandsReplaced {
                }
    }
    
}

class CustomWindowController: NSWindowController, NSWindowDelegate {
    
    init(window: NSWindow, contentView: AnyView, width: CGFloat = 600, height: CGFloat = 400) {
            super.init(window: window)
            window.setContentSize(NSSize(width: width, height: height))
            window.delegate = self
            window.contentView = NSHostingView(rootView: contentView)
        }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return false
    }
}


struct WindowAccessor: NSViewRepresentable {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    func makeNSView(context: Context) -> some NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                let windowController = CustomWindowController(window: window, contentView: AnyView(ContentView(viewModel: appDelegate.contentViewViewModel, toggleVPNAction: appDelegate.toggleVPN)), width: 800, height: 600)
                window.windowController = windowController
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {}
}

extension String {
    func deletingSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
}

func listFilenamesWithoutSuffixes (directoryPath: String) -> Array<String> {
    let fileManager = FileManager.default
    var files: [String] = []
    do {
        let fileURLs = try fileManager.contentsOfDirectory(atPath: directoryPath)

        for fileURL in fileURLs {
            if fileURL.hasSuffix(".conf") {
                let fileNameWithoutSuffix = fileURL.deletingSuffix(".conf")
                files.append(fileNameWithoutSuffix)
            }
        }
        return files
    } catch {
        let files: [String] = []
        print("Error reading directory: \(error)")
        return files
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var statusMenuItem: NSMenuItem?
    var startVPNItem: NSMenuItem?
    var statusUpdateTimer: Timer?
    var contentViewViewModel = ViewModel()
    var selectedTunnelItem: NSMenuItem?
    
    
    
    let files: [String] = listFilenamesWithoutSuffixes(directoryPath: "/usr/local/etc/wireguard/")
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Setup the menu bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Wireguard")
        }

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarItem.menu = statusBarMenu
        
        statusMenuItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        statusBarMenu.addItem(statusMenuItem!)
        
        startVPNItem = NSMenuItem(title: "Init", action: #selector(toggleVPN), keyEquivalent: "")
        statusBarMenu.addItem(startVPNItem!)
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        func setupMenuItems(with files: [String]) {
                for file in files {
                    let menuItem = NSMenuItem(
                        title: file,
                        action: #selector(selectTunnel(_:)),
                        keyEquivalent: ""
                    )
                    menuItem.representedObject = file
                    statusBarMenu.addItem(menuItem)
                }
            }
        
        setupMenuItems(with: files)
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusBarMenu.addItem(
            withTitle: "Show Window",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        )
        
        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        
        

        // Initialize VPN status check
        checkVPNStatus()
        statusUpdateTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkVPNStatus), userInfo: nil, repeats: true)
    }
    
    
    
    @objc func selectTunnel(_ sender: NSMenuItem) {
            if let file = sender.representedObject as? String {
                if(self.contentViewViewModel.UIText == "Waiting for connection"){
                    self.contentViewViewModel.selectTunnel = file
                    self.startVPN()
                    sender.state = .on
                    if(selectedTunnelItem != sender){
                        selectedTunnelItem?.state = .off
                    }
                }else if(self.contentViewViewModel.selectTunnel != file){
                    self.contentViewViewModel.selectTunnel = file
                    self.stopVPN()
                    self.startVPN()
                    sender.state = .on
                    selectedTunnelItem?.state = .off
                }else{
                    self.stopVPN()
                    sender.state = .off
                    selectedTunnelItem?.state = .off
                }
                print("Selected file: \(file)")
                
                // Remove checkmark from previously selected tunnel
                

                // Set checkmark on the newly selected tunnel
                //sender.state = .on

                // Keep a reference to the newly selected tunnel
                selectedTunnelItem = sender
            }
        }
    
    /*var currTunnel = ""
    @objc func selectTunnel(with fileName: String){
        currTunnel = fileName
    }*/
    @objc func showMainWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            
            var windowsCount = 0
            for windows in NSApp.windows {
                if windows.isMiniaturized {
                    windows.deminiaturize(self)
                }
                
                if !windows.isVisible {
                    windows.makeKeyAndOrderFront(nil)
                }
                
                windowsCount+=1
            }
            print(windowsCount)
            if(windowsCount <= 2){
                print("window closed")
                
            }
        }
    }
    
    
    
    
    



    @objc func startVPN() {
        if(self.contentViewViewModel.selectTunnel == "Please Select Tunnel"){
            return
        }
        self.startVPNItem?.title = "Connecting..."
        self.startVPNItem?.action = nil
        self.contentViewViewModel.UIText = "Connecting..."
        self.updateStatus(with: "Connecting...")
        runCommand("sudo wg-quick up "+self.contentViewViewModel.selectTunnel+";exit;")
    }

    @objc func stopVPN() {
        self.startVPNItem?.title = "Disconnecting..."
        self.startVPNItem?.action = nil
        self.contentViewViewModel.UIText = "Disconnecting..."
        self.updateStatus(with: "Disconnecting...")
        for tunnel in files{
            print(tunnel)
            runCommand("sudo wg-quick down "+tunnel+";networksetup -setdnsservers Wi-Fi empty;exit;")
            sleep(1)
        }
        
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    func runCommand(_ command: String) {
            let script = """
            tell application "Terminal"
                do script "\(command)"
            end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    DispatchQueue.main.async {
                        print("AppleScript Error: \(error)")
                    }
                }
            }
    }
    
    @objc func toggleVPN() {
        if self.startVPNItem?.title == "Connecting..." || self.startVPNItem?.title == "Disconnecting..."{
            return
        }
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            let pipe = Pipe()

            process.launchPath = "/bin/zsh"
            process.arguments = ["-c", "sudo /usr/local/bin/wg show"]
            process.standardOutput = pipe
            process.launch()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

             
            
            DispatchQueue.main.async {
                if output.contains("interface"){
                    self.selectedTunnelItem?.state = .off
                    self.stopVPN()
                }else{
                    self.startVPN()
                }
            }
        }
    }
    
    @objc func checkVPNStatus() {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            let pipe = Pipe()

            process.launchPath = "/bin/zsh"
            process.arguments = ["-c", "sudo /usr/local/bin/wg show"]
            process.standardOutput = pipe
            process.launch()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

             
            
            DispatchQueue.main.async {
                if output.contains("interface"){
                    if self.startVPNItem?.title == "Connecting..." || self.startVPNItem?.title == "Init" || self.startVPNItem?.title == "Disconnect VPN"{
                        self.updateStatus(with: "VPN Running")
                        self.startVPNItem?.title = "Disconnect VPN"
                        self.startVPNItem?.action = #selector(self.toggleVPN)
                        self.contentViewViewModel.UIText = output
                    }
                }else{
                    if self.startVPNItem?.title == "Disconnecting..." || self.startVPNItem?.title == "Init"{
                        self.updateStatus(with: "VPN Stopped")
                        self.startVPNItem?.title = "Select a tunnel below to start connection"
                        self.startVPNItem?.action = nil
                        self.contentViewViewModel.UIText = "Waiting for connection"
                    }
                }
            }
        }
    }
    
    func updateStatus(with status: String) {
        DispatchQueue.main.async {
            if let button = self.statusBarItem.button {
                let symbolName: String
                let accessibilityDescription: String
                
                if status.contains("VPN Running") {
                    symbolName = "network.badge.shield.half.filled"
                    accessibilityDescription = "VPN Connected"
                }else if status.contains("Connecting"){
                    symbolName = "ellipsis"
                    accessibilityDescription = "Connecting"
                }else if status.contains("Disconnecting"){
                    symbolName = "ellipsis"
                    accessibilityDescription = "Connecting"
                }else {
                    symbolName = "network"
                    accessibilityDescription = "VPN Disconnected"
                }

                // Create a configuration for the symbol
                let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .light) // Adjust size and weight
                if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?.withSymbolConfiguration(configuration) {
                    button.image = image
                }

                self.updateStatusMenuItem(with: status)
            }
        }
    }


    func updateStatusMenuItem(with status: String) {
        DispatchQueue.main.async {
            self.statusMenuItem?.title = "Status: \(status)"
        }
    }
}

class ViewModel: ObservableObject {
    @Published var UIText: String = "Please Select A Tunnel"
    @Published var selectTunnel: String = "Please Select Tunnel"
}

struct ContentView: View {
    @ObservedObject var viewModel: ViewModel
    
    let toggleVPNAction: () -> Void
    
    func openWGConfig(){
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "/usr/local/etc/wireguard/")
    }
    
    func noAction(){
        
    }

    var body: some View {
        VStack {
            if(viewModel.selectTunnel != "Please Select Tunnel"){
                //Text("Selected Tunnel: " + viewModel.selectTunnel).padding()
            }
                
            
            Text(viewModel.UIText).padding() // Adds padding around the text
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            
            
            if viewModel.UIText.contains("interface"){
                Button(action: toggleVPNAction) {
                    Text("Disconnect VPN")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }else if viewModel.UIText.contains("Connecting"){
                Button(action: toggleVPNAction) {
                    Text("Connecting...")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }else if viewModel.UIText.contains("Disconnecting"){
                Button(action: toggleVPNAction) {
                    Text("Disconnecting...")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }else{
                Button(action: noAction) {
                    Text("Select a tunnel in menu to connect")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            Button(action: openWGConfig) {
                Text("Open Wireguard Tunnels Folder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            
        }
    }
}
