//
//  AlertsViewModifier.swift
//  prototype
//
//  Created by Elliot Boschwitz on 5/6/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers

struct AlertsViewModifier: ViewModifier {
    let alertState: ProjectAlertState
    @State private var showProjectDeleteAllAlert = false
    @State private var showStitchFileAlert = false
    
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
            .onChange(of: showStitchFileAlert) { _, showAlert in
                // Hide alert when state value is toggled to false from user dismissing alert
                if !showAlert { dispatch(HideStitchFileErrorAlert()) }
            }
        
        // Delete ALL projects
            .onChange(of: alertState.showDeleteAllProjectsConfirmation) { _, willShow in
                showProjectDeleteAllAlert = willShow
            }
            .onChange(of: showProjectDeleteAllAlert) { _, willShow in
                // Hide alert when state value is toggled to false from user dismissing alert
                if !willShow { dispatch(HideDeleteAllProjectsConfirmation()) }
            }
        
        // Confirmation to delete ALL projects
            .alert(Text("This will delete ALL projects. Are you sure you want to proceed?"),
                   isPresented: $showProjectDeleteAllAlert,
                   actions: {
                StitchButton("Keep", role: .cancel) {}
                StitchButton("Delete", role: .destructive) {
                    dispatch(DeleteAllProjectsConfirmed())
                }
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
