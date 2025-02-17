//
//  GraphUIActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit
import OrderedCollections

let MIN_GRAPH_SCALE: CGFloat = 0.1 // most zoomed out

let MAX_GRAPH_SCALE: CGFloat = 2.8 // most zoomed in

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
        // log("SetDeviceScreenSize: frame: \(frame)")
        // log("SetDeviceScreenSize: state.graphUI.frame was: \(state.graphUI.frame)")

        state.graphUI.frame = frame
        // log("SetDeviceScreenSize: state.graphUI.frame is now: \(state.graphUI.frame)")
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
struct GenerateAINode: StitchDocumentEvent {
    let prompt: String
    
    func handle(state: StitchDocumentViewModel) {
        print("🤖 🔥 GENERATE AI NODE - STARTING AI GENERATION MODE 🔥 🤖")
        print("🤖 Prompt: \(prompt)")
        
        assertInDebug(state.aiManager?.secrets != nil)
        
        // Set loading state
        state.graph.graphUI.insertNodeMenuState.isGeneratingAINode = true
        
        // Set flag to indicate this is from AI generation
        state.graph.graphUI.insertNodeMenuState.isFromAIGeneration = true
        
        print("🤖 isFromAIGeneration set to: \(state.graph.graphUI.insertNodeMenuState.isFromAIGeneration)")
        
        // Dispatch OpenAI request
        do {
            let request = try OpenAIRequest(prompt: prompt)
            state.aiManager?.handleRequest(request)
        } catch {
            fatalErrorIfDebug("Unable to generate Stitch AI prompt with error: \(error.localizedDescription)")
        }
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

    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard !trimmedQuery.isEmpty else {
        return searchOptions
    }

    // Check for "when prototype" sequence first
    // This needs to handle partial typing of the entire sequence
    if trimmedQuery.hasPrefix("when") {
        let targetPhrase = "when prototype start"
        if targetPhrase.hasPrefix(trimmedQuery) {
            // If what they typed is the start of our target phrase, show the node
            if let prototypeStartNode = searchOptions.first(where: {
                $0.data.displayTitle.lowercased().contains("on prototype start")
            }) {
                return [prototypeStartNode]
            }
        }
    }
    
    if trimmedQuery.hasPrefix("text") {
        let targetPhrase = "text split"
        if targetPhrase.hasPrefix(trimmedQuery) {
            // If what they typed is the start of our target phrase, show the node
            if let splitTextNode = searchOptions.first(where: {
                $0.data.displayTitle.lowercased().contains("split text")
            }) {
                return [splitTextNode]
            }
        }
    }

    // Handle exact symbol matches next
    switch trimmedQuery {
    case "+": return [.init(data: .patch(.add))]
    case "-": return [.init(data: .patch(.subtract))]
    case "*": return [.init(data: .patch(.multiply))]
    case "/": return [.init(data: .patch(.divide))]
    case "**", "^": return [.init(data: .patch(.power))]
    default: break
    }
    
    // Split results into title matches and description matches
    let titleMatches = searchOptions.filter { option in
        option.data.displayTitle.localizedCaseInsensitiveContains(trimmedQuery)
    }
    
    let descriptionMatches = searchOptions.filter { option in
        option.data.displayDescription
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "/", with: "")
            .localizedCaseInsensitiveContains(trimmedQuery)
    }
    
    // Using OrderedSet to handle duplicates
    var results = OrderedSet(titleMatches + descriptionMatches)

    // Check for text-based matches for remaining items
    let textBasedMatches = searchOptions.filter { option in
        guard !results.contains(option) else { return false }
        
        if case .patch(let patchData) = option.data {
            switch patchData {
            case .add: return "add".hasPrefix(trimmedQuery) || "plus".hasPrefix(trimmedQuery)
            case .subtract: return "subtract".hasPrefix(trimmedQuery) || "minus".hasPrefix(trimmedQuery)
            case .multiply: return "multiply".hasPrefix(trimmedQuery) || "times".hasPrefix(trimmedQuery)
            case .divide: return "divide".hasPrefix(trimmedQuery)
            case .power: return "power".hasPrefix(trimmedQuery) || "exponent".hasPrefix(trimmedQuery)
            case .splitter: return "value".hasPrefix(trimmedQuery) || "splitter".hasPrefix(trimmedQuery)
            default: return false
            }
        }
        return false
    }
    
    results.append(contentsOf: textBasedMatches)
    
    // Sort items within their respective groups (title matches and description matches)
    return results.sorted { first, second in
        // First prioritize type of match (title vs description)
        let firstInTitleMatches = titleMatches.contains(first)
        let secondInTitleMatches = titleMatches.contains(second)
        if firstInTitleMatches != secondInTitleMatches {
            return firstInTitleMatches
        }
        
        let firstTitle = first.data.displayTitle.lowercased()
        let secondTitle = second.data.displayTitle.lowercased()

        // Then exact matches
        if firstTitle == trimmedQuery { return true }
        if secondTitle == trimmedQuery { return false }

        // Then prefix matches
        let firstStartsWithQuery = firstTitle.hasPrefix(trimmedQuery)
        let secondStartsWithQuery = secondTitle.hasPrefix(trimmedQuery)
        if firstStartsWithQuery != secondStartsWithQuery { return firstStartsWithQuery }

        // Finally alphabetical
        return firstTitle < secondTitle
    }
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
