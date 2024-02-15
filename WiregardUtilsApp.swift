import SwiftUI
import Cocoa

@main
struct WireguardUtilsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appDelegate.contentViewViewModel, toggleVPNAction: appDelegate.toggleVPN)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var statusMenuItem: NSMenuItem?
    var startVPNItem: NSMenuItem?
    var statusUpdateTimer: Timer?
    var contentViewViewModel = ViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup the menu bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Wireguard")
        }

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarItem.menu = statusBarMenu

        startVPNItem = NSMenuItem(title: "Init", action: #selector(startVPN), keyEquivalent: "")
        statusBarMenu.addItem(startVPNItem!)
        
        
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusMenuItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        statusBarMenu.addItem(statusMenuItem!)
        
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        
        

        // Initialize VPN status check
        checkVPNStatus()
        statusUpdateTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkVPNStatus), userInfo: nil, repeats: true)
    }

    @objc func startVPN() {
        self.startVPNItem?.title = "Connecting..."
        self.startVPNItem?.action = nil
        self.contentViewViewModel.UIText = "Connecting..."
        self.updateStatus(with: "Connecting...")
        updateStatus(with: "Connecting")
        runCommand("sudo wg-quick up wg0;exit")
    }

    @objc func stopVPN() {
        self.startVPNItem?.title = "Disconnecting..."
        self.startVPNItem?.action = nil
        self.contentViewViewModel.UIText = "Disconnecting..."
        self.updateStatus(with: "Disconnecting...")
        updateStatus(with: "Disconnecting")
        runCommand("sudo wg-quick down wg0;networksetup -setdnsservers Wi-Fi empty;exit")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    func runCommand(_ command: String) {
        DispatchQueue.global(qos: .background).async {
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
                        self.startVPNItem?.action = #selector(self.stopVPN)
                        self.contentViewViewModel.UIText = output
                    }
                }else{
                    if self.startVPNItem?.title == "Disconnecting..." || self.startVPNItem?.title == "Init"{
                        self.updateStatus(with: "VPN Stopped")
                        self.startVPNItem?.title = "Connect VPN"
                        self.startVPNItem?.action = #selector(self.startVPN)
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
    @Published var UIText: String = "Waiting for connection"
}

struct ContentView: View {
    @ObservedObject var viewModel: ViewModel
    let toggleVPNAction: () -> Void

    var body: some View {
        VStack {
            Text(viewModel.UIText)
            
            
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
                Button(action: toggleVPNAction) {
                    Text("Connect VPN")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }

            
        }
    }
}
