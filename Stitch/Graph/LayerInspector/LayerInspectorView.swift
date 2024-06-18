//
//  LayerInspectorView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LayerInspectorView: View {
    
    // TODO: better?: allow user to resize inspector; and we read the width via GeometryReader
    static let LAYER_INSPECTOR_WIDTH = 360.0
    
    @State private var debugLocation: String = "none"
    
    @State private var isLayoutExpanded = true
    @State private var isSomeSectionExpanded = true
    @State private var isAnotherSectionExpanded = true
    
    @Bindable var graph: GraphState // should be Bindable?
    
    // TODO: property sidebar changes when multiple sidebar layers are selected
    @MainActor
    var selectedLayerNode: NodeViewModel? {
        
        guard !graph.orderedSidebarLayers.isEmpty else {
            return nil
        }
     
        // Take the last (most-recently) tapped sidebar layer; or the first non-selected layer.
        let inspectedLayer = graph.sidebarSelectionState.nonEditModeSelections.last?.id ?? graph.orderedSidebarLayers.first?.id
        
        //selectedSidebarItems.last ?? graph.orderedSidebarLayers.first
                
        guard let inspectedLayerId = inspectedLayer,
              let node = graph.getNodeViewModel(inspectedLayerId),
              node.layerNode.isDefined else {
            log("LayerInspectorView: No node for sidebar layer \(inspectedLayer)")
            return nil
        }
        
        return node
    }
    
    var body: some View {
        if let node = selectedLayerNode,
           let layerNode = node.layerNode {
            
            // added
            // works for key press listening, but introduces
            UIKitWrapper(ignoresKeyCommands: false,
                         name: "LayerInspectorView") {
                selectedLayerView(node, layerNode)
                    .frame(idealHeight: .infinity)
            }
            // Takes care of the mysterious white top padding UIKitWrapper introduces
            // TODO: compare on various iPads (using simulator?); -40 seems perfect for Catalyst
                         .padding(.top, -40)
            
//            selectedLayerView(node, layerNode)
//                .onAppear {
//                    #if DEV_DEBUG
//                    let listedLayers = Self.required
//                        .union(Self.common)
//                        .union(Self.groupLayer)
//                        .union(Self.unknown)
//                        .union(Self.text)
//                        .union(Self.stroke)
//                        .union(Self.rotation)
//                        .union(Self.shadow)
//                        .union(Self.effects)
//
//                    // TODO: make LayerInputType enum `CaseIterable`
//                    let allLayers = LayerInputType.allCases
//
//                    assert(listedLayers.count == allLayers)
//
//                    #endif
//                }
        } else {
            // Empty List, so have same background
            List { }
        }
    }
        
    @MainActor @ViewBuilder
    func selectedLayerView(_ node: NodeViewModel,
                           _ layerNode: LayerNodeViewModel) -> some View {
        
        
        // bad perf implications?
        let section = { (title: String, layers: LayerInputTypeSet) -> LayerInspectorSectionView in
            LayerInspectorSectionView(
                title: title,
                layers: layers,
                node: node,
                layerNode: layerNode,
                graph: graph)
        }
        
        List {
            // TODO: remove?
//            UIKitWrapper(ignoresKeyCommands: false,
//                         name: "LayerInspectorView") {
//                Text(node.displayTitle).font(.title2)
//            }
            Text(node.displayTitle).font(.title2)
            
            section("Required", Self.required)
            section("Common", Self.common)
            
            if layerNode.layer.supportsGroupInputs {
                section("Group", Self.groupLayer)
            }
            
            if layerNode.layer.supportsUnknownInputs {
                section("Enabled", Self.unknown)
            }
            
            if layerNode.layer.supportsTypographyInputs {
                section("Typography", Self.text)
            }
            
            if layerNode.layer.supportsStrokeInputs {
                section("Stroke", Self.stroke)
            }
            
            if layerNode.layer.supportsRotationInputs {
                section("Rotation", Self.rotation)
            }
            
            if layerNode.layer.supportsShadowInputs {
                section("Shadow", Self.shadow)
            }
            
            if layerNode.layer.supportsLayerEffectInputs {
                section("Layer Effects", Self.effects)
            }
        }
    }
}

struct LayerInspectorPortView: View {
    
    let layerInputType: LayerInputType
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    
    @Bindable var graph: GraphState
    
    var body: some View {
        let definition = layerNode.layer.layerGraphNode
        let inputsList = definition.inputDefinitions
        let rowObserver = layerNode[keyPath: layerInputType.layerNodeKeyPath]
        
        // See if layer node uses this input
        if inputsList.contains(layerInputType),
           let portViewType = rowObserver.portViewType {
            NodeInputOutputView(graph: graph,
                                node: node,
                                rowData: rowObserver,
                                coordinateType: portViewType,
                                nodeKind: .layer(layerNode.layer),
                                isNodeSelected: false,
                                adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId,
                                forPropertySidebar: true)
        } else {
            EmptyView()
        }
    }
}

struct LayerInspectorSectionView: View {
    
    let title: String
    let layers: LayerInputTypeSet
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    @State private var expanded = true
    
