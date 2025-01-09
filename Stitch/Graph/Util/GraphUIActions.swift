//
//  GraphUIActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit

let MIN_GRAPH_SCALE: CGFloat = 0.1

let MAX_GRAPH_SCALE: CGFloat = 2.8

struct SetSidebarWidth: GraphUIEvent {
    
    let frame: CGRect // .global frame
    
    func handle(state: GraphUIState) {
        // log("SetSidebarWidth: frame.origin.x: \(frame.origin.x)")
        state.sidebarWidth = frame.origin.x
    }
}

struct SetDeviceScreenSize: GraphEvent {

    let frame: CGRect

    func handle(state: GraphState) {
        // Set frame of view
        //        log("SetDeviceScreenSize: frame: \(frame)")
        //        log("SetDeviceScreenSize: graphState.graphUI.frame was: \(graphState.graphUI.frame)")

        state.graphUI.frame = frame
        //        log("SetDeviceScreenSize: graphState.graphUI.frame is now: \(graphState.graphUI.frame)")
    }
}

struct SetGraphYPosition: GraphUIEvent {
    let graphYPosition: CGFloat
    
    func handle(state: GraphUIState) {
        state.graphYPosition = graphYPosition
    }
}

struct ColorSchemeReceived: GraphUIEvent {
    let colorScheme: ColorScheme

    func handle(state: GraphUIState) {
        //        log("ColorSchemeReceived: colorScheme: \(colorScheme)")
        state.colorScheme = colorScheme
    }
}

struct SafeAreaInsetsReceived: GraphUIEvent {
    let insets: SafeAreaInsets

    func handle(state: GraphUIState) {
        //        log("SafeAreaInsetsReceived: insets: \(insets)")
        state.safeAreaInsets = insets
    }
}

struct GroupNodeDoubleTapped: GraphEvent {

    let id: NodeId

    func handle(state: GraphState) {

        log("GroupNodeDoubleTapped: id: \(id)")

        // De-select any nodes once new parent is shown
        state.resetAlertAndSelectionState()
        
        guard let groupNodeType = state.getGroupNodeType(for: id) else {
            return
        }

        state.graphUI.groupNodeBreadcrumbs.append(groupNodeType)

        // Animate to child
        state.graphUI.groupTraversedToChild = true

        // reset any active selections
        state.resetAlertAndSelectionState()
    }
}

extension GraphState {
    @MainActor
    func getGroupNodeType(for nodeId: NodeId) -> GroupNodeType? {
        guard let node = self.getNodeViewModel(nodeId) else {
            fatalErrorIfDebug()
            return nil
        }
        
        switch node.nodeType {
        case .group:
            return .groupNode(nodeId)
        case .component:
            return .component(nodeId)
        default:
            fatalErrorIfDebug()
            return nil
        }
    }
}

// When we enter fullscreen preview window mode, we save which nodes were on-screen, and set those visible again when we exit fullscreen preview window mode.
struct ToggleFullScreenEvent: GraphEvent {
    func handle(state: GraphState) {
        state.graphUI.isFullScreenMode.toggle()
                
        if state.graphUI.isFullScreenMode {
            // Ports should not update while in fullscreen mode
            state.visibleNodesViewModel.visibleCanvasIds = .init()
        }  else {
            // Mark all nodes as visible, will correct later
            state.visibleNodesViewModel.setAllNodesVisible()
        }
    }
}

struct TogglePreviewWindow: GraphUIEvent {
    func handle(state: GraphUIState) {
        state.showPreviewWindow.toggle()
    }
}

struct ToggleSidebars: GraphEvent {
    func handle(state: GraphState) {
        // Opens both if both are already closed;
        // else closes both.
        let inspectorOpen = state.graphUI.showsLayerInspector
        let layerSidebarOpen = state.graphUI.leftSidebarOpen
        
        withAnimation {
            if !inspectorOpen && !layerSidebarOpen {
                state.graphUI.showsLayerInspector = true
                state.graphUI.leftSidebarOpen = true
            } else {
                state.graphUI.showsLayerInspector = false
                state.graphUI.leftSidebarOpen = false
            }
        }
    }
}

struct InsertNodeSelectionChanged: GraphUIEvent {
    let selection: InsertNodeMenuOptionData

    func handle(state: GraphUIState) {
        state.insertNodeMenuState.activeSelection = selection
    }
}

/// Process search results in the insert node menu sheet
struct GenerateAINode: GraphEvent {
    let prompt: String
    
    func handle(state: GraphState) {
        print("DEBUG - Handling AI node generation with prompt: \(prompt)")
        // Set loading state
        state.graphUI.insertNodeMenuState.isGeneratingAINode = true
        // Dispatch OpenAI request
        dispatch(MakeOpenAIRequest(prompt: prompt))
    }
}

struct AINodeGenerationComplete: GraphEvent {
    func handle(state: GraphState) {
        state.graphUI.insertNodeMenuState.isGeneratingAINode = false
        state.graphUI.insertNodeMenuState.show = false
    }
}

/// Process search results in the insert node menu sheet
struct InsertNodeQuery: GraphEvent {
    let query: String
    
