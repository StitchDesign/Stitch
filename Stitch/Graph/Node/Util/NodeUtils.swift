//
//  NodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/29/22.
//

import Foundation
import StitchSchemaKit

extension NodeKind {
    var isSpeakerNode: Bool {
        self == .patch(.speaker)
    }

    /// Returns true if video or image layer node.
    var isVisualMediaNode: Bool {
        switch self {
        case .patch(let patch):
            switch patch {
            case .imageImport, .grayscale, .videoImport, .cameraFeed:
                return true
    
            default:
                return false
            }
            
        case .layer:
            return self.isVisualMediaLayerNode
            
        default:
            return false
        }
    }
    
    var isVisualMediaLayerNode: Bool{
        self == .layer(.image) || self == .layer(.video)
    }
}

let fakeNodeId: UUID = .randomNodeId
