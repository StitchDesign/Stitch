//
//  FullScreenPreviewViewWrapper.swift
//  prototype
//
//  Created by Elliot Boschwitz on 1/19/22.
//

import SwiftUI
import StitchSchemaKit

let actionSheetHeaderString = "Preview Window Actions"
let changeScaleString = "Change Scale"
let exitString = "Exit Full Screen"
let appResetString = "Reset Prototype"
let cancelString = "Cancel"

struct FullScreenPreviewViewWrapper: View {
    @Bindable var graphState: GraphState
    @State private var showDeleteAlert: Bool = false

    let previewWindowSizing: PreviewWindowSizing
    
    let showFullScreenPreviewSheet: Bool
    let graphNamespace: Namespace.ID
    let routerNamespace: Namespace.ID    
    let animationCompleted: Bool

    var previewWindowSize: CGSize {
        graphState.previewWindowSize
    }

    var previewView: some View {
        PreviewContent(graph: graphState,
                       isFullScreen: true)
        #if !targetEnvironment(macCatalyst)
        .ignoresSafeArea()
        #endif
    }

    var body: some View {
        
        let showActionSheetBinding = createBinding(showFullScreenPreviewSheet) { newValue in

            // Explicitly set the alert-state true or false,
            // rather than use a toggle, which can become out of sync
            // if this value is being toggled elsewhere.
            if newValue {
                dispatch(ShowFullScreenPreviewSheet())
            } else {
                dispatch(CloseFullScreenPreviewSheet())
            }
        }

        let showProjectSettingsAction = { dispatch(ShowProjectSettingsSheet()) }

        let closeGraphBtnAction = {
            // Only close graph if user is on iPhone
            GraphUIState.isPhoneDevice ? dispatch(CloseGraph()) : dispatch(ToggleFullScreenEvent())
        }

        let appResetAction = { dispatch(PrototypeRestartedAction()) }

        FullScreenGestureRecognizerView(showFullScreenPreviewSheet: showFullScreenPreviewSheet) {
            previewView
        }
        .matchedGeometryEffect(id: graphState.id, in: routerNamespace)
        .matchedGeometryEffect(id: graphState.id, in: graphNamespace)

        // Only ignore safe areas on iPad/iPhone
        #if !targetEnvironment(macCatalyst)
        .ignoresSafeArea()
        #endif

        // Using actionSheet causes a constraint bug which breaks gesture support
        // https://stackoverflow.com/questions/55372093/uialertcontrollers-actionsheet-gives-constraint-error-on-ios-12-2-12-3
        .alert(actionSheetHeaderString,
               isPresented: showActionSheetBinding) {
            StitchDocumentShareButton(willPresentShareSheet: showActionSheetBinding,
                                      document: graphState.createSchema())
            StitchButton(changeScaleString, action: showProjectSettingsAction)
            StitchButton(appResetString, action: appResetAction)
            StitchButton(exitString, action: closeGraphBtnAction)
            StitchButton(cancelString, role: .cancel) { }
                .keyboardShortcut(.cancelAction)
        }
        .statusBar(hidden: true)
    }
}

// struct FullScreenPreviewViewWrapper_Previews: PreviewProvider {
//    @Namespace static var mockNamespace
//
//    static var previews: some View {
//        GeometryReader { _ in
//            FullScreenPreviewViewWrapper(
//                graphState: GraphState(),
//                showFullScreenPreviewSheet: false,
//                metadata: ProjectMetadata(name: "Test", lastModifiedDate: Date()),
//                graphNamespace: mockNamespace,
//                routerNamespace: mockNamespace,
//                scale: 1,
//                animationCompleted: true,
//                exportableProject: nil)
//        }
//        .background(.red)
//        .previewDevice(IPAD_PREVIEW_DEVICE_NAME)
//    }
// }
