//
//  NodeOutputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct PortPreviewData: Identifiable {
    let loopIndex: Int
    let fields: [(fieldIndex: Int,
                  fieldLabel: String,
                  fieldValue: FieldValue)]
    
    var id: Int {
        self.loopIndex
    }
}

struct PortValuesPreviewView<NodeRowObserverType: NodeRowObserver>: View {

    @Environment(\.appTheme) var theme
    
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
        
    let nodeIO: NodeIO

    var tableRows: [PortPreviewData] {
        
        let loopedValues: PortValues = rowObserver.allLoopedValues
        
        // TODO: handle ShapeCommand port-preview ?
        guard let labels = loopedValues.first?
            .getNodeRowType(nodeIO: nodeIO,
                            layerInputPort: rowObserver.id.keyPath?.layerInput,
                            // doesn't matter here
                            isLayerInspector: false)
                .fieldGroupTypes.first?.labels else {
            fatalErrorIfDebug()
            return []
        }
        
        let _tableData: [PortPreviewData] = loopedValues.enumerated().compactMap { index, value in
            
            // Most PortValues only use a single field grouping
            // TODO: handle ShapeCommand port-preview ?
            guard let fieldValues = value.createFieldValuesList(
                nodeIO: nodeIO,
                rowViewModel: rowViewModel).first else {
                
                fatalErrorIfDebug()
                return nil
            }
                        
            return PortPreviewData(
                loopIndex: index,
                fields: fieldValues.enumerated().map { (fieldIndex: Int, fieldValue: FieldValue) in
                    return (fieldIndex: fieldIndex,
                            fieldLabel: labels[fieldIndex],
                            fieldValue: fieldValue)
            })
        }
        
        return _tableData
    }
    
    var body: some View {
        ScrollView {
            valueGrid
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding()
    }
    
    @State var hoveredIndex: Int? = nil
    
    var valueGrid: some View {
        VStack(alignment: .leading) {
            
            ForEach(tableRows, id: \.id) { (data: PortPreviewData) in
                
                HStack(alignment: .center) {
                    StitchTextView(string: "\(data.loopIndex)", fontColor: STITCH_FONT_GRAY_COLOR)
                        .monospaced()
                        .gridCellAnchor(UnitPoint(x: 0.5, y: 0)) // aligns middle, top
                    
                    ForEach(data.fields, id: \.0) { field in
                        let label = field.fieldLabel
                        HStack {
                            if !label.isEmpty {
                                StitchTextView(string: "\(field.fieldLabel)",
                                               truncationMode: .tail)
                                .monospaced()
                            }
                            
                            PortValuesPreviewValueView(fieldValue: field.fieldValue)
                        }
                    } // ForEach(date.fields)
                    
                } // HStack
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.hoveredIndex == data.loopIndex ? theme.fontColor : .clear)
                }
                
                .onHover { hovering in
                    if hovering {
                        log("hovered data.loopIndex \(data.loopIndex)")
                        self.hoveredIndex = data.loopIndex
                        dispatch(ActiveIndexChangedAction(index: .init(data.loopIndex)))
                    }
                }
                
                .padding(.top, 2)
            } // ForEach
        }
    }
}

struct PortValuesPreviewValueView: View {
    
    let fieldValue: FieldValue
    
    var body: some View {
        
        switch fieldValue {

        case .color(let color):
            Circle().fill(color).frame(width: 18,
                                       height: 18,
                                       alignment: .center)

        case .anchorPopover(let anchoring):
            AnchoringGridIconView(anchor: anchoring, isSelectedInspectorRow: false)
                .scaleEffect(0.18)
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       height: NODE_ROW_HEIGHT)
                
            
        default:
            // Every other value
            StitchTextView(string: "\(fieldValue.portValuePreview)",
                           lineLimit: 1,
                           truncationMode: .tail)
                .monospaced()
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH, alignment: .leading) // necessary to prevent overflow scenarios
        }
    }
}
