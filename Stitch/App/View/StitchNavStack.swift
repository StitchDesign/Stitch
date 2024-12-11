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
                .navigationDestination(for: StitchDocumentViewModel.self) { document in
                    StitchProjectView(store: store,
                                      document: document,
                                      graphUI: document.graphUI,
                                      alertState: store.alertState)
                }
                .onChange(of: store.isCurrentProjectSelected) {
                    // Rest undo if project closed
                    if !store.isCurrentProjectSelected {
                        store.environment.undoManager.undoManager.removeAllActions()
                    }
                }
            
            // TODO: change color of top navigation bar; .red only gives a slight tint (and just on homescreen)
//                .toolbarBackground(Color(.lightModeWhiteDarkModeBlack),
////                .toolbarBackground(.red,
//                                   for: .navigationBar, .bottomBar, .tabBar)
//                .toolbarBackground(.visible, for: .navigationBar, .bottomBar, .tabBar)
        }
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
