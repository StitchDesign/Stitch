//
//  TopBarSharingButtonsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/30/25.
//

import SwiftUI

struct TopBarSharingButtonsView: View {
#if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
#endif
    
    @Bindable var document: StitchDocumentViewModel
    
    var body: some View {
        Menu {
            ShareLink(item: document.lastEncodedDocument,
                      preview: SharePreview(document.projectName)) {
                Text("Share Document")
                Image(systemName: "document.fill")
            }
            
            StitchButton {
                document.isScreenRecording = true
                
#if targetEnvironment(macCatalyst)
                openWindow(id: RecordingView.windowId)
#else
                document.isFullScreenMode = true
#endif
            } label: {
                Text("Record Prototype")
                Image(systemName: "inset.filled.rectangle.badge.record")
            }
        } label: {
            #if !targetEnvironment(macCatalyst)
            Text("Share")
            #endif
            
            Image(systemName: .SHARE_ICON_SF_SYMBOL_NAME)
        }
    }
}
