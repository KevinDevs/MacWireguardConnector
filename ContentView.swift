import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ViewModel
    
    let connectTunnel: () -> Void
    
    func openWGConfig() {
        // This function will open the WireGuard configuration in Finder
        // Since we can't actually implement NSWorkspace in a SwiftUI view directly,
        // you should call this function from a coordinator or controller that has access to AppKit.
    }
    
    func readConfig(){
        let fileURL = URL(fileURLWithPath: "/usr/local/etc/wireguard/"+viewModel.selectTunnel+".conf")
        
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            viewModel.UIText2 = "Interface: "+viewModel.selectTunnel+"\n\n"
            if viewModel.selectTunnel == viewModel.connTunnel{
                viewModel.UIText2 += "Status: Connected"
            }else{
                viewModel.UIText2 += "Status: Inactive"
            }
            
            viewModel.UIText2 += "\n\n" + contents
        } catch {
            print("Error reading file: \(error)")
        }
    }
    
    
    var body: some View {
        NavigationView {
            List(viewModel.tunnels, id: \.self) { tunnelName in
                Button(action: {
                    viewModel.selectTunnel = tunnelName
                    readConfig()
                    // Here you would also update any additional details for the selected tunnel
                }) {
                    HStack {
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                            .frame(width: 10, height: 10)
                        Text(tunnelName)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Manage WireGuard Tunnels")
            
            
            
            // Detail view
            VStack {
                if viewModel.selectTunnel != "Please Select Tunnel" {
                    // Details for selected tunnel
                    Text(viewModel.UIText2)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if viewModel.selectTunnel == viewModel.connTunnel{
                        Text(viewModel.UIText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: connectTunnel) {
                            Text("Deactivate VPN")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }else{
                        Button(action: connectTunnel) {
                            Text("Activate VPN")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                } else {
                    // No tunnel selected placeholder
                    Text("Please select a tunnel")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300) // Ensure that the detail view has a minimum width
        }
        .frame(minWidth: 700, minHeight: 400) // Ensure that the window has a minimum size
    }
}

// Define your ViewModel as provided
class ViewModel: ObservableObject {
    @Published var UIText: String = "Please Select A Tunnel"
    @Published var UIText2: String = "Please Select A Tunnel"
    @Published var selectTunnel: String = "Please Select Tunnel"
    @Published var connTunnel: String = "None"
    @Published var tunnels: [String] = []
}
