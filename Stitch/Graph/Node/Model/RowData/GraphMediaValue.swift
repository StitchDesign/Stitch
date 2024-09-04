//
//  GraphMediaValue.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GraphMediaValue: Hashable {
    let id: MediaObjectId
    let dataType: DataType<MediaKey>
    var mediaObject: StitchMediaObject
}

extension GraphMediaValue {
    init?(from media: AsyncMediaValue) {
        guard let mediaObject = media._mediaObject as? StitchMediaObject else {
            return nil
        }
        
        self.id = media.id
        self.dataType = media.dataType
        self.mediaObject = mediaObject
    }
    
    init(computedMedia: StitchMediaObject) {
        self.id = .init()
        self.dataType = .computed
        self.mediaObject = computedMedia
    }
    
    var portValue: PortValue {
        .asyncMedia(.init(id: self.id,
                          dataType: self.dataType,
                          _mediaObject: self.mediaObject))
    }
    
    var mediaKey: MediaKey? {
        switch self.dataType {
        case .source(let mediaKey):
            return mediaKey
        default:
            return nil
        }
    }
}
