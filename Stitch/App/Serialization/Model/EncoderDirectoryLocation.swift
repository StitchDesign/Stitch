//
//  EncoderDirectoryLocation.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import Foundation

enum EncoderDirectoryLocation {
    case document(GraphSaveLocation)
    case clipboard
}

extension EncoderDirectoryLocation {
    var documentSaveLocation: GraphSaveLocation? {
        switch self {
        case .document(let document):
            return document
        default:
            return nil
        }
    }
}
