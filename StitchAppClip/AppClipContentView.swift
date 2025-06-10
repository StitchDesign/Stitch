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
    
    @State private var store = StitchStore()
    @State var document: StitchDocumentViewModel? = nil
    
    @Namespace private var graphNamespace
    @Namespace private var routerNamespace
    
    var body: some View {
        VStack(spacing: 12) {
            
            Text("Example PortValue \(PortValue.number(99))")
            
            Text("Had document ? ... \(document.isDefined)")
            Text("Received invocation id of 2 ? ... \(self.invocationID == "2")")
            
//            if let document = document {
            if let document = document,
               self.invocationID == "2" {
                logInView("had document now")
                FullScreenPreviewViewWrapper(
                    document: document,
                    previewWindowSizing: document.previewWindowSizingObserver,
                    showFullScreenPreviewSheet: false,
                    graphNamespace: self.graphNamespace,
                    routerNamespace: self.routerNamespace,
                    animationCompleted: true)
            }

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
        .task {
//            let doc = StitchDocumentViewModel.createTestFriendlyDocument(store)
            let (_, documentViewModel) = try! createNewEmptyProject(store: self.store)
            
            let _ = documentViewModel.nodeInserted(choice: .layer(.text))
            let _ = documentViewModel.nodeInserted(choice: .layer(.switchLayer))
            
            // update the graph
            documentViewModel.graph.updateGraphData(documentViewModel)
            
            // update the cached preview layers
            documentViewModel.graph.updateOrderedPreviewLayers(activeIndex: documentViewModel.activeIndex)
            
            self.document = documentViewModel
        }
//        .onAppear {
//            DispatchQueue.main.async {
//                
//                
//            }
//        }
    }
}

#Preview {
    AppClipContentView()
}
