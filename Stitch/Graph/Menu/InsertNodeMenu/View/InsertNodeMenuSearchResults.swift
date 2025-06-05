//
//  InsertNodeMenuSearchResults.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import StitchSchemaKit

struct InsertNodeMenuSearchResults: View {

    @State private var nodeResultSizes: [InsertNodeMenuOption: CGRect] = .init()
    @State private var localId = UUID()

    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme

    // All the nodes and components (default or custom) that met the entered search criteria
    let searchResults: [InsertNodeMenuOption]

    let activeSelection: InsertNodeMenuOption?

    // Updated by bottomFooter's FooterSizeReader
    @Binding var footerRect: CGRect

    let show: Bool
    
    // TODO: iterate through DefaultComponents enum
    var defaultComponents: [InsertNodeMenuOption] {
        searchResults.defaultComponents
    }

    var customComponents: [InsertNodeMenuOption] {
        searchResults.customComponents
    }

    var nodes: [InsertNodeMenuOption] {
        searchResults.nodes
    }

    var body: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    
                    if !nodes.isEmpty {
                        Section {
                            ForEach(nodes) {

                                let isLast = $0.id == nodes.last?.id

                                searchResultButton($0)
                                    .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_WIDTH,
                                           height: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_HEIGHT)
                                    // Must apply padding on last item,
                                    // else we lose `.ultraThinMaterial` effect
                                    .padding(.bottom, isLast ? INSERT_NODE_MENU_SCROLL_LIST_BOTTOM_PADDING : 0)
                                    .background(InsertNodeResultSizeReader(
                                                    option: $0,
                                                    title: $0.displayTitle,
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
                guard let newActiveSelection: InsertNodeMenuOption = newActiveSelection else {
                    // log("InsertNodeMenuSearchResults: no active selection")
                    return
                }
                
                guard let bounds = self.nodeResultSizes[newActiveSelection] else {
                    // log("InsertNodeMenuSearchResults: no bounds for selection \(newActiveSelection.displayTitle), will default to regular proxy.scrollTo")
                    proxy.scrollTo(newActiveSelection.id)
                    return
                }
                
                guard self.footerRect.intersects(bounds) else {
                    // log("InsertNodeMenuSearchResults: no intersection for footerRect \(footerRect) and bounds \(bounds) of selection \(newActiveSelection.displayTitle), will default to regular proxy.scrollTo")
                    proxy.scrollTo(newActiveSelection.id)
                    return
                }
                
                // log("InsertNodeMenuSearchResults: special API: had intersection for footerRect \(footerRect) and bounds \(bounds) of selection \(newActiveSelection.displayTitle)")
                
                proxy.scrollTo(newActiveSelection.id,
                               anchor: .init(x: 0, y: 0.775))
                
            } // .onChange(of: activeSelection) { ... }

        } // ScrollViewReader
        // Hide the list if no search results, so that we don't show headers etc.
        .onChange(of: self.show) { oldValue, newValue in
            self.localId = .init()
        }
    }
    
    var selectionColor: Color {
        theme.themeData.edgeColor
    }

    @MainActor
    func searchResultButton(_ option: InsertNodeMenuOption) -> some View {
        VStack(spacing: 0) {

            StitchButton(action: {
                dispatch(InsertNodeSelectionChanged(selection: option))
            }, label: {
                HStack {
                    StitchTextView(string: option.displayTitle)
                        .fontWeight(.light)
                        .offset(x: 8)
                    Spacer()
                }
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(option == activeSelection ? selectionColor : Color.clear)
                        .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_WIDTH,
                               height: INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_HEIGHT)
                }
            })
        }
        .id(option.id) // required for proxy.scrollTo
    }
}
