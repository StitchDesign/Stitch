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
    let reduxFocusedField: FocusedUserEditField?

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
    
    
    var widthString: String  {
        "\(Int(previewWindowSize.width))"
    }
    
    var heightString: String  {
        "\(Int(previewWindowSize.height))"
    }
    
  
    @ViewBuilder
    var widthDimensionInput: some View {
        if self.widthReduxFocused {
            TextField("", text: self.$previewWindowWidthEdit)
                .focused(self.$focusedPWField, equals: .width)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onSubmit {
                    log("width field submitted")
                    dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
                }
        } else {
            Text(self.previewWindowWidthEdit)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onTapGesture {
                    log("width field tapped")
                    dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
                }
        }
    }
    
    @ViewBuilder
    var heightDimensionInput: some View {
        if self.heightReduxFocused {
            TextField("", text: self.$previewWindowHeightEdit)
                .focused(self.$focusedPWField, equals: .height)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onSubmit {
                    log("height field submitted")
                    dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsHeight))
                }
        } else {
            Text(self.previewWindowHeightEdit)
                .frame(maxWidth: 140, alignment: .leading)
                .modifier(StitchSheetInput())
                .onTapGesture {
                    log("height field tapped")
                    dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
                }
        }
    }
    

    var widthReduxFocused: Bool {
        self.graph.graphUI.reduxFocusedField == .previewWindowSettingsWidth
    }
    
    var heightReduxFocused: Bool {
        self.graph.graphUI.reduxFocusedField == .previewWindowSettingsHeight
    }
    
    enum FocusedPWField {
        case width, height
    }
    
    @FocusState var focusedPWField: FocusedPWField?
    
    @State var previewWindowWidthEdit = ""
    @State var previewWindowHeightEdit = ""
    
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
            
//            // set local focus state
            self.focusedPWField = .width
            
            // set redux state
            dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
        }
        
//        // // When local state changes, update redux state
        .onChange(of: self.focusedPWField, initial: true) { oldValue, newValue in
            log("self.focusedPWField: changed: oldValue: \(oldValue)")
            log("self.focusedPWField: changed: newValue: \(newValue)")
            
            let widthFocused = newValue == .width
            let heightFocused = newValue == .height
            
            log("self.focusedPWField: changed: widthFocused: \(widthFocused)")
            log("self.focusedPWField: changed: heightFocused: \(heightFocused)")
            
            if widthFocused {
                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
            } else if heightFocused {
                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
            }
//            else {
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsHeight))
//            }
        }
        
        // // When redux state changes, update local focus state
        .onChange(of: self.reduxFocusedField, initial: true) { oldValue, newValue in
            log("self.graph.graphUI.reduxFocusedField: changed: oldValue: \(oldValue)")
            log("self.graph.graphUI.reduxFocusedField: changed: newValue: \(newValue)")
            
            let widthFocused = newValue == .previewWindowSettingsWidth
            let heightFocused = newValue == .previewWindowSettingsHeight
            
            log("self.graph.graphUI.reduxFocusedField: changed: widthFocused: \(widthFocused)")
            log("self.graph.graphUI.reduxFocusedField: changed: heightFocused: \(heightFocused)")
            
            if widthFocused {
                self.focusedPWField = .width
            } else if heightFocused {
                self.focusedPWField = .height
            }
//            else {
//                self.focusedPWField = nil
//            }
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
        
        // onChange of redux focused field
//        .onChange(of: self.widthIsFocused) { oldValue, newValue in
//        .onChange(of: self.graph.graphUI.reduxFocusedField == .previewWindowSettingsWidth) { oldValue, newValue in
//            log("self.widthIsFocused: changed: oldValue: \(oldValue)")
//            log("self.widthIsFocused: changed: newValue: \(newValue)")
//            if newValue {
//                self.previewWindowWidthFocus = true
//                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
//            } else {
//                self.previewWindowWidthFocus = false
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
//            }
//        }
//        
//        
////        .onChange(of: self.heightIsFocused) { oldValue, newValue in
//        .onChange(of: self.graph.graphUI.reduxFocusedField == .previewWindowSettingsHeight) { oldValue, newValue in
//            log("self.heightIsFocused: changed: oldValue: \(oldValue)")
//            log("self.heightIsFocused: changed: newValue: \(newValue)")
//            if newValue {
//                self.previewWindowHeightFocus = true
//                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
//            } else {
//                self.previewWindowHeightFocus = false
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsHeight))
//            }
//        }
//        
////        .onChange(self.graph.graphUI.reduxFocusedField) { oldValue, newValue in
////            log("self.graph.graphUI.reduxFocusedField: changed: oldValue: \(oldValue)")
////            log("self.graph.graphUI.reduxFocusedField: changed: newValue: \(newValue)")
////            if newValue == .previewWindowHeightEdit {
////                
////            } else if newValue == .previewW {
////                
////            }
////        }
//        
//        // onChange of local focus variables
//        .onChange(of: self.previewWindowHeightFocus) { oldValue, newValue in
//            log("self.previewWindowHeightFocus: changed: oldValue: \(oldValue)")
//            log("self.previewWindowHeightFocus: changed: newValue: \(newValue)")
//            if !newValue {
//                dispatch(UpdatePreviewCanvasDimension(edit: previewWindowHeightEdit,
//                                                      isWidth: false,
//                                                      isCommitting: true))
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsHeight))
//            }
//            else {
//                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsHeight))
//            }
//        }
//
//        .onChange(of: self.previewWindowWidthFocus) { oldValue, newValue in
//            log("self.previewWindowWidthFocus: changed: oldValue: \(oldValue)")
//            log("self.previewWindowWidthFocus: changed: newValue: \(newValue)")
//            if !newValue {
//                dispatch(UpdatePreviewCanvasDimension(edit: previewWindowWidthEdit,
//                                                      isWidth: true,
//                                                      isCommitting: true))
//                dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
//            }
//            else {
//                dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
//            }
//        }
        
        
//        .onAppear {
//            dispatch(ReduxFieldFocused(focusedField: .previewWindowSettingsWidth))
//        }
//        .onDisappear {
//            dispatch(ReduxFieldDefocused(focusedField: .previewWindowSettingsWidth))
//        }
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
            isForFlyout: false,
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


//// TODO: create an inner view that still receives this data
//struct ProjectSettingsView_Previews: PreviewProvider {
//    @State static var show = true
//    static let graph = GraphState.createEmpty()
//
//    static var previews: some View {
//        ProjectSettingsView(previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
//                            previewSizeDevice: .custom,
//                            previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR, 
//                            graph: graph)
//            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))
//
//        ProjectSettingsView(previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
//                            previewSizeDevice: .custom,
//                            previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR, 
//                            graph: graph)
//            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
//    }
//}
