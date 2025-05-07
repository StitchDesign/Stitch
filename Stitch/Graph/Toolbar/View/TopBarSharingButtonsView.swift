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

struct TopBarFeedbackButtonsView: View {
    @Environment(\.openURL) private var openURL
    
    var showLabel: Bool = true
    
    var body: some View {
        Menu {
            // Opens the user’s default mail client with a pre-filled address
            StitchButton {
                if let url = URL(string: "mailto:hello@stitchdesign.app") {
                    openURL(url)
                }
            } label: {
                Text("Email")
                Image(systemName: "mail.fill")
            }
            
            // Launches the system browser and navigates to your site
            StitchButton {
                if let url = URL(string: "https://github.com/StitchDesign/Stitch/issues/new") {
                    openURL(url)
                }
            } label: {
                Label {
                    Text("Post to GitHub")
                } icon: {
                    Image("github")
                        .resizable()
                        .scaledToFit()
                }
                .labelStyle(.titleAndIcon)
            }
        } label: {
#if !targetEnvironment(macCatalyst)
            if showLabel {
                Text("Contact Stitch")                
            }
#endif
            
            Image(systemName: "bubble.left.and.text.bubble.right")
        }
    }
}
