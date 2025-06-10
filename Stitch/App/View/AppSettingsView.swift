//
//  AppSettingsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/18/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVFoundation

// Formerly `ProjectSettingsView.canvasSizePicker`
struct PreviewWindowDeviceSelectionView: View {

    @AppStorage(StitchAppSettings.DEFAULT_PREVIEW_WINDOW_DEVICE.rawValue) private var defaultPreviewWindowDevice: String = PreviewWindowDevice.defaultPreviewWindowDevice.rawValue

    // ^^ does assigning a value here ALWAYS provide that value, or just a default?

    // Existing/current preview window device
    var previewSizeDevice: PreviewWindowDevice

    // If we're using the preview-window-device picker from within a project,
    // we're setting the size for the project's
    // Else we're setting the default preview window size for a new project.
    let isForProject: Bool

    var body: some View {
        if isForProject {
            projectSettingsMenu
        } else {
            appSettingsMenu
        }
    }

    @MainActor
    var canvasMenu: some View {

        Menu {
            canvasSizeSubmenu(caseName: "iPhone",
                              cases: PreviewWindowDevice.allCases.filter(\.isIPhone))

            canvasSizeSubmenu(caseName: "iPad",
                              cases: PreviewWindowDevice.allCases.filter(\.isIPad))

            canvasSizeSubmenu(caseName: "MacBook",
                              cases: PreviewWindowDevice.allCases.filter(\.isMacBook))

            canvasSizeSubmenu(caseName: "iMac",
                              cases: PreviewWindowDevice.allCases.filter(\.isIMac))
        } label: {

            if isForProject {
                Button(action: {}, label: {
                    HStack {
                        Text(previewSizeDevice.rawValue)
                        #if !targetEnvironment(macCatalyst)
                        Image(systemName: "chevron.up.chevron.down")
                        #endif
                    }
                })
                //                Button(previewSizeDevice.rawValue, action: { })
                .frame(width: 140, alignment: .center)
                .padding(.top, 37)
                //  Catalyst's Picker needs a little more room on the side
                #if targetEnvironment(macCatalyst)
                .padding(.trailing, 12)
                #endif
            } else {
                HStack {
                    Text(previewSizeDevice.rawValue)
                    #if !targetEnvironment(macCatalyst)
                    Image(systemName: "chevron.up.chevron.down")
                    #endif
                }

            }
        }

    }

    @MainActor
    var projectSettingsMenu: some View {
        canvasMenu
        #if targetEnvironment(macCatalyst)
        .menuStyle(.button)
        .buttonStyle(.borderless)
        #else
        .menuStyle(.button)
        .buttonStyle(.automatic)
        #endif
    }

    @MainActor
    var appSettingsMenu: some View {
        canvasMenu
        #if targetEnvironment(macCatalyst)
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        #else
        .menuStyle(.button)
        //            .buttonStyle(.bordered) // looks terrible on iPad!
        .buttonStyle(.automatic)
        #endif
    }

    @MainActor
    func canvasSizeSubmenu(caseName: String,
                           cases: [PreviewWindowDevice]) -> some View {

        let customSizeBinding = createBinding(previewSizeDevice) { (choice: PreviewWindowDevice) in
            if isForProject {
                dispatch(UpdatePreviewCanvasDevice(previewSize: choice))
            } else {
                self.defaultPreviewWindowDevice = choice.rawValue
            }
        }

        return Picker(caseName, selection: customSizeBinding) {
            // Setting an `id` in the loop fixes a SwiftUI bug preventing the picker from updating
            ForEach(cases, id: \.self) { sizeName in
                Text(sizeName.rawValue)
            }
        }
        .pickerStyle(.menu)

        //        .frame(width: 140, alignment: .leading)
        //        .padding(.top, 37)
        // Catalyst's Picker needs a little more room on the side
        // #if targetEnvironment(macCatalyst)
        //        .padding(.trailing, 12)
        // #endif
    }

}

// TODO: move
enum StitchAppSettings: String {
    case DEFAULT_PREVIEW_WINDOW_DEVICE = "DefaultPreviewWindowDevice"
    case APP_THEME = "SavedAppTheme"
    case EDGE_STYLE = "SavedEdgeStyle"
    case IS_OPTION_REQUIRED_FOR_SHORTCUTS = "SavedIsOptionRequiredForShortcuts"
    case CAN_SHARE_AI_DATA = "CanShareAIData"
    case EXPERIMENTAL_JS_NODE = "ExperimentalJsNode"
    case EXPERIMENTAL_NODE_SUMMARIES = "ExperimentalNodeSummaries"
}

