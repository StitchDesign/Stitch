//
//  StitchRootView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/15/23.
//

import SwiftUI
import StitchSchemaKit

extension CGFloat {
#if DEV_DEBUG
    static let STITCH_APP_WINDOW_MINIMUM_WIDTH: CGFloat = 400
    static let STITCH_APP_WINDOW_MINIMUM_HEIGHT: CGFloat = 200
#else
    static let STITCH_APP_WINDOW_MINIMUM_WIDTH: CGFloat = 800
    static let STITCH_APP_WINDOW_MINIMUM_HEIGHT: CGFloat = 600
#endif
}

struct StitchRootView: View {
    @Environment(StitchFileManager.self) var fileManager
    
    @Bindable var store: StitchStore
    
    @AppStorage(SAVED_APP_THEME_KEY_NAME) private var savedAppTheme: String = StitchTheme.defaultTheme.rawValue
    
    @AppStorage(SAVED_EDGE_STYLE_KEY_NAME) private var savedEdgeStyle: String = EdgeStyle.defaultEdgeStyle.rawValue
    
    @MainActor
    var alertState: ProjectAlertState {
        self.store.alertState
    }
    
    var isShowingDrawer: Bool {
        self.store.isShowingDrawer
    }
    
    var theme: StitchTheme {
        self.store.appTheme
    }
    
    var edgeStyle: EdgeStyle {
        self.store.edgeStyle
    }
    
    // "Is NavigationSplitView's sidebar open or not?"
    // Handled manually by user; but synced with StitchDocumentViewModel.leftSide
    @State var columnVisibility: NavigationSplitViewVisibility = .detailOnly
            
    var showMenu: Bool {
         guard let document = store.currentDocument else {
             return false
         }

         return document.insertNodeMenuState.show
     }
            
//    @State var rootViewFrame: CGRect? = nil
        
    var body: some View {
        
        // MARK: HStack still distorts ReplayKit; VStack doesn't but messes up top bar
//        HStack(spacing: 0) { // distorts ReplayKit
        VStack(spacing: 0) { // no ReplayKit distortion, but top bar buttons mess up
//        ZStack { // distorts ReplayKit
            
            if Stitch.isPhoneDevice {
                iPhoneBody
            } else {
                splitView
                    .overlay(alignment: .center) {
                        if let document = store.currentDocument, showMenu {
                            InsertNodeMenuWrapper(document: document)
                        } // if let document
                    } // .overlay
                
//                    .background {
//                        RecordingView(shouldRecord: store.shouldRecord)
//                    }
            }
     
            
            // Can't .overlay this, nor use ZStack, nor HStack
//            RecordingView(recorder: store.recorder)
//            RecordingView()
//            Rectangle().fill(.clear).frame(width: 1, height: 1)
            
        } // ZStack
        
        // MARK: attempting to use .background to place the ReplayKit without  avoid avoids distortion in ReplayKit video, but messes up top bar buttons
        
//        .overlay(alignment: .center) {
//            Button("Toggle Recording") {
//                store.shouldRecord.toggle()
//            }
//        }
//        .background {
//            RecordingView(shouldRecord: store.shouldRecord)
//        }
        
        // MARK: reading StitchRootView window size
        
//        .background {
//            GeometryReader { geometry in
//                Color.clear.onChange(of: geometry.frame(in: .global), initial: true) { oldValue, newValue in
//                    log("StitchRootView: oldValue.size: \(oldValue.size)")
//                    log("StitchRootView: oldValue.origin: \(oldValue.origin)")
//                    log("StitchRootView: newValue.size: \(newValue.size)")
//                    log("StitchRootView: newValue.origin: \(newValue.origin)")
//                    self.rootViewFrame = newValue
//                    self.frameSizeId = .init()
//                }
//            }
//        }

        .modifier(StitchRootModifier())
        .onAppear {
            // TODO: move this to the start of StitchStore instead?
            //            dispatch(ImportDefaultComponents())
            
            hideTitleAndSetMinimumWindowSize()
            
            dispatch(AppThemeChangedEvent(newTheme: .init(rawValue: savedAppTheme) ?? .defaultTheme))
            
            dispatch(AppEdgeStyleChangedEvent(newEdgeStyle: .init(rawValue: savedEdgeStyle) ?? .defaultEdgeStyle))
            
        }
        .onChange(of: self.columnVisibility, initial: true) { oldValue, newValue in
            let fn = { (open: Bool) in dispatch(LeftSidebarSet(open: open)) }
            
            switch newValue {
            case .all:
                fn(true)
            case .detailOnly:
                fn(false)
            case .doubleColumn:
                fn(true)
            // When and how can this case happen?
            case .automatic:
                fn(false)
            default:
                fn(false)
            }
        }
        .onChange(of: self.store.currentDocument?.leftSidebarOpen ?? false) { oldValue, newValue in
            if newValue {
                self.columnVisibility = .doubleColumn
            } else {
                self.columnVisibility = .detailOnly
            }
                
        }
        .environment(\.appTheme, theme)
        .environment(\.edgeStyle, edgeStyle)
    }
    
