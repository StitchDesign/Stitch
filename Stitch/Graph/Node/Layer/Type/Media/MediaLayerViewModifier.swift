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

/// Processes media changes to handle new media objects and update media-related fields.
struct MediaLayerViewModifier: ViewModifier {
    private let mediaImportCoordinator = MediaLayerImportCoordinator()
    
    let mediaValue: AsyncMediaValue?
    @Binding var mediaObject: StitchMediaObject?
    let document: StitchDocumentViewModel
    let mediaRowObserver: InputNodeRowObserver?
    // Ensures we don't duplicate tasks
    let isRendering: Bool
    
    func body(content: Content) -> some View {
        content
            .task(id: isRendering ? mediaValue?.mediaKey : nil) {
                guard let mediaValue = mediaValue,
                      let mediaKey = mediaValue.mediaKey,
                      isRendering else {
                    // Covers media scenarios, ensuring we set to nil while task makes copy
                    await MainActor.run {
                        Self.resetMedia(self.mediaObject)
                        self.mediaObject = nil                        
                    }
                    return
                }
                
                let newMediaObject = await mediaImportCoordinator
                    .getUniqueImport(mediaKey: mediaKey,
                                     mediaValue: mediaValue,
                                     document: document,
                                     mediaRowObserver: mediaRowObserver)
                
                await MainActor.run {
                    self.mediaObject = newMediaObject
                }
            }
            .onChange(of: self.mediaValue, initial: true) {
                guard let mediaValue = self.mediaValue else {
                    Self.resetMedia(self.mediaObject)
                    self.mediaObject = nil
                    return
                }
                
                if let _mediaObject = mediaValue._mediaObject as? StitchMediaObject {
                    self.mediaObject = _mediaObject
                }
            }
    }
    
    static func resetMedia(_ mediaObject: StitchMediaObject?) {
        // Hack to remove video loop
        if let videoPlayer = mediaObject?.video {
            videoPlayer.pause()
            videoPlayer.stitchVideoDelegate.removeAllObservers()
        }
    }
}