struct AppSettingsView: View {
    @State private var showAILogsAlert = false
    @State private var showDataCollectionPopover = false
    
    // Obtains last camera preference setting, if any
    @AppStorage(CAMERA_PREF_KEY_NAME) private var cameraPrefId: String?

    @AppStorage(StitchAppSettings.DEFAULT_PREVIEW_WINDOW_DEVICE.rawValue) private var defaultPreviewWindowDevice: String = PreviewWindowDevice.defaultPreviewWindowDevice.rawValue

    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme

    @AppStorage(StitchAppSettings.EDGE_STYLE.rawValue) private var edgeStyle: EdgeStyle = EdgeStyle.defaultEdgeStyle
    
    @AppStorage(StitchAppSettings.IS_OPTION_REQUIRED_FOR_SHORTCUTS.rawValue) private var isOptionRequiredForShortcuts: Bool = Bool.defaultIsOptionRequiredForShortcuts
    
    @AppStorage(StitchAppSettings.CAN_SHARE_AI_DATA.rawValue) private var canShareAIData: Bool?
    
    @AppStorage(StitchAppSettings.EXPERIMENTAL_JS_NODE.rawValue) private var enabledJsNode: Bool = false
    
    @AppStorage(StitchAppSettings.EXPERIMENTAL_NODE_SUMMARIES.rawValue) private var enabledNodeSummaries: Bool = false
        
    let allCameraChoices = getCameraPickerOptions()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cameraPicker
            themePicker
            edgeStylePicker
            defaultPreviewWindowDevicePicker
            isOptionRequiredForShortcutsPicker
            canShareAIRetriesPicker
            
            Divider()
            Text("Experimental Features")
                .font(.subheadline)
            
