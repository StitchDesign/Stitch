//
//  Model3DLayerUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/16/25.
//

import RealityKit
import SwiftUI
import StitchSchemaKit

extension View {
    func model3DModifier(viewModel: LayerViewModel,
                         entityType: StitchEntityType,
                         isPinnedViewRendering: Bool) -> some View {
        self.modifier(Model3DViewModifier(viewModel: viewModel,
                                          entityType: entityType,
                                          isPinnedViewRendering: isPinnedViewRendering))
    }
}

struct Model3DViewModifier: ViewModifier {
    let viewModel: LayerViewModel
    let entityType: StitchEntityType
    let isPinnedViewRendering: Bool
    
    @MainActor
    private func updateEntity(entity: StitchEntity) {
        entity.update(layerViewModel: viewModel)
    
        // Needed for gesture support if implicit sizing changed
        entity.updateCollisionBounds()
    }
    
    @MainActor
    private func updateEntity() {
        if let entity = self.viewModel.mediaObject?.model3DEntity {
            self.updateEntity(entity: entity)
        }
    }
    
    @MainActor
    private func createEntity() -> StitchEntity {
        let entity = Entity()
        let stitchEntity = StitchEntity(type: entityType,
                                        entity: entity)
        
        self.updateEntity(entity: stitchEntity)
        
        return stitchEntity
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard isPinnedViewRendering,
                      viewModel.mediaObject == nil else {
                    return
                }
                
                // Set state for media object
                let entity = self.createEntity()
                viewModel.mediaViewModel.inputMedia = .init(computedMedia: .model3D(entity))
            }
            .onChange(of: viewModel.size3D) {
                self.updateEntity()
            }
            .onChange(of: viewModel.radius3D) {
                self.updateEntity()
            }
            .onChange(of: viewModel.height3D) {
                self.updateEntity()
            }
            .onChange(of: viewModel.color) {
                self.updateEntity()
            }
            .onChange(of: viewModel.isMetallic) {
                self.updateEntity()
            }
            .onChange(of: viewModel.cornerRadius) {
                self.updateEntity()
            }
    }
}
