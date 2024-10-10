//
//  SampleAppsSheet.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/22/22.
//

import SwiftUI
import StitchSchemaKit

/// Sheet for displaying quick-start sample apps to the user. Conditionally presents alert if some error occurs while decoding apps.
struct SampleAppsSheet: ViewModifier {
    let showSampleAppsSheet: Bool
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        return content
        // TODO: sample apps
        // .stitchSheet(isPresented: showSampleAppsSheet,
        //              titleLabel: "Examples",
        //              hideAction: HideSampleProjectSheet()) {
        //     ProjectsScrollView {
        //         ForEach(SampleApp.allCases, id: \.hashValue) { sampleApp in
        //             let metadata = ProjectMetadata(name: sampleApp.rawValue)
        //             ProjectsListItemLoadedView(projectMetadata: metadata,
        //                                        didSchemaDecodingFail: false,
        //                                        projectIdForTitleEdit: nil,
        //                                        namespace: namespace,
        //                                        // should be non-nil? Can we ever
        //                                        exportableProject: nil) {
        //                 log("ProjectsListItemView sample project clicked")
        //                 dispatch(SampleProjectSelected(sampleApp: sampleApp))
        //             }
        //         }
        //     }
        // }
    }
}
