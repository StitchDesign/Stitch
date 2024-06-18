//
//  NodeOutputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct PortValuesPreviewData<FieldType: FieldViewModel>: Identifiable {
    let id = UUID()
    let loopIndex: Int
    let fields: [FieldType]
}

struct PortValuesPreviewView<RowObserver>: View where RowObserver: NodeRowObserver {

    // Pin `NodeRowData` via `@ValuesObserver` so that this view re-renders as `NodeRowData.values` changes
    @Bindable var data: RowObserver
    let fieldValueTypes: [FieldGroupTypeViewModel<RowObserver.RowViewModelType.FieldType>]
    let coordinate: NodeIOCoordinate
    let nodeIO: NodeIO

    @State private var tableData: [PortValuesPreviewData<RowObserver.RowViewModelType.FieldType>] = []

    var values: PortValues {
        self.data.allLoopedValues
    }

    var nodeId: NodeId {
        self.coordinate.nodeId
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

            ForEach(tableData) { data in
                GridRow {
                    StitchTextView(string: "\(data.loopIndex)")
                        .monospaced()
                        .gridCellAnchor(UnitPoint(x: 0.5, y: 0)) // aligns middle, top

                    ForEach(data.fields) { field in
                        let label = field.fieldLabel

                        Group {
                            if !label.isEmpty {
                                StitchTextView(string: "\(field.fieldLabel):",
                                               truncationMode: .tail)
                                    .monospaced()
                            }
                        }
                        .gridCellAnchor(UnitPoint(x: 0, y: 0)) // aligns right, top

                        PortValuesPreviewValueView(field: field)
                            .fixedSize(horizontal: true, vertical: false) // make sure
                            .gridCellAnchor(UnitPoint(x: 0, y: 0)) // aligns left, top
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    var body: some View {
        ScrollView {
            valueGrid
        }
        .onChange(of: self.data.allLoopedValues, initial: true) {
            self.updateTableData(with: self.data.allLoopedValues)
        }
        .padding()
    }

    @MainActor
    func updateTableData(with values: PortValues) {
        let enumerated = Array(zip(values.indices, values))
        self.tableData = enumerated.map { index, _ in
            let rowObserver = RowObserver(values: values,
                                          nodeKind: data.nodeKind,
                                          userVisibleType: data.userVisibleType,
                                          id: self.data.id,
                                          activeIndex: .init(index),
                                          upstreamOutputCoordinate: nil,
                                          nodeDelegate: self.data.nodeDelegate)

            let fields = fieldValueTypes.flatMap { $0.fieldObservers }

            return .init(loopIndex: index,
                         fields: fields)
        }
    }
}

struct PortValuesPreviewValueView<FieldType>: View where FieldType: FieldViewModel {

    let field: FieldType

    var body: some View {

        switch field.fieldValue {

        case .color(let color):
            Circle().fill(color).frame(width: 18,
                                       height: 18,
                                       alignment: .center)

        default:
            // Every other value
            StitchTextView(string: "\(field.fieldValue.portValuePreview)",
                           truncationMode: .tail)
                .monospaced()
                .frame(minWidth: 40) // necessary to prevent overflow scenarios

        }

    }
}

// struct PortValuesPreviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        let values1 = PortValuesObserver([
//            .position(.zero),
//            .position(.init(width: 30.999122, height: 30000))
//        ],
//        Coordinate.input(InputCoordinate(portId: 0, nodeId: .init()))
//        )
//        //        let values2: PortValues = [
//        //            .number(.zero),
//        //            .number(30.999122)
//        //        ]
//
//        VStack {
//            PortValuesPreviewView(valuesObserver: values1, isInput: true)
//            //            Divider()
//            //            PortValuesPreviewView(values: values2)
//
//        }
//
//    }
// }
