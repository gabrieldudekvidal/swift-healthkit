// Go to Signing & Capabilities and add HealthKit
// Add Privacy info.pslist information

import SwiftUI

struct ContentView: View {
    @State private var manager = HealthKitManager()
    
    var body: some View {
        VStack {
            Text("HealthKit Demo")
                .font(.largeTitle)
        }
        .padding()
        
        VStack {
            Text("\(manager.stepCount)")
                .font(.system(size: 60))
            Text("Steps for today")
                .font(.headline)
                .foregroundStyle(.gray)
        }
        .padding()
        
        VStack {
            Button("Request Permissions") {
                Task {
                    await manager.requestAuthorization()
                }
            }
            
            Button("Refresh Steps") {
                Task {
                    await manager.fetchTodayStepCount()
                }
            }
            
            Button("Log water (250ml)") {
                Task {
                    await manager.logWaterIntake(milliliters: 250)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