    @MainActor
    func hideTitleAndSetMinimumWindowSize() {
#if targetEnvironment(macCatalyst)
        if let windowScene = (UIApplication.shared.connectedScenes.first as? UIWindowScene) {
            windowScene.titlebar?.titleVisibility = .hidden
            windowScene.titlebar?.toolbarStyle = .unified
            
            // MARK: avoids distortion in ReplayKit video, but messes up top bar buttons
//            windowScene.windows.first?.rootViewController?.view.bounds.size = CGSize(width: 1024, height: 768)
            
//            windowScene.sizeRestrictions?.minimumSize = .init(
//                width: .STITCH_APP_WINDOW_MINIMUM_WIDTH,
//                height: .STITCH_APP_WINDOW_MINIMUM_HEIGHT)
        } else {
            fatalErrorIfDebug("StitchRootView: unable to retrieve UIWindowScene")
        }
#endif
    }
    
    var iPhoneBody: some View {
        
        // `NavigationSplitView` does not respect `NavigationSplitViewVisibility.detailOnly` on iPhone;
        // but since we show neither components- nor layers-sidebars on iPhone,
        // we don't need to use `NavigationSplitView`.
        StitchNavStack(store: store)
    }

    // MARK: reading document's frame
//    var frameSize: CGSize? {
//        if let doc = store.currentDocument {
//            return doc.frame.size
//        } else {
//            return nil
//        }
//    }
    
    @MainActor
    var splitView: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                topLevelSidebar
                
                // MARK: attempting to place the recording view; ReplayKit video still gets distorted
//                RecordingView()
                
                // Needed on Catalyst to prevent sidebar button from sliding into traffic light buttons
                
                // MARK: what we do on `development`, but removed for testing purposes here; ReplayKit video still gets distorted
//#if targetEnvironment(macCatalysYt)
//                    .toolbar(.hidden)
//#endif
            },
            // Apple's 'detail view' = the view to the right of the sidebar
            detail: {
                // The NavigationStack which switches between
                // Projects Home View <-> some Loaded Project;
                // gives us proper back button etc.
                StitchNavStack(store: store)
                     .coordinateSpace(name: Self.STITCH_ROOT_VIEW_COORDINATE_SPACE)
            })
        
        
        // MARK: avoids distortion in ReplayKit video, but messes up top bar buttons
//        .frame(minWidth: 1024, idealWidth: 1024, maxWidth: 1024, minHeight: 768, idealHeight: 768, maxHeight: 768)
        
        // MARK: reading StitchRootView's GeometryReader size; causes error with ReplayKit's startRecording
//        .frame(minWidth: store.recorder.isRecording ? 1024 : nil,
//               idealWidth: store.recorder.isRecording ? 1024 : nil,
//               maxWidth: store.recorder.isRecording ? 1024 : nil,
//               minHeight: store.recorder.isRecording ? 768 : nil,
//               idealHeight: store.recorder.isRecording ? 768 : nil,
//               maxHeight: store.recorder.isRecording ? 768 : nil)

        // MARK: reading StitchRootView's GeometryReader size; causes error with ReplayKit's startRecording
//        .frame(minWidth: self.rootViewFrame?.size.width,
//               idealWidth: self.rootViewFrame?.size.width,
//               maxWidth: self.rootViewFrame?.size.width,
//               minHeight: self.rootViewFrame?.size.height,
//               idealHeight: self.rootViewFrame?.size.height,
//               maxHeight: self.rootViewFrame?.size.height)
//
        // MARK: reading frame from current document
//        .frame(minWidth: self.frameSize?.width,
//               idealWidth: self.frameSize?.width,
//               maxWidth: self.frameSize?.width,
//               minHeight: self.frameSize?.height,
//               idealHeight: self.frameSize?.height,
//               maxHeight: self.frameSize?.height)
        
        
                
        // On iPad's graph view, we use a custom top bar, and so do not have the native bar's sidebar-icon for opening or closing sidebar;
        // instead we listen to redux state.
#if !targetEnvironment(macCatalyst)
        .onChange(of: isShowingDrawer) { newValue in
            columnVisibility = newValue ? .all : .detailOnly
        }
        .onChange(of: self.store.currentDocument.isDefined) { isProjectOpened in
            // If we close graph while sidebar is open,
            // we need to also close sidebar
            // since otherwise the native nav bar's sidebar icon can get lost.
            // (Finicky.)
            if !isProjectOpened {
                columnVisibility = .detailOnly
            }
        }
#endif
        
        // Update Redux when drawer state changes
        .onChange(of: self.columnVisibility) { _, newColumnVisibility in
            switch newColumnVisibility {
            case .all, .doubleColumn:
                dispatch(ShowDrawer())
            case .automatic, .detailOnly:
                dispatch(HideDrawer())
            default:
                dispatch(HideDrawer())
            }
        }
    }
    
    static let STITCH_ROOT_VIEW_COORDINATE_SPACE = "STITCH_ROOT_VIEW_COORDINATE_SPACE"
    
    // TODO: remove on Catalyst
    @Namespace var topButtonNamespace
    
    @ViewBuilder
    var topLevelSidebar: some View {
        StitchSidebarView(syncStatus: fileManager.syncStatus)
    }
}
