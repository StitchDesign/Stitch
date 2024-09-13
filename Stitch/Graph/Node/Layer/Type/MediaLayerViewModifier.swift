//
//  MediaLayerViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/5/24.
//

import SwiftUI
import StitchSchemaKit

/// Processes media changes to handle new media objects and update media-related fields.
struct MediaLayerViewModifier: ViewModifier {
    let mediaValue: AsyncMediaValue?
    @Binding var mediaObject: StitchMediaObject?
    let document: StitchDocumentViewModel
    let mediaRowObserver: InputNodeRowObserver?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: self.mediaValue, initial: true) {
                guard let mediaValue = self.mediaValue else {
                    self.mediaObject = nil
                    return
                }
                
                if let _mediaObject = mediaValue._mediaObject as? StitchMediaObject {
                    self.mediaObject = _mediaObject
                } else if let mediaKey = mediaValue.mediaKey {
                    // Create media if none assigned to the port value
                    Task(priority: .high) { [weak document, weak mediaRowObserver] in
                        guard let document = document else {
                            return
                        }
                        
                        let newMediaObject = await MediaEvalOpCoordinator
                            .createMediaValue(from: mediaKey,
                                              isComputedCopy: false,
                                              mediaId: mediaValue.id,
                                              graphDelegate: document.visibleGraph,
                                              nodeId: mediaRowObserver?.id.nodeId)?.mediaObject
                        self.mediaObject = newMediaObject
                        
                        // Update fields to refresh media name in dropdown
                        if let newMediaObject = newMediaObject {
                            let newMediaValue = GraphMediaValue(id: mediaValue.id,
                                                                dataType: mediaValue.dataType,
                                                                mediaObject: newMediaObject)
                            let newPortValue = newMediaValue.portValue
                            
                            // Update all row view models
                            mediaRowObserver?.allRowViewModels.forEach {
                                $0.activeValueChanged(oldRowType: .asyncMedia,
                                                      newValue: newPortValue)
                            }
                        }
                    }
                }
            }
    }
}
