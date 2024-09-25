//
//  StitchComponentUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/17/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import UniformTypeIdentifiers

extension StitchComponent: StitchComponentable {
    static let zippedFileType: UTType = .stitchComponentZipped
    static let unzippedFileType: UTType = .stitchComponentUnzipped

    /// Builds path given possible nesting inside other components
    var rootUrl: URL {
        self.saveLocation.getRootUrl(componentId: self.id,
                                     isPublished: false)
    }
    
    var publishedRootUrl: URL {
        self.saveLocation.getRootUrl(componentId: self.id,
                                     isPublished: true)
    }
}

extension StitchComponentable {
    public var id: UUID {
        get {
            self.graph.id
        }
        set(newValue) {
            self.graph.id = newValue
        }
    }
    
    var name: String {
        self.graph.name
    }
    
    var dataJsonUrl: URL {
        self.rootUrl.appendingVersionedSchemaPath()
    }
    
    var nodes: [NodeEntity] {
        self.graph.nodes
    }
    
    var orderedSidebarLayers: SidebarLayerList {
        self.graph.orderedSidebarLayers
    }
}

public struct GraphDocumentPath: Codable, Equatable, Sendable {
    let docId: UUID
    let componentsPath: [UUID]
}

// TODO: move to SSK
public enum GraphSaveLocation: Codable, Equatable, Sendable {
    case document(GraphDocumentPath)
    case userLibrary
    // TODO: system
    //case system(UUID)
}

extension GraphSaveLocation {
    func getRootUrl(componentId: UUID,
                    isPublished: Bool) -> URL {
        switch self {
        case .document(let graphDocumentPath):
            let rootDocPath = StitchDocument.getRootUrl(from: graphDocumentPath.docId)
            
            let componentPath = graphDocumentPath.componentsPath.reduce(into: rootDocPath) { url, docId in
                url = url
                    .appendingComponentsPath()
                    .appendingPathComponent(docId.uuidString, conformingTo: .stitchComponentUnzipped)
                    .appendingComponentDraftPath()     // Always use draft path
            }
            
            // lastly append with direct parent folders
            .appendingComponentsPath()
            .appendingPathComponent(componentId.uuidString, conformingTo: .stitchComponentUnzipped)
            
            return isPublished ? componentPath.appendingComponentPublishedPath() : componentPath.appendingComponentDraftPath()
            
        case .userLibrary:
            // TODO: come back to user library
            fatalError()
        }
    }
}

//extension GraphDocumentPath {
//    func appendingComponent(_ id: UUID) -> Self {
//        .init(docId: self.docId,
//              componentsPath: componentsPath + [id])
//    }
//}

// TODO: consider data structure here
//struct ComponentSaveData {
//    var type: ComponentSaveLocation
//    var component: StitchComponent
//}

//extension ComponentSaveData: MediaDocumentEncodable {
//    var rootUrl: URL {
//        switch type {
//        case .document(let documentId):
//            StitchDocument.getRootUrl(from: documentId)
//                .appendingPathComponent(URL.componentsDirPath,
//                                        conformingTo: .stitchComponent)
//        case .userLibrary:
//            // TODO: come back to user library
//            fatalError()
//        }
//    }
//    
//    public static var transferRepresentation: some TransferRepresentation {
//        FileRepresentation(contentType: .stitchComponent,
//                           exporting: Self.exportComponent,
//                           importing: Self.importComponent)
//    }
//
//    @Sendable
//    static func exportComponent(_ component: StitchComponent) async -> SentTransferredFile {
//        await component.encodeDocumentContents()
//
//        let url = component.rootUrl
//        await ComponentSaveData.exportComponent(component, url: url)
//        return SentTransferredFile(url)
//    }
//
//    @Sendable
//    static func exportComponent(_ component: StitchComponent, url: URL) async {
//        do {
//            let encodedData = try getStitchEncoder().encode(component)
//            try encodedData.write(to: url, options: .atomic)
//        } catch {
//            log("exportComponent error: \(error)")
//            #if DEBUG
//            fatalError()
//            #endif
//        }
//    }
//
//    @Sendable
//    static func importComponent(_ received: ReceivedTransferredFile) async -> ComponentSaveData {
//        fatalError()
//        //        do {
//        //            guard let doc = try await Self.importDocument(from: received.file,
//        //                                                          isImport: true) else {
//        //                //                #if DEBUG
//        //                //                fatalError()
//        //                //                #endif
//        //                DispatchQueue.main.async {
//        //                    dispatchStitch(.displayError(.unsupportedProject))
//        //                }
//        //                return StitchDocument()
//        //            }
//        //
//        //            return doc
//        //        } catch {
//        //            #if DEBUG
//        //            fatalError()
//        //            #endif
//        //            return StitchDocument()
//        //        }
//    }
//}
