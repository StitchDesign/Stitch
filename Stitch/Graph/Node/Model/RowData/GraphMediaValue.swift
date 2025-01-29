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
    init?(from media: AsyncMediaValue,
          mediaObject: StitchMediaObject) {        
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
        .asyncMedia(self.mediaValue)
    }
    
    var mediaValue: AsyncMediaValue {
        .init(id: self.id,
              dataType: self.dataType)
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
