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
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel

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
        
    @ViewBuilder
    var widthDimensionInput: some View {
        if self.widthReduxFocused {
            TextField("", text: self.$previewWindowWidthEdit)
                .padding(.bottom, 1) // slight difference between Text vs TextField
                .focused(self.$focusedPWField, equals: .width)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onSubmit {
                    dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
                }
                
        } else {
            Text(self.previewWindowWidthEdit)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onTapGesture {
                    dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
                }
        }
    }
    
    @ViewBuilder
    var heightDimensionInput: some View {
        if self.heightReduxFocused {
            TextField("", text: self.$previewWindowHeightEdit)
                .padding(.bottom, 1) // slight difference between Text vs TextField
                .focused(self.$focusedPWField, equals: .height)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onSubmit {
                    dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsHeight))
                }
                
        } else {
            Text(self.previewWindowHeightEdit)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onTapGesture {
                    dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
                }
        }
    }
    
    var reduxFocusedField: FocusedUserEditField? {
        document.reduxFocusedField
    }

    var widthReduxFocused: Bool {
        reduxFocusedField == .previewWindowSettingsWidth
    }
    
    var heightReduxFocused: Bool {
        reduxFocusedField == .previewWindowSettingsHeight
    }
    
    enum FocusedPWField {
        case width, height
    }
    
    @FocusState var focusedPWField: FocusedPWField?
    
    @State var previewWindowWidthEdit = ""
    @State var previewWindowHeightEdit = ""
    
    var widthString: String  {
        "\(Int(previewWindowSize.width))"
    }
    
    var heightString: String  {
        "\(Int(previewWindowSize.height))"
    }
    
    var canvasDimensionInputs: some View {
        VStack(alignment: .leading) {
            Text("Canvas Size").fontWeight(.bold)
            HStack {
                widthDimensionInput
                heightDimensionInput
            }
        }
        .onAppear {
            // update local edit variables
            self.previewWindowWidthEdit = self.widthString
            self.previewWindowHeightEdit = self.heightString
            
            // set local focus state
            self.focusedPWField = .width
            
            // set redux state
            dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
        }
        
        // // When local state changes, update redux state
        .onChange(of: self.focusedPWField, initial: true) { oldValue, newValue in
            // log("self.focusedPWField: changed: oldValue: \(oldValue)")
            // log("self.focusedPWField: changed: newValue: \(newValue)")
            
            let widthFocused = newValue == .width
            let heightFocused = newValue == .height
            
            // log("self.focusedPWField: changed: widthFocused: \(widthFocused)")
            // log("self.focusedPWField: changed: heightFocused: \(heightFocused)")
            
            if widthFocused {
                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
            } else if heightFocused {
                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
            }
        }
        
        // // When redux state changes, update local focus state
        .onChange(of: self.reduxFocusedField, initial: true) { oldValue, newValue in
            // log("self.reduxFocusedField: changed: oldValue: \(oldValue)")
            // log("self.reduxFocusedField: changed: newValue: \(newValue)")
            
            let widthFocused = newValue == .previewWindowSettingsWidth
            let heightFocused = newValue == .previewWindowSettingsHeight
            
            // log("self.reduxFocusedField: changed: widthFocused: \(widthFocused)")
            // log("self.reduxFocusedField: changed: heightFocused: \(heightFocused)")
            
            if widthFocused {
                self.focusedPWField = .width
            } else if heightFocused {
                self.focusedPWField = .height
            }
        }
        
        // onChange of edit strings
        .onChange(of: self.previewWindowWidthEdit) { oldValue, newValue in
            dispatch(UpdatePreviewCanvasDimension(edit: newValue,
                                                  isWidth: true,
                                                  isCommitting: false))
        }
        .onChange(of: self.previewWindowHeightEdit) { oldValue, newValue in
            dispatch(UpdatePreviewCanvasDimension(edit: newValue,
                                                  isWidth: false,
                                                  isCommitting: false))
        }
        .onChange(of: self.previewWindowSize) { oldValue, newValue in
            self.previewWindowWidthEdit = widthString
            self.previewWindowHeightEdit = heightString
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
            rowViewModelId: .init(graphItemType: .empty, nodeId: .init(), portId: -1),
            rowObserver: nil,
            fieldCoordinate: .fakeFieldCoordinate,
            isFieldInsideLayerInspector: false,
            isForFlyout: false,
            isForPreviewWindowBackgroundPicker: true,
            isForIPhone: Stitch.isPhoneDevice,
            isMultiselectInspectorInputWithHeterogenousValues: false,
            activeIndex: .init(.zero),
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
