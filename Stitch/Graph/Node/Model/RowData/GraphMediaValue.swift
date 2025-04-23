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
    
    init(computedMedia: StitchMediaObject,
         id: UUID) {
        self.id = id
        self.dataType = .computed
        self.mediaObject = computedMedia
    }
    
    @MainActor
    var portValue: PortValue {
        .asyncMedia(self.mediaValue)
    }
    
    func mediaValue(label: String) -> AsyncMediaValue {
        .init(id: self.id,
              dataType: self.dataType,
              label: label)
    }
    
    func portValue(label: String) -> PortValue {
        .asyncMedia(self.mediaValue(label: label))
    }
    
    @MainActor
    var mediaValue: AsyncMediaValue {
        self.mediaValue(label: self.mediaObject.name)
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
