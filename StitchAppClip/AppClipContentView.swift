//
//  ContentView.swift
//  StitchAppClip
//
//  Created by Christian J Clampitt on 6/9/25.
//

import SwiftUI
// import Stitch

struct AppClipContentView: View {
    
    @State private var invocationID: String?
    
    var body: some View {
        VStack(spacing: 12) {
            
            MySharedView()
            
//            StitchProjectView(routerNamespace: .init(),
//                              store: StitchStore,
//                              document: <#T##StitchDocumentViewModel#>, alertState: <#T##ProjectAlertState#>, isFullScreen: <#T##arg#>)
            
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Stitch")
                .font(.headline)
            
            Text("Received: \(self.invocationID ?? "Nothing received...")")
                .font(.caption)
        }
        .padding()
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            guard let url = userActivity.webpageURL else {
                print("NO WEB PAGE URL")
                return
            }
            invocationID = url.lastPathComponent
        }
    }
}

#Preview {
    AppClipContentView()
}
