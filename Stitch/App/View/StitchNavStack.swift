//
//  StitchNavStack.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/23.
//

import SwiftUI
import StitchSchemaKit

struct StitchNavStack: View {
    @Bindable var store: StitchStore
    
    var body: some View {
        NavigationStack(path: $store.navPath) {
            ProjectsHomeViewWrapper()
                .navigationDestination(for: ProjectLoader.self) { projectLoader in
                    ZStack { // Attempt to keep view-identity the same
                        if let document = projectLoader.documentViewModel {
                            StitchProjectView(store: store,
                                              document: document,
                                              alertState: store.alertState)
                            .onDisappear {
                                // Remove document from project loader
                                // MARK: logic needs to be here as its the one place guaranteed to have the project
                                projectLoader.documentViewModel = nil
                            }
                        }
                    }
                    
                }
                .onChange(of: store.navPath.first) { _, currentProject in
                    let currentProjectId = currentProject?.id
                    
                    // Rest undo if project closed
                    if !store.isCurrentProjectSelected {
                        store.environment.undoManager.undoManager.removeAllActions()
                    }
                    
                    // Remove references to other StitchDocuments to release them from memory
                    // Logic here needed for drag-and-drop import with existing document open
                    store.allProjectUrls.forEach { projectLoader in
                        if projectLoader.id != currentProjectId &&
                            projectLoader.documentViewModel != nil {
                            // In case references are stored here (but probably not)
                            projectLoader.lastEncodedDocument = nil
                            
                            // Remove document from memory
                            projectLoader.documentViewModel = nil
                        }
                    }
                }
            
            // TODO: change color of top navigation bar; .red only gives a slight tint (and just on homescreen)
            //                .toolbarBackground(Color(.lightModeWhiteDarkModeBlack),
            ////                .toolbarBackground(.red,
            //                                   for: .navigationBar, .bottomBar, .tabBar)
            //                .toolbarBackground(.visible, for: .navigationBar, .bottomBar, .tabBar)
            
        } // NavigationStack
        
        // Does this event fire when Toolbar freaks out?
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(rawValue: "renewToolbar")),
                   perform: { notification in
            log("StitchNavStack: received 'renewToolbar' notification, name: \(notification.name), description: \(notification.description)", .logToServer)
        })
    }
}

/*
 Disables "pop" view back-swipe: https://stackoverflow.com/a/70873465

 Resolves issue on Sonoma where UIKit/SwiftUI drag gestures were ignored in favor of nav pop back-swipe.

 We don't use back-swipe pop anywhere; user can still exit project via back button.
 */
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// struct CatalystNavStack_Previews: PreviewProvider {
//    static var previews: some View {
//        CatalystNavStack()
//    }
// }
