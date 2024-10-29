//
//  StitchRootModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import SwiftUI
import StitchSchemaKit
import UniformTypeIdentifiers

struct StitchRootModifier: ViewModifier {
    @Environment(StitchStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    let alertState: ProjectAlertState

    func body(content: Content) -> some View {
        content
            .modifier(FileDropModifier())
            .modifier(AlertsViewModifier(alertState: alertState))
            .onOpenURL { (url: URL) in
                
                log("StitchRootModifier: onOpenURL: url: \(url)")
                
                if url.isStitchCampsiteURL() {
                    Task { [weak store] in
                        guard let store = store else {
                            fatalErrorIfDebug("StitchRootModifier: had Campsite URL but not StitchStore")
                            return
                        }
                        
                        do {
                            try await onCampsiteURLOpen(url, store: store)
                        } catch {
                            fatalErrorIfDebug("CampiteURL error: \(error)")
                        }
                    }
                    }
                
                else if url.pathExtension == UTType.stitchDocument.preferredFilenameExtension {
                    Task { [weak store] in
                        guard let importedDoc = try? await StitchDocument
                            .openDocument(from: url,
                                          isImport: true) else {
                            log("StitchRootModifier: onOpenURL: could not import \(url)")
                            return
                        }
                        log("StitchRootModifier: onOpenURL: will try to create new project from \(url)")
//                        await store?.createNewProject(from: importedDoc)
                        store?.createNewProject(from: importedDoc)
                    }
                }
            } // .onOpenURL
            .dropDestination(for: StitchDocument.self) { docs, document in
                
                
                log("StitchRootModifier: dropDestination")
                
                // Only open document if one is imported
                if docs.count == 1,
                   let firstDoc = docs.first {
                    store.createNewProject(from: firstDoc)
                }

                return true
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    log("got UIApplication.willResignActiveNotification")
                case .active:
                    log("got UIApplication.willEnterForegroundNotification")
                    dispatch(ColorSchemeReceived(colorScheme: colorScheme))
                    dispatch(KeyModifierReset())
                default:
                    return
                }
            }
    }
}
