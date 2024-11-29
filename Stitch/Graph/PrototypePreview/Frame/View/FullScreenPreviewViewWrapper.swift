//
//  FullScreenPreviewViewWrapper.swift
//  Stitch
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
    @Bindable var document: StitchDocumentViewModel
    @State private var showDeleteAlert: Bool = false

    let previewWindowSizing: PreviewWindowSizing
    
    let showFullScreenPreviewSheet: Bool
    let graphNamespace: Namespace.ID
    let routerNamespace: Namespace.ID    
    let animationCompleted: Bool

    var previewWindowSize: CGSize {
        document.previewWindowSize
    }

    var previewView: some View {
        PreviewContent(document: document,
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

        let showProjectSettingsAction = { @MainActor in
            dispatch(ShowProjectSettingsSheet())
        }

        let closeGraphBtnAction = { @MainActor in
            // Only close graph if user is on iPhone
            GraphUIState.isPhoneDevice ? dispatch(CloseGraph()) : dispatch(ToggleFullScreenEvent())
        }

        let appResetAction = { @MainActor in
            dispatch(PrototypeRestartedAction())
        }

        FullScreenGestureRecognizerView(showFullScreenPreviewSheet: showFullScreenPreviewSheet) {
            previewView
        }
        .matchedGeometryEffect(id: document.id, in: routerNamespace)
        .matchedGeometryEffect(id: document.id, in: graphNamespace)

        // Only ignore safe areas on iPad/iPhone
        #if !targetEnvironment(macCatalyst)
        .ignoresSafeArea()
        #endif

        // Using actionSheet causes a constraint bug which breaks gesture support
        // https://stackoverflow.com/questions/55372093/uialertcontrollers-actionsheet-gives-constraint-error-on-ios-12-2-12-3
        .alert(actionSheetHeaderString,
               isPresented: showActionSheetBinding) {
            StitchDocumentShareButton(willPresentShareSheet: showActionSheetBinding,
                                      document: document.createSchema())
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