            experimentalJsNodeCheckbox
            experimentalNodeSummariesCheckbox
        }
    }

    @MainActor
    var cameraPicker: some View {
        // the last local camera selection (if any)
        let cameraSelection = getCameraSelection(cameraID: self.cameraPrefId)

        return VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text("Camera").fontWeight(.bold)
                Menu {
                    // Setting an `id` in the loop fixes a SwiftUI bug preventing the picker from updating
                    ForEach(allCameraChoices, id: \.self.uniqueID) { device in
                        let label = device.localizedName
                        Button(label) {
                            dispatch(CameraPreferenceChanged(
                                        cameraId: device.uniqueID))
                        }
                    }
                } label: {
                    HStack {
                        Text("\(cameraSelection?.localizedName ?? "No Camera Selection")")
                        #if !targetEnvironment(macCatalyst)
                        Image(systemName: "chevron.up.chevron.down")
                        #endif
                    }

                }
                .disabled(allCameraChoices.isEmpty)
                .pickerStyle(.menu)
                .padding(.leading, 10)
            }
            
            StitchCaptionView("Set the main camera used throughout your projects.")
        }
    }

    @MainActor
    var themePicker: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text("Theme").fontWeight(.bold)
                Menu {
                    ForEach(Array(StitchTheme.allCases), id: \.self) { (choice: StitchTheme) in
                        Button(choice.rawValue) {
                            StitchStore.appThemeChanged(newTheme: choice)
                        }
                    } // ForEach
                } label: {
                    HStack {
                        Text(self.theme.rawValue)
                        #if !targetEnvironment(macCatalyst)
                        Image(systemName: "chevron.up.chevron.down")
                        #endif
                    }
                }
                .padding(.leading, 10)
            } // HStack
            StitchCaptionView("Set the theme used throughout the app.")
        } // VStack
    }

    @MainActor
    var edgeStylePicker: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text("Edge Style").fontWeight(.bold)
                Menu {
                    ForEach(Array(EdgeStyle.allCases), id: \.self) { (choice: EdgeStyle) in
                        Button(choice.rawValue) {
                            StitchStore.appEdgeStyleChanged(newEdgeStyle: choice)
                        }
                    } // ForEach
                } label: {
                    HStack {
                        Text(self.edgeStyle.rawValue)
                        #if !targetEnvironment(macCatalyst)
                        Image(systemName: "chevron.up.chevron.down")
                        #endif
                    }
                }
                .padding(.leading, 10)
            } // HStack
            StitchCaptionView("Set the edge style used throughout the app.")
        } // VStack
    }

    var defaultPreviewWindowDevicePicker: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text("Default Preview Window Device").fontWeight(.bold)
                PreviewWindowDeviceSelectionView(
                    previewSizeDevice: .init(rawValue: defaultPreviewWindowDevice)!,
                    isForProject: false)
            }
            StitchCaptionView("Set the default preview window device for new projects.")
        }
    }

    @ViewBuilder
    var isOptionRequiredForShortcutsPicker: some View {
        let isRequired = self.isOptionRequiredForShortcuts
        
        self.checkboxView(title: "Require Option Key for Shortcuts",
                          caption: "If true, `Option + O`, rather than just `O`, adds an Option Picker to the canvas.",
                          wasChecked: isRequired) { isChecked in
            dispatch(CanShareAIData(newValue: isChecked))
        }
    }
    
    @ViewBuilder
    var canShareAIRetriesPicker: some View {
        logInView("AppSettingsView: canShareAIRetriesPicker: self.canShareAIRetries: \(self.canShareAIData)")
                
        VStack(alignment: .leading) {
            self.checkboxView(title: "Share AI Usage Data",
                              caption: "Sharing your AI requests to Stitch helps improve our AI.",
                              wasChecked: self.canShareAIData ?? true) { isChecked in
                dispatch(CanShareAIData(newValue: isChecked))
            }
            
            Text("Data we collect.")
                .foregroundColor(theme.themeData.edgeColor)
                .onTapGesture {
                    self.showDataCollectionPopover = true
                }
                .popover(isPresented: $showDataCollectionPopover) {
                    StitchDocsPopoverView(router: .overview(.dataCollection))
                }
        }
    }
    
    var experimentalJsNodeCheckbox: some View {
        self.checkboxView(title: "AI Node",
                          caption: "A node that's created using natural language and runs JavaScript code underneath the hood.",
                          wasChecked: self.enabledJsNode) { isChecked in
            self.enabledJsNode = isChecked
        }
    }
    
    var experimentalNodeSummariesCheckbox: some View {
        self.checkboxView(title: "Node Summaries",
                          caption: "Displays a summary of a selection of nodes. Accessed by right-clicking a multi-selection of nodes.",
                          wasChecked: self.enabledNodeSummaries) { isChecked in
            self.enabledNodeSummaries = isChecked
        }
    }
    
    func checkboxView(title: String,
                      caption: String,
                      wasChecked: Bool,
                      isTappedCallback: @escaping (Bool) -> ()) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text(title).fontWeight(.bold)
    
                let icon: String = wasChecked ? "checkmark.square" : "square"
                Image(systemName: icon)
                    .onTapGesture {
                        let isNowChecked = !wasChecked
                        isTappedCallback(isNowChecked)
                    }
            }
            .padding(.bottom, 2)
            
            StitchCaptionView(caption)
        }
    }
            
    func getCameraSelection(cameraID: String?) -> AVCaptureDevicePickerOption? {
        guard let cameraID = cameraID,
              cameraID != BUILT_IN_CAM_LABEL else {
            return AVCaptureDevice.getDefaultCamera()?.pickerOption
        }

        return discoverExternalCameraDevices()
            .first { $0.uniqueID == cameraID }?
            .pickerOption
    }
}

struct AppSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppSettingsView()
    }
}

extension StitchStore {
    static var canShareAIData: Bool {
        (UserDefaults.standard.value(forKey: StitchAppSettings.CAN_SHARE_AI_DATA.rawValue) as? Bool) ?? false
    }
    
    static var enabledJsNode: Bool {
        UserDefaults.standard.value(forKey: StitchAppSettings.EXPERIMENTAL_JS_NODE.rawValue) as? Bool ?? false
    }
    
    static var enabledNodeSummaries: Bool {
        UserDefaults.standard.value(forKey: StitchAppSettings.EXPERIMENTAL_NODE_SUMMARIES.rawValue) as? Bool ?? false
    }
}
