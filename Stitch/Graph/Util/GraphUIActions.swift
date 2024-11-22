//
//  GraphUIActions.swift
//  prototype
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit

let MIN_GRAPH_SCALE: CGFloat = 0.1

let MAX_GRAPH_SCALE: CGFloat = 2.8

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

    let id: GroupNodeId

    func handle(state: GraphState) {

        log("GroupNodeDoubleTapped: id: \(id)")

        guard let crumb = state.getGroupNodeBreadcrumb(id: id) else {
            log("GroupNodeDoubleTapped: could not find group node \(id)")
            return
        }
        
        state.graphUI.groupNodeFocused = id

        // De-select any nodes once new parent is shown
        state.resetAlertAndSelectionState()

        state.graphUI.groupNodeBreadcrumbs.append(crumb)

        // Animate to child
        state.graphUI.groupTraversedToChild = true

        // reset any active selections
        state.resetAlertAndSelectionState()
    }
}

// When we enter fullscreen preview window mode, we save which nodes were on-screen, and set those visible again when we exit fullscreen preview window mode.
struct ToggleFullScreenEvent: GraphEvent {
    func handle(state: GraphState) {
        state.graphUI.isFullScreenMode.toggle()
                
        if state.graphUI.isFullScreenMode {
            // Ports should not update while in fullscreen mode
            state.visibleNodesViewModel.getCanvasItems().forEach { node in
                if node.isVisibleInFrame {
                    state.graphUI.nodesThatWereOnScreenPriorToEnteringFullScreen.insert(node.id)
                    node.isVisibleInFrame = false
                }
            }
        }  else {
            state.graphUI.nodesThatWereOnScreenPriorToEnteringFullScreen.forEach { nodeId in
                state.getCanvasItem(nodeId)?.isVisibleInFrame = true
            }
            state.graphUI.nodesThatWereOnScreenPriorToEnteringFullScreen = .init()
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
        
        if !inspectorOpen && !layerSidebarOpen {
            state.graphUI.showsLayerInspector = true
            state.graphUI.leftSidebarOpen = true
        } else {
            state.graphUI.showsLayerInspector = false
            state.graphUI.leftSidebarOpen = false
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
struct InsertNodeQuery: GraphUIEvent {
    let query: String

    func handle(state: GraphUIState) {
        let results = searchForNodes(by: query,
                                     searchOptions: .ALL_NODE_SEARCH_OPTIONS)

        // Update results and the current selection
        state.insertNodeMenuState.searchResults = results
        state.insertNodeMenuState.activeSelection = results.first
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

    let titleMatches = searchOptions.filter {
        $0.data.displayTitle.localizedCaseInsensitiveContains(trimmedQuery)
    }

    let descriptionMatches = searchOptions.filter {
        !$0.data.displayTitle.localizedCaseInsensitiveContains(trimmedQuery) &&
            $0.data.displayDescription.replacingOccurrences(of: "*", with: "")
                                         .replacingOccurrences(of: "/", with: "")
                                         .localizedCaseInsensitiveContains(trimmedQuery)
    }

    var filtered = titleMatches + descriptionMatches

    // Also check for:
    // Sort to prioritize exact matches first
    filtered.sort { first, second in
        let firstTitle = first.data.displayTitle.lowercased()
        let secondTitle = second.data.displayTitle.lowercased()

        // Check if either title starts with the query
        let firstStartsWithQuery = firstTitle.hasPrefix(trimmedQuery.lowercased())
        let secondStartsWithQuery = secondTitle.hasPrefix(trimmedQuery.lowercased())

        // Sort by whether they start with the query
        if firstStartsWithQuery && !secondStartsWithQuery {
            return true
        } else if !firstStartsWithQuery && secondStartsWithQuery {
            return false
        }

        // If both or neither start with the query, sort alphabetically
        return firstTitle < secondTitle
    }

    // math symbols
    // Also check for math symbols and logical operators
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
        state.getVisibleNodes().forEach { (node: any NodeDelegate) in
            node.updateInputPortViewModels(activeIndex: index)
            node.updateOutputPortViewModels(activeIndex: index)
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