    func handle(state: GraphState) {
        // Update the search query in menu state
        state.graphUI.insertNodeMenuState.searchQuery = query
        
        // Update search results
        if query.isEmpty {
            state.graphUI.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions
            state.graphUI.insertNodeMenuState.activeSelection = InsertNodeMenuState.startingActiveSelection
        } else {
            let filtered = searchForNodes(by: query,
                                           searchOptions: InsertNodeMenuState.allSearchOptions)
            
            state.graphUI.insertNodeMenuState.searchResults = filtered
            
            // Update selection based on search results
            if !filtered.isEmpty {
                state.graphUI.insertNodeMenuState.activeSelection = filtered.first
            } else {
                // We're in AI mode - clear selection
                state.graphUI.insertNodeMenuState.activeSelection = nil
            }
        }
    }
}

extension [InsertNodeMenuOptionData] {
    static let ALL_NODE_SEARCH_OPTIONS = InsertNodeMenuState.allSearchOptions
}

func searchForNodes(by query: String,
                    searchOptions: [InsertNodeMenuOptionData]) -> [InsertNodeMenuOptionData] {

    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedQuery.isEmpty else {
        return searchOptions
    }

    // First collect all matching nodes
    var filtered = searchOptions.filter {
        $0.data.displayTitle.localizedCaseInsensitiveContains(trimmedQuery) ||
        $0.data.displayDescription.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "/", with: "")
            .localizedCaseInsensitiveContains(trimmedQuery)
    }

    // Sort with priority for exact boolean operation matches
    filtered.sort { first, second in
        let firstTitle = first.data.displayTitle.lowercased()
        let secondTitle = second.data.displayTitle.lowercased()
        let lowercaseQuery = trimmedQuery.lowercased()

        // Give priority to exact boolean operation matches
        if firstTitle == lowercaseQuery && ["and", "or", "not"].contains(lowercaseQuery) {
            return true
        }
        if secondTitle == lowercaseQuery && ["and", "or", "not"].contains(lowercaseQuery) {
            return false
        }

        // For all other cases, sort alphabetically
        return firstTitle < secondTitle
    }

    // math symbols
    if trimmedQuery == "+" {
        filtered.append(.init(data: .patch(.add)))
    }
    if trimmedQuery == "-" {
        filtered.append(.init(data: .patch(.subtract)))
    }
    if trimmedQuery == "/" {
        filtered.append(.init(data: .patch(.divide)))
    }
    if trimmedQuery == "*" {
        filtered.append(.init(data: .patch(.multiply)))
    }
    if trimmedQuery == "**" || trimmedQuery == "^" {
        filtered.append(.init(data: .patch(.power)))
    }

    // equality operators
    if trimmedQuery == "=" {
        filtered.append(.init(data: .patch(.equals)))
        filtered.append(.init(data: .patch(.equalsExactly)))
        filtered.append(.init(data: .patch(.optionEquals)))
        filtered.append(.init(data: .patch(.greaterOrEqual)))
        filtered.append(.init(data: .patch(.lessThanOrEqual)))
    }
    if trimmedQuery == ">" {
        filtered.append(.init(data: .patch(.greaterThan)))
        filtered.append(.init(data: .patch(.greaterOrEqual)))
    }
    if trimmedQuery == ">=" {
        filtered.append(.init(data: .patch(.greaterOrEqual)))
    }
    if trimmedQuery == "<" {
        filtered.append(.init(data: .patch(.lessThan)))
        filtered.append(.init(data: .patch(.lessThanOrEqual)))
    }
    if trimmedQuery == "<=" {
        filtered.append(.init(data: .patch(.lessThanOrEqual)))
    }

    // logical operators
    if trimmedQuery == "!" {
        filtered.append(.init(data: .patch(.not)))
    }
    if trimmedQuery == "%" {
        filtered.append(.init(data: .patch(.mod)))
    }
    if trimmedQuery == "&" || trimmedQuery == "&&" {
        filtered.append(.init(data: .patch(.and)))
    }
    if trimmedQuery == "|" || trimmedQuery == "||" {
        filtered.append(.init(data: .patch(.or)))
    }

    // splitter == value node
    if "splitter".hasPrefix(trimmedQuery.lowercased()) {
        let splitterOption = InsertNodeMenuOptionData(data: .patch(.splitter))
        filtered.append(splitterOption)
    }
    
    return filtered
}

struct ActiveIndexChangedAction: GraphEvent {
    let index: ActiveIndex

    func handle(state: GraphState) {
        state.graphUI.activeIndex = index
        
        // Note: previously this logic was handled in the view (`NodeInputOutputView`);
        // the advantage was that only actively-rendered
        state.getVisibleNodes().forEach { node in
            node.updatePortViewModels()
        }
    }
}

struct InsertNodeQuery_REPL: View {

    let query: String = "a"

    var results: [InsertNodeMenuOptionData] {
        searchForNodes(by: query,
                       searchOptions: .ALL_NODE_SEARCH_OPTIONS)
    }

    var body: some View {
        ForEach(results, id: \.id) {
            Text($0.data.displayTitle)
        }
    }
}

#Preview {
    InsertNodeQuery_REPL()
        .scaleEffect(4)
}
