//
//  Voxel_StridesApp.swift
//  Voxel Strides
//
//  Created by Pushkaraj Baradkar on 7/14/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Voxel_StridesApp: App {
    @State private var showingSplash = true
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Task.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if showingSplash {
                LaunchScreen()
                    .onAppear {
                        // Show splash for 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSplash = false
                            }
                        }
                    }
            } else {
            ContentView()
                    .modelContainer(sharedModelContainer)
                    .onAppear {
                        // Initialize the PersistenceManager with the model context
                        PersistenceManager.shared.setModelContext(sharedModelContainer.mainContext)
                        
                        // Initialize the Accountability Agent
                        _ = AccountabilityAgent.shared
                    }
            }
        }
    }
}

// App Delegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Set the delegate for notification handling
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification responses
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Check if this is a rescheduling notification
        if response.notification.request.content.categoryIdentifier == "RESCHEDULE_CATEGORY" {
            // Handle the user's response
            if response.actionIdentifier == "RESCHEDULE_ACTION" {
                print("User chose to reschedule the task")
                
                // Show a confirmation alert
                DispatchQueue.main.async {
                    let alertController = UIAlertController(
                        title: "Task Rescheduled",
                        message: "Your 'Go for a run' quest has been rescheduled to this afternoon at 4:00 PM.",
                        preferredStyle: .alert
                    )
                    
                    alertController.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    // Get the root view controller
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(alertController, animated: true)
                    }
                }
                
                // If we have a real task ID, use the agent to handle it
                if let taskId = userInfo["taskId"] as? String,
                   let suggestedTimeInterval = userInfo["suggestedTime"] as? TimeInterval {
                    let suggestedTime = Date(timeIntervalSince1970: suggestedTimeInterval)
                    AccountabilityAgent.shared.handleReschedulingResponse(
                        taskId: taskId,
                        suggestedTime: suggestedTime,
                        accepted: true
                    )
                }
            } else if response.actionIdentifier == "KEEP_ACTION" {
                print("User chose to keep the task as is")
                // No action needed, but we could log this decision
            }
        }
        
        completionHandler()
    }
}