    var body: some View {
        Section(isExpanded: $expanded) {
            ForEach(layers) { input in
                LayerInspectorPortView(layerInputType: input,
                                       node: node,
                                       layerNode: layerNode,
                                       graph: graph)
            }
            .transition(.slideInAndOut(edge: .top))
        } header: {
            HStack  {
                StitchTextView(string: title)
                Spacer()
                let rotationZ: CGFloat = expanded ? 90 : 0
                Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
                    .rotation3DEffect(Angle(degrees: rotationZ),
                                      axis: (x: 0, y: 0, z: rotationZ))
                    .animation(.linear(duration: 0.2), value: rotationZ)
            }
            .padding(4)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.expanded.toggle()
                }
                
            }
        }
    }
}


#Preview {
    let graph = GraphState(from: .init(), store: nil)
    let nodeTest = TextLayerNode.createViewModel(position: .zero,
                                                 zIndex: .zero,
                                                 activeIndex: .init(.zero),
                                                 graphDelegate: graph)
    nodeTest.isSelected = true
    
    graph.nodes.updateValue(nodeTest, forKey: nodeTest.id)
    
    return LayerInspectorView(graph: graph)
}

// MARK: each one of these corresponds to a section
extension LayerInspectorView {
    // TODO: fill these out
        
    // TODO: better?: make the LayerInputTypeSet enum CaseIterable and have the enum ordering as the source of truth for this order 
    @MainActor
    static let allInputs: LayerInputTypeSet = Self.required
        .union(Self.common)
        .union(Self.groupLayer)
        .union(Self.unknown)
        .union(Self.text)
        .union(Self.stroke)
        .union(Self.rotation)
        .union(Self.shadow)
        .union(Self.effects)
    
    
    @MainActor
    static let required: LayerInputTypeSet = [
        .position,
        .size,
        .scale,
        .anchoring,
        .opacity,
        .zIndex,
        .pivot // pivot point for scaling; put with
    ]
    
    // Includes some
    @MainActor
    static let common: LayerInputTypeSet = [
        .masks,
        .clipped,
        
        .color, // Text color vs Rectangle color
        
        // Hit Area
        .setupMode,
        
        // Model3D
        .isAnimating,
        
        // Shape layer node
        .shape,
        .coordinateSystem,
        
        // rectangle (and group?)
        .cornerRadius,
        
        // Canvas
        .canvasLineColor,
        .canvasLineWidth,
        
        // text
        .text,
        
        // Media
        .image,
        .video,
        .model3D,
        .fitStyle,
        
        
        // Progress Indicator
        .progressIndicatorStyle,
        .progress,
        
        // Map
        .mapType,
        .mapLatLong,
        .mapSpan,
        
        // Switch
        .isSwitchToggled,
        
        // Gradients
        .startColor,
        .endColor,
        .startAnchor,
        .endAnchor,
        .centerAnchor,
        .startAngle,
        .endAngle,
        .startRadius,
        .endRadius,
        
        // SFSymbol
        .sfSymbol,
        
        // Video
        .videoURL,
        .volume,
        
        // Reality
        .allAnchors,
        .cameraDirection,
        .isCameraEnabled,
        .isShadowsEnabled
    ]
    
    @MainActor
    static let groupLayer: LayerInputTypeSet = [
        .backgroundColor, // actually for many layers?
        .isClipped,
        .orientation,
        .padding,
        // Grid
        .spacingBetweenGridColumns,
        .spacingBetweenGridRows,
        .itemAlignmentWithinGridCell
    ]
     
    // TODO: what are these inputs?
    @MainActor
    static let unknown: LayerInputTypeSet = [
        .lineColor,
        .lineWidth,
        .enabled // what is this?
    ]
 
    @MainActor
    static let text: LayerInputTypeSet = [
        .text,
        .placeholderText,
        .fontSize,
        .textAlignment,
        .verticalAlignment,
        .textDecoration,
        .textFont,
    ]
    
    @MainActor
    static let stroke: LayerInputTypeSet = [
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin
    ]
    
    @MainActor
    static let rotation: LayerInputTypeSet = [
        .rotationX,
        .rotationY,
        .rotationZ
    ]
    
    @MainActor
    static let shadow: LayerInputTypeSet = [
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    @MainActor
    static let effects: LayerInputTypeSet = [
        .blur, // blur vs blurRadius ?
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation
    ]
}

// TODO: derive this from exsiting LayerNodeDefinition ? i.e. filter which sections we show by the LayerNodeDefinition's input list
extension Layer {
    
 
    @MainActor
    var supportsGroupInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.groupLayer).isEmpty
    }
    
    @MainActor
    var supportsUnknownInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.unknown).isEmpty
    }
    
    @MainActor
    var supportsTypographyInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.text).isEmpty
    }
    
    @MainActor
    var supportsStrokeInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.stroke).isEmpty
    }

    @MainActor
    var supportsRotationInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.rotation).isEmpty
    }
    
    @MainActor
    var supportsShadowInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.shadow).isEmpty
    }
    
    @MainActor
    var supportsLayerEffectInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.effects).isEmpty
    }
}

extension LayerInputType: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

//extension LayerInputType: CaseIterable {
//    public static var allCases: [LayerInputType_V18.LayerInputType]
//}
