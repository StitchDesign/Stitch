//
//  BoxLayerNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/13/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

struct BoxLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.box

    static let inputDefinitions: LayerInputPortSet = .init([
        .anchorEntity,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset,
        .transform3D,
        .translation3DEnabled,
        .scale3DEnabled,
        .rotation3DEnabled,
        .cornerRadius,
        .isMetallic,
        .size3D,
        .color
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    @MainActor
    private static func createEntity(viewModel: LayerViewModel) -> StitchEntity {
        let entity = Entity()
        let stitchEntity = StitchEntity(type: .box, entity: entity)
        
        Self.updateEntity(entity: stitchEntity,
                          viewModel: viewModel)
        
        return stitchEntity
    }
    
    @MainActor
    private static func updateEntity(entity: StitchEntity,
                                     viewModel: LayerViewModel) {
        entity.update(size3D: viewModel.size3D.getPoint3D ?? .zero,
                      cornerRadius: viewModel.cornerRadius.getNumber ?? .zero,
                      color: viewModel.color.getColor ?? .red,
                      isMetallic: viewModel.isMetallic.getBool ?? false)
    
        // Needed for gesture support if implicit sizing changed
        entity.updateCollisionBounds()
    }
    
    @MainActor
    private static func updateEntity(viewModel: LayerViewModel) {
        if let entity = viewModel.mediaObject?.model3DEntity {
            Self.updateEntity(entity: entity,
                              viewModel: viewModel)
        }
    }
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: Binding<LayerRealityCameraContent?>) -> some View {
        Model3DLayerNode
            .content(document: document,
                     graph: graph,
                     viewModel: viewModel,
                     parentSize: parentSize,
                     layersInGroup: layersInGroup,
                     isPinnedViewRendering: isPinnedViewRendering,
                     parentDisablesPosition: parentDisablesPosition,
                     parentIsScrollableGrid: parentIsScrollableGrid,
                     realityContent: realityContent)
            .onAppear {
                guard isPinnedViewRendering,
                      viewModel.mediaObject == nil else {
                    return
                }
                
                // Set state for media object
                let entity = Self.createEntity(viewModel: viewModel)
                viewModel.mediaObject = .model3D(entity)
            }
            .onChange(of: viewModel.size3D) {
                Self.updateEntity(viewModel: viewModel)
            }
            .onChange(of: viewModel.color) {
                Self.updateEntity(viewModel: viewModel)
            }
            .onChange(of: viewModel.isMetallic) {
                Self.updateEntity(viewModel: viewModel)
            }
            .onChange(of: viewModel.cornerRadius) {
                Self.updateEntity(viewModel: viewModel)
            }
    }
}
