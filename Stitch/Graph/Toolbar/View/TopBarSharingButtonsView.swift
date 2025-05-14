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
    private static let to = "hello@stitchdesign.app"
    private static let subject = "Stitch Feedback"
    
    private static let emailCallout: String = """
**Email to \(Self.to)**

"""
    
    private static let mainBodyString: String = """
What were you trying to do?
[Describe here]

What went well?
[Describe here]

What was confusing or didn’t work?
[Describe here]

Any feature you’d love to see?
[Describe here]

---
App version: \(Self.appVersion)
Platform: \(Self.platform)
"""
    
    private static func bodyStringForAttachment() -> AttributedString {
        var bold = AttributedString("Email to \(Self.to)")
        bold.font = .system(size: 16, weight: .bold)
        bold.backgroundColor = .systemYellow
        
        let rest = AttributedString(Self.mainBodyString)
        
        bold.append(AttributedString("\n\n"))
        bold.append(rest)
        return bold
    }
    
    @Environment(\.openURL) private var openURL
    
    let document: StitchDocumentViewModel?
    var showLabel: Bool = true
    
    private static var appVersion: String {
        let v  = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b  = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "?"
        return "\(v) (\(b))"
    }

    private static var platform: String {
        #if os(iOS) || os(tvOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
        #elseif os(visionOS)
        return "visionOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        return "Unknown"
        #endif
    }
    
    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    private var feedbackURL: URL? {
        URL(string: "mailto:\(Self.to)?subject=\(Self.encode(Self.subject))&body=\(Self.encode(Self.mainBodyString))")
    }
    
    func shareWithDocumentButton(document: StitchDocumentViewModel) -> some View {
        ShareLink(item: document.lastEncodedDocument,
                  subject: Text(Self.subject),
                  message: Text(Self.bodyStringForAttachment()),
                  preview: SharePreview(document.projectName)) {
            Text("Share Document")
            Image(systemName: "document.fill")
        }
    }
    
    var emailButton: some View {
        // Opens the user’s default mail client with a pre-filled address
        StitchButton {
            if let url = self.feedbackURL {
                openURL(url)
            }
        } label: {
            Text("Email")
            Image(systemName: "mail.fill")
        }
    }
    
    var gitHubButton: some View {
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
    }
    
    var body: some View {
        Menu {
            if let document = self.document {
                shareWithDocumentButton(document: document)
            }
            emailButton
            gitHubButton
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
