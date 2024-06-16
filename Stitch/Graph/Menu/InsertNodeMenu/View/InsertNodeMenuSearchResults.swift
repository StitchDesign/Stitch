//
//  InsertNodeMenuSearchResults.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

struct InsertNodeMenuSearchResults: View {

    @Environment(\.appTheme) var theme

    // All the nodes and components (default or custom) that met the entered search criteria
    let searchResults: [InsertNodeMenuOptionData]

    let activeSelection: InsertNodeMenuOptionData?

    // Updated by bottomFooter's FooterSizeReader
    @Binding var footerRect: CGRect

    let show: Bool
    
    let animatingNodeOpacity: CGFloat

    @State var nodeResultSizes: [UUID: CGRect] = .init()

    @State var localId = UUID()
    
    // TODO: iterate through DefaultComponents enum
    var defaultComponents: [InsertNodeMenuOptionData] {
        searchResults.defaultComponents
    }

    var customComponents: [InsertNodeMenuOptionData] {
        searchResults.customComponents
    }

    var nodes: [InsertNodeMenuOptionData] {
        searchResults.nodes
    }

    var body: some View {

        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    
                    if !nodes.isEmpty {
                        Section {
                            ForEach(nodes, id: \.self) {

                                let isLast = $0.id == nodes.last?.id

                                searchResultButton($0)
                                    .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_WIDTH,
                                           height: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_HEIGHT)
                                    // Must apply padding on last item,
                                    // else we lose `.ultraThinMaterial` effect
                                    .padding(.bottom, isLast ? INSERT_NODE_MENU_SCROLL_LIST_BOTTOM_PADDING : 0)
                                    .background(InsertNodeResultSizeReader(
                                                    id: $0.id,
                                                    title: $0.data.displayTitle,
                                                    nodeResultSizes: self.$nodeResultSizes))
                            }
                        } header: {
                            EmptyView()
                        } // Section

                    } // if !nodes.isEmpty

                } // LazyVStack
            } // ScrollView
            
            // Note: seems like best way to reset scrollview's position upon re-open, while also avoiding unintended animations etc.
            .id(self.localId)
            
            
            // Note: If current selection is below the frosted footer,
            // then use scrollProxy.scrollTo such that the current selection ends up
            // just above the footer.
            .onChange(of: activeSelection, initial: true) { _, newActiveSelection in
                
                // Note: using guard statements for easier debugging
                guard let newActiveSelection: InsertNodeMenuOptionData = newActiveSelection else {
                    // log("InsertNodeMenuSearchResults: no active selection")
                    return
                }
                
                guard let bounds = self.nodeResultSizes[newActiveSelection.id] else {
                    // log("InsertNodeMenuSearchResults: no bounds for selection \(newActiveSelection.data.displayTitle), will default to regular proxy.scrollTo")
                    proxy.scrollTo(newActiveSelection.id)
                    return
                }
                
                guard self.footerRect.intersects(bounds) else {
                    // log("InsertNodeMenuSearchResults: no intersection for footerRect \(footerRect) and bounds \(bounds) of selection \(newActiveSelection.data.displayTitle), will default to regular proxy.scrollTo")
                    proxy.scrollTo(newActiveSelection.id)
                    return
                }
                
                // log("InsertNodeMenuSearchResults: special API: had intersection for footerRect \(footerRect) and bounds \(bounds) of selection \(newActiveSelection.data.displayTitle)")
                
                proxy.scrollTo(newActiveSelection.id,
                               anchor: .init(x: 0, y: 0.775))
                
            } // .onChange(of: activeSelection) { ... }

        } // ScrollViewReader
        // Hide the list if no search results, so that we don't show headers etc.
        .opacity(searchResults.isEmpty ? 0 : 1)
        .onChange(of: self.show) { oldValue, newValue in
            self.localId = .init()
        }
    }

    var selectionColor: Color {
        theme.themeData.edgeColor.opacity(1 - animatingNodeOpacity)
    }

    @MainActor
    func searchResultButton(_ option: InsertNodeMenuOptionData) -> some View {
        VStack(spacing: 0) {

            StitchButton(action: {
                dispatch(InsertNodeSelectionChanged(selection: option))
            }, label: {
                HStack {
                    StitchTextView(string: option.data.displayTitle)
                        .fontWeight(.light)
                        .offset(x: 8)
                    Spacer()
                }
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(option.data == activeSelection?.data ? selectionColor : Color.clear)
                        .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_WIDTH,
                               height: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_HEIGHT)
                }
            })
        }
        .id(option.id) // required for proxy.scrollTo
    }
}
