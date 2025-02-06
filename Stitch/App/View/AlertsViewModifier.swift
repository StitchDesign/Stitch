//
//  AlertsViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/6/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers

struct AlertsViewModifier: ViewModifier {
    @State private var showStitchFileAlert = false
    
    @Bindable var store: StitchStore
    
    var alertState: ProjectAlertState {
        store.alertState
    }
    
    var showSettingsPrompt: Bool {
        alertState.stitchFileError?.showSettingsPrompt ?? false
    }
    
    func body(content: Content) -> some View {
        let showProjectDeletedFromCloudAlert = createBinding(alertState.isCurrentProjectDeleted) {
            // Set state value to false if alert is dismissed
            if !$0 {
                dispatch(ProjectDeletedAlertCompleted())
            }
            log("AlertsViewModifier: show project deleted from cloud alert set to \($0)")
        }
        
        let stitchFileMessage = alertState.stitchFileError?.description ?? ""
        
        content
            .onChange(of: alertState.stitchFileError) { _, stitchFileError in
                showStitchFileAlert = stitchFileError != nil
            }
            .onChange(of: alertState.stitchFileError != nil) { _, showAlert in
                // Hide alert when state value is toggled to false from user dismissing alert
                if !showAlert { dispatch(HideStitchFileErrorAlert()) }
            }
        
        // Confirmation to delete ALL projects
            .alert(Text("This will delete ALL projects. Are you sure you want to proceed?"),
                   isPresented: $store.alertState.showDeleteAllProjectsConfirmation,
                   actions: {
                StitchButton("Keep", role: .cancel) {}
                StitchButton("Delete", role: .destructive) {
                    store.deleteAllProjectsConfirmed()
                }
            })
        
        // Camera permissions
            .alert(Text("You cannot use the camera until permissions have been granted."),
                   isPresented: $store.alertState.showCameraPermissionsAlert,
                   actions: {
                StitchButton("Go to Settings") {
                    let url: String
#if targetEnvironment(macCatalyst)
                    url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
#else
                    url = UIApplication.openSettingsURLString
#endif
                    UIApplication.shared.open(URL(string: url)!)
                }
                StitchButton("Cancel", role: .cancel) {}
            })
        
        // This is the scenario when a project is deleted from another device, and your current device has that same project open
            .alert(Text("Project Deleted"),
                   isPresented: showProjectDeletedFromCloudAlert,
                   actions: {
                StitchButton("Keep", role: .cancel) {
                    dispatch(EncodeCurrentProject())
                }
                StitchButton("Delete", role: .destructive) {
                    dispatch(ProjectDeletedAndWillExitCurrentProject())
                }
            },
                   message: {
                Text("This project has been deleted elsewhere. Would you like to keep it?")
            })
            .alert(stitchFileMessage,
                   isPresented: $showStitchFileAlert) {
                if showSettingsPrompt {
                    // Shortcut button to open settings
                    StitchButton("Enable in Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    StitchButton("Keep Disabled", role: .cancel) { }
                } else {
                    // Default confirmation
                    StitchButton("OK", role: .cancel) { }
                }
            }
    }
}
