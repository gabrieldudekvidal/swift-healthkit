import Foundation
import HealthKit
import Observation

@Observable

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    var stepCount: Int  = 0
    var authStatus: String = "Not requested"
    
    func requestAuthorization() async {
        let readTypes: Set<HKSampleType> = [
            HKQuantityType(.stepCount)
        ]
        
        let writeTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryWater)
        ]
        
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = "HealthKit is not available on this device"
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            authStatus = "Auth requested"
        } catch {
            authStatus = "Auth failed \(error.localizedDescription)"
        }
    }
    
    func fetchTodayStepCount() async {
        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: HKSamplePredicate<HKQuantitySample>.quantitySample(type: stepType, predicate: predicate), options: .cumulativeSum)
        
        do {
            let result = try await descriptor.result(for: healthStore)
            
            if let sum = result?.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                await MainActor.run {
                    self.stepCount = steps
                }
            }
        } catch {
            print("Step count failed \(error.localizedDescription)")
        }
    }
    
    func logWaterIntake(milliliters: Double) async {
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        
        do {
            try await healthStore.save(sample)
            print("Save water intake: \(milliliters) ml")
        } catch {
            print("Failed to save \(error.localizedDescription)")
        }
    }
    
    func startObservingStepCount() {
        let stepType = HKQuantityType(.stepCount)
        
        let observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("Observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            Task {
                await self?.fetchTodayStepCount()
            }
            completionHandler()
        }
        
        healthStore.execute(observerQuery)
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
            if success {
                print("Background delivery enabled for steps")
            } else if let error = error {
                print("Background delivery failed: \(error.localizedDescription)")
            }
        }
    }
}
