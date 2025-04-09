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
    let activeIndex: ActiveIndex

    // TODO: do we really need `[PortPreviewData]`? Can we access some already existing data?
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
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    @State var hoveredIndex: Int? = nil
    
    var activeIndexForThisObserver: Int {
        self.activeIndex.adjustedIndex(self.rowObserver.allLoopedValues.count)
    }
    
    var valueGrid: some View {
        VStack(alignment: .leading) {
            
            ForEach(tableRows, id: \.id) { (data: PortPreviewData) in
                
                HStack(alignment: .center) {
                    
                    // Loop index
                    StitchTextView(string: "\(data.loopIndex)",
                                   fontColor: STITCH_FONT_GRAY_COLOR)
                        .monospaced()
                        // 34 = enough for 3 monospaced digits
                        .frame(minWidth: 34, maxWidth: 48)
                    
                    ForEach(data.fields, id: \.0) { field in
                        let label = field.fieldLabel
                        HStack {
                            if !label.isEmpty {
                                StitchTextView(string: "\(label)",
                                           truncationMode: .tail)
                                .monospaced()
                                // 24 = enough for 1 monospaced letter
                                .frame(minWidth: 24)
                            }
                            
                            PortValuesPreviewValueView(fieldValue: field.fieldValue)
                        }
                    } // ForEach(date.fields)
                    
                } // HStack
                .padding([.top, .bottom], 4)
                .background {
                    if self.hoveredIndex == data.loopIndex {
                        RoundedRectangle(cornerRadius: 8).fill(theme.fontColor)
                    } else if self.activeIndexForThisObserver == data.loopIndex {
                        RoundedRectangle(cornerRadius: 8).fill(.gray)
                    }
                }
                .onTapGesture {
                    dispatch(ClosePortPreview())
                }
                .onHover { hovering in
                    if hovering {
//                        log("hovered data.loopIndex \(data.loopIndex)")
                        self.hoveredIndex = data.loopIndex
                        dispatch(ActiveIndexChangedAction(index: .init(data.loopIndex)))
                    }
                }
                
                .padding(.top, 2)
            } // ForEach
        }
    }
}

struct ClosePortPreview: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.openPortPreview = nil
    }
}

// TODO: get popover to work with all values
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
                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                       alignment: .leading) // necessary to prevent overflow scenarios
        }
    }
}
