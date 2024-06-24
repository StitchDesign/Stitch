//
//  AsyncMediaValue.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/2/23.
//

import Foundation
import StitchSchemaKit

typealias MediaObjectId = UUID

extension AsyncMediaValue {
    /// Desired initializer for `AsyncMediaValue`.
    init(id: MediaObjectId = .init(),
         dataType: DataType<MediaKey>,
         mediaObject: StitchMediaObject) {
        self.init(id: id,
                  dataType: dataType,
                  _mediaObject: mediaObject)
    }
    
    /// Optional initializer with NodeId and MediaKey.
    init(mediaKey: MediaKey) {
        self.init(
            id: .init(),
            dataType: .source(mediaKey),
            _mediaObject: nil)
    }

    /// Optional initializer for default media, where loopIndex is always 0 but we need the static global id.
    init(id: UUID, mediaKey: MediaKey) {
        self.init(id: id,
                  dataType: .source(mediaKey),
                  _mediaObject: nil)
    }
    
    var mediaKey: MediaKey? {
        switch dataType {
        case .source(let value):
            return value
        case .computed:
            return nil
        }
    }

    var isImage: Bool {
        self.mediaKey?.getMediaType() == .image
    }
}

extension AsyncMediaValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
        hasher.combine(self.dataType)
    }
}
