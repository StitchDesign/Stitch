//
//  ProjectSettingsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/10/22.
//

import SwiftUI
import StitchSchemaKit

struct ProjectSettingsView: View {

    let previewWindowSize: CGSize
    let previewSizeDevice: PreviewWindowDevice
    let previewWindowBackgroundColor: Color
    let graph: GraphState

    var body: some View {

        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                canvasDimensionInputs
                swapImage
                    .padding(.all)
                #if !targetEnvironment(macCatalyst)
                .offset(y: 6)
                #endif

                canvasSizePicker
                    .padding(.leading)
                #if targetEnvironment(macCatalyst)
                // why is this necessary just on Catalyst? why does SwiftUI Menu mess up vertical alignment?
                .offset(y: 12)
                #endif
            }
            StitchCaptionView("Set the size of the prototype's Canvas")
            HStack(alignment: .center) {
                Text("Preview Window Color")
                    .fontWeight(.bold)
                    .frame(maxHeight: previewWindowColorPickerHeight)
                previewWindowColorBackgroundPicker
            }
        }
    }

    func createDeviceDimensionInput(label: String, isWidth: Bool) -> some View {
        StitchTextEditingField(
            currentEdit: label,
            fieldType: .any,
            canvasDimensionInput: label,
            shouldFocus: false) { (newS: String, isCommitting: Bool) in
                dispatch(UpdatePreviewCanvasDimension(edit: newS,
                                                      isWidth: isWidth,
                                                      isCommitting: isCommitting))
            }
            .keyboardType(.decimalPad)
            .frame(maxWidth: 140)
            .modifier(StitchSheetInput())
    }

    var canvasDimensionInputs: some View {
        let widthString = "\(Int(previewWindowSize.width))"
        let heightString = "\(Int(previewWindowSize.height))"

        return VStack(alignment: .leading) {
            Text("Canvas Size").fontWeight(.bold)
            HStack {
                createDeviceDimensionInput(label: widthString,
                                           isWidth: true)
                createDeviceDimensionInput(label: heightString,
                                           isWidth: false)
            }
        }
    }

    @MainActor
    var swapImage: some View {
        return VStack(alignment: .leading) {
            StitchButton(action: {
                dispatch(PreviewWindowDimensionsSwapped())
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                }
            }
            .frame(width: 22, height: 22)
            .aspectRatio(contentMode: .fit)
            .padding(.top, 24)
            .padding(.trailing, -10)
        }
    }

    // TODO: revisit this styling a bit with
    var canvasSizePicker: some View {
        PreviewWindowDeviceSelectionView(
            previewSizeDevice: previewSizeDevice,
            isForProject: true)
    }

    var platformSpecificDisplay: String {
        #if targetEnvironment(macCatalyst)
        return ""
        #else
        return previewWindowBackgroundColor.asHexDisplay
        #endif
    }

    let previewWindowColorPickerHeight: CGFloat = 46

    @MainActor
    var previewWindowColorBackgroundPicker: some View {

        let binding = Binding<Color>.init {
            previewWindowBackgroundColor
        } set: { (color: Color) in
            dispatch(PreviewWindowBackgroundColorSet(color: color))
        }

        return StitchColorPickerView(
            rowId: nil, 
            layerInputObserver: nil,
            fieldCoordinate: .fakeFieldCoordinate,
            isFieldInsideLayerInspector: false,
            isForPreviewWindowBackgroundPicker: true,
            isForIPhone: isPhoneDevice(),
            chosenColor: binding, 
            graph: graph)
    }
}

struct PreviewWindowBackgroundColorSet: StitchDocumentEvent {

    let color: Color

    func handle(state: StitchDocumentViewModel) {
        state.previewWindowBackgroundColor = color
        state.visibleGraph.encodeProjectInBackground()
    }
}

// TODO: create an inner view that still receives this data
struct ProjectSettingsView_Previews: PreviewProvider {
    @State static var show = true
    static let graph = GraphState.createEmpty()

    static var previews: some View {
        ProjectSettingsView(previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
                            previewSizeDevice: .custom,
                            previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR, 
                            graph: graph)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))

        ProjectSettingsView(previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
                            previewSizeDevice: .custom,
                            previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR, 
                            graph: graph)
            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
    }
}
