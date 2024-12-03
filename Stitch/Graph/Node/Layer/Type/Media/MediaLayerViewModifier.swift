//
//  MediaLayerViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/5/24.
//

import SwiftUI
import StitchSchemaKit

final actor MediaLayerImportCoordinator {
    private var cachedValue: GraphMediaValue?
    
    func getUniqueImport(mediaKey: MediaKey,
                         mediaValue: AsyncMediaValue,
                         document: StitchDocumentViewModel,
                         mediaRowObserver: InputNodeRowObserver?) async -> StitchMediaObject? {
        // Limits duplicate object creation
        if mediaKey == cachedValue?.mediaKey {
            return cachedValue?.mediaObject
        }
        
        let newMediaObject = await MediaEvalOpCoordinator
            .createMediaValue(from: mediaKey,
                              isComputedCopy: false,
                              mediaId: mediaValue.id,
                              graphDelegate: document.visibleGraph,
                              nodeId: mediaRowObserver?.id.nodeId)?.mediaObject
        
        // Update fields to refresh media name in dropdown
        if let newMediaObject = newMediaObject {
            let newMediaValue = GraphMediaValue(id: mediaValue.id,
                                                dataType: mediaValue.dataType,
                                                mediaObject: newMediaObject)
            let newPortValue = newMediaValue.portValue
            
            // Update all row view models
            await MainActor.run {
                mediaRowObserver?.allRowViewModels.forEach {
                    $0.activeValueChanged(oldRowType: .asyncMedia,
                                          newValue: newPortValue)
                }
            }
        }
        
        self.cachedValue = newMediaObject.isDefined ? .init(id: mediaValue.id,
                                 dataType: .source(mediaKey),
                                                            mediaObject: newMediaObject!) : nil
        return newMediaObject
    }
}
