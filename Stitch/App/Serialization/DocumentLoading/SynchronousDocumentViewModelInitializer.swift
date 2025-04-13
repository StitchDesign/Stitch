//
//  SynchronousDocumentViewModelInitializer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/12/25.
//

import Foundation

/*
 Primarily intended for test contexts, but could be used in main app if connected properly with DocumentLoader ?
 
 TODO: Why didn't we have a sync initializer already?: https://github.com/StitchDesign/Stitch--Old/issues/7134
 */

@MainActor
func createNewEmptyProject(store: StitchStore) throws -> (ProjectLoader, StitchDocumentViewModel) {
    
    // Create document schema
    let documentSchema = StitchDocument()
    
    // "Install" the document
    try documentSchema.installDocument()
    
    // Create the project loader
    let projectLoader = ProjectLoader(url: documentSchema.rootUrl)
    projectLoader.encoder = .init(document: documentSchema)
    projectLoader.loadingDocument = .loaded(documentSchema, nil)
    
    let documentEncoder = DocumentEncoder(document: documentSchema)
    
    let graph: GraphState = .getNewEmptyGraphState(from: documentSchema.graph,
                                                   saveLocation: [],
                                                   encoder: documentEncoder)
    
    let document: StitchDocumentViewModel = .init(from: documentSchema,
                                                  graph: graph,
                                                  projectLoader: projectLoader,
                                                  store: store,
                                                  isDebugMode: false)

    // TODO: why do we need to set the previewWindow on the document?
    let previewDevice = UserDefaults.standard.string(forKey: DEFAULT_PREVIEW_WINDOW_DEVICE_KEY_NAME)
        .flatMap { PreviewWindowDevice(rawValue: $0) }
    ?? PreviewWindowDevice.defaultPreviewWindowDevice
    
    document.previewSizeDevice = previewDevice
    document.previewWindowSize = previewDevice.previewWindowDimensions
    
    // After both GraphState and StitchDocumentViewModel have been created,
    // initialize the delegates on node view models
    document.graph.nodes.values.forEach { (node: NodeViewModel) in
        node.initializeDelegate(graph: graph, document: document)
    }

    
    projectLoader.documentViewModel = document
    
    document.didDocumentChange = true
    
    store.navPath = [projectLoader]
    
    return (projectLoader, document)
}

extension GraphState {
    
    // NOTE: delegates NOT yet initialized
    @MainActor
    static func getNewEmptyGraphState(from schema: GraphEntity,
                                      localPosition: CGPoint = ABSOLUTE_GRAPH_CENTER,
                                      saveLocation: [UUID],
                                      encoder: (any DocumentEncodable)) -> Self {
        
        var nodes = NodesViewModelDict()
        
        for nodeEntity in schema.nodes {

            switch nodeEntity.nodeTypeEntity {

            case .component:
                continue

            case .patch, .layer, .group:
                let nodeType = NodeViewModelType(from: nodeEntity.nodeTypeEntity, nodeId: nodeEntity.id)
                let newNode = NodeViewModel(from: nodeEntity, nodeType: nodeType)
                nodes.updateValue(newNode, forKey: newNode.id)
            }
        }
        
        return .init(from: schema,
                     localPosition: localPosition,
                     nodes: nodes,
                     components: [:],
                     mediaFiles: [],
                     saveLocation: saveLocation)
    }
}

extension NodeViewModel {
    @MainActor
    convenience init?(from schema: NodeEntity) {
        
        switch schema.nodeTypeEntity {
            
        case .patch, .layer, .group:
            self.init(from: schema,
                      nodeType: NodeViewModelType(from: schema.nodeTypeEntity, nodeId: schema.id))
            return
            
        case .component:
            fatalErrorIfDebug()
            return nil
        }
    }
}
