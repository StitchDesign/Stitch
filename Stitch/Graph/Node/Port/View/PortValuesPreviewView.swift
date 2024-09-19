//
//  NodeOutputView.swift
//  prototype
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

    @Bindable var rowObserver: NodeRowObserverType
        
    let nodeIO: NodeIO

    var tableRows: [PortPreviewData] {
        
        let loopedValues: PortValues = rowObserver.allLoopedValues
        
        // TODO: handle ShapeCommand port-preview ?
        guard let labels = loopedValues.first?.getNodeRowType(nodeIO: nodeIO).fieldGroupTypes.first?.labels else {
            fatalErrorIfDebug()
            return []
        }
        
        let _tableData: [PortPreviewData] = loopedValues.enumerated().compactMap { index, value in
            
            // Most PortValues only use a single field grouping
            // TODO: handle ShapeCommand port-preview ?
            guard let fieldValues = value.createFieldValuesList(
                nodeIO: nodeIO,
                // Don't display media object?
                importedMediaObject: nil).first else {
                
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
        .padding()
    }
    
    var valueGrid: some View {
        Grid {
            GridRow {
                StitchTextView(string: "Loop")
                    .monospaced()
                    .frame(minWidth: 40)    // necessary to prevent overflow scenarios
                    .gridCellAnchor(UnitPoint(x: 0.5, y: 0.5))
               
                StitchTextView(string: "Values", lineLimit: 1)
                    .monospaced()
                    .gridCellAnchor(UnitPoint(x: 0, y: 0.5))
                    .gridCellColumns(2)
            }
            .padding(.bottom, 2)

            ForEach(tableRows, id: \.id) { (data: PortPreviewData) in
                GridRow {
                    StitchTextView(string: "\(data.loopIndex)")
                        .monospaced()
                        .gridCellAnchor(UnitPoint(x: 0.5, y: 0)) // aligns middle, top

                    ForEach(data.fields, id: \.0) { field in
                        let label = field.fieldLabel

                        Group {
                            if !label.isEmpty {
                                StitchTextView(string: "\(field.fieldLabel):",
                                               truncationMode: .tail)
                                    .monospaced()
                            }
                        }
                        .gridCellAnchor(UnitPoint(x: 0, y: 0)) // aligns right, top

                        PortValuesPreviewValueView(fieldValue: field.fieldValue)
                            .fixedSize(horizontal: true, vertical: false) // make sure
                            .gridCellAnchor(UnitPoint(x: 0, y: 0)) // aligns left, top
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

// just pass the FieldValue and
struct PortValuesPreviewValueView: View {

    let fieldValue: FieldValue

    var body: some View {

        switch fieldValue {

        case .color(let color):
            Circle().fill(color).frame(width: 18,
                                       height: 18,
                                       alignment: .center)

        default:
            // Every other value
            StitchTextView(string: "\(fieldValue.portValuePreview)",
                           truncationMode: .tail)
                .monospaced()
                .frame(minWidth: 40) // necessary to prevent overflow scenarios
        }
    }
}
