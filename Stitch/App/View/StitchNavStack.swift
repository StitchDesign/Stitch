//
//  StitchNavStack.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/23.
//

import SwiftUI
import StitchSchemaKit

enum StitchAppRouter {
    case project(ProjectLoader)
    
    // Document encoder needs strong reference and enables nodse to appear in viewer
    case aiPreviewer(StitchDocumentViewModel, DocumentEncoder)
}

extension StitchAppRouter: Identifiable, Hashable {
    static let aiID = UUID().uuidString
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .project(let projectLoader):
            hasher.combine(projectLoader.hashValue)
        case .aiPreviewer(let stitchDocumentViewModel, _):
            hasher.combine(stitchDocumentViewModel.rootId)
        }
    }
    
    static func == (lhs: StitchAppRouter, rhs: StitchAppRouter) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    var id: String {
        switch self {
        case .project(let projectLoader):
            return projectLoader.url.absoluteString
        case .aiPreviewer:
            return Self.aiID
        }
    }
    
    var project: ProjectLoader? {
        switch self {
        case .project(let projectLoader):
            return projectLoader
        case .aiPreviewer:
            return nil
        }
    }
    
    @MainActor
    var document: StitchDocumentViewModel? {
        switch self {
        case .project(let projectLoader):
            return projectLoader.documentViewModel
        case .aiPreviewer(let stitchDocumentViewModel, _):
            return stitchDocumentViewModel
        }
    }
}

struct StitchNavStack: View {
    @Environment(\.dismissWindow) private var dismissWindow

    @Bindable var store: StitchStore
    
    var body: some View {
        // TODO: need to determine a router
        NavigationStack(path: $store.navPath) {
            ProjectsHomeViewWrapper()
                .navigationDestination(for: StitchAppRouter.self) { router in
                    
                    switch router {
                    case .project(let projectLoader):
                        ZStack { // Attempt to keep view-identity the same
                            if let document = projectLoader.documentViewModel {
                                StitchProjectView(store: store,
                                                  document: document,
                                                  alertState: store.alertState)
                                .onDisappear {
                                    // Remove document from project loader
                                    // MARK: logic needs to be here as its the one place guaranteed to have the project
                                    projectLoader.documentViewModel = nil
                                    
                                    // Close mac screen sharing if still visible
#if targetEnvironment(macCatalyst)
                                    dismissWindow(id: RecordingView.windowId)
#endif
                                }
                            }
                        }
                        
                    case .aiPreviewer(let document, _):
                        StitchAIProjectViewer(store: store,
                                              document: document)
                    }
                    
                }
                .onChange(of: store.navPath.first) { _, currentProject in
                    let currentGraphId = currentProject?.project?.id
                    
                    // Rest undo if project closed
                    if !store.isCurrentProjectSelected {
                        store.environment.undoManager.undoManager.removeAllActions()
                    }
                    
                    // Remove references to other StitchDocuments to release them from memory
                    // Logic here needed for drag-and-drop import with existing document open
                    store.allProjectUrls?.forEach { projectLoader in
                        if projectLoader.id != currentGraphId &&
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
