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
        guard let firstSidebarLayerId = graph.orderedSidebarLayers.first?.id else {
            log("LayerInspectorView: No sidebar layers")
            return nil
        }
        
        guard let node = graph.getNodeViewModel(firstSidebarLayerId),
              node.layerNode.isDefined else {
            log("LayerInspectorView: No node for sidebar layer id \(firstSidebarLayerId)")
            return nil
        }
        
        return node
    }
    
    var body: some View {
        if let node = selectedLayerNode,
           let layerNode = node.layerNode {
            selectedLayerView(node, layerNode)
                .onAppear {
                    #if DEV_DEBUG
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
                    #endif
                }
        } else {
            // Empty List, so have same background
            List { }
        }
    }
        
    @MainActor @ViewBuilder
    func selectedLayerView(_ node: NodeViewModel,
                           _ layerNode: LayerNodeViewModel) -> some View {
        
        
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
            Text(node.displayTitle).font(.title2)
            
            section("Required", Self.required)
            section("Common", Self.common)
            section("Group", Self.groupLayer)
            section("Enabled", Self.unknown)
            section("Text", Self.text)
            section("Stroke", Self.stroke)
            section("Rotation", Self.rotation)
            section("Shadow", Self.shadow)
            section("Layer Effects", Self.effects)
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
                                forLayerProperty: true)
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

extension LayerInputType: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

//extension LayerInputType: CaseIterable {
//    public static var allCases: [LayerInputType_V18.LayerInputType]
//}
