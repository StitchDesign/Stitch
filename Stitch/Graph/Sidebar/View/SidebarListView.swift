//
//  _SidebarListView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

// Entire Figma sidebar is 320 pixels wide
let SIDEBAR_WIDTH: CGFloat = 320

let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_SPACING: CGFloat = 4.0

#if targetEnvironment(macCatalyst)
let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT: CGFloat = 20.0
let SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT: CGFloat = 28.0
let SIDEBAR_LIST_ITEM_FONT: Font = STITCH_FONT // 14.53
#else
let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT: CGFloat = 24.0
let SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT: CGFloat = 32.0
let SIDEBAR_LIST_ITEM_FONT: Font = stitchFont(18)
#endif

// TODO: move
enum ProjectSidebarTab: String, Identifiable, CaseIterable {
    case layers = "Layers"
    case assets = "Assets"
}

extension ProjectSidebarTab {
    var id: String {
        self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .layers:
            return "square.3.layers.3d.down.left"
        case .assets:
            return "folder"
        }
    }
    
//    @ViewBuilder @MainActor
//    func content(graph: GraphState,
//                 syncStatus: iCloudSyncStatus) -> some View {
//        switch self {
//        case .layers:
//            LayersSidebarView(graph: graph,
//                              syncStatus: syncStatus)
//        case .assets:
//            Text("Assets")
//        }
//    }
//    
    var viewModelType: any ProjectSidebarObservable.Type {
        switch self {
        case .layers:
            return LayersSidebarViewModel.self
        default:
            fatalError()
        }
    }
}

struct SidebarListView: View {
    static let tabs = ["Layers", "Assets"]
    @State private var currentTab = ProjectSidebarTab.layers.rawValue
//    @Bindable var layersViewModel: LayersSidebarViewModel
    
    @Bindable var graph: GraphState
    let syncStatus: iCloudSyncStatus
    

//    var selections: SidebarSelectionState {
//        graph.sidebarSelectionState
//    }
//    
//    var sidebarListState: SidebarListState {
//        graph.sidebarListState
//    }
    
    
    var body: some View {
        VStack {
            Picker("Sidebar Tabs", selection: self.$currentTab) {
                ForEach(Self.tabs, id: \.self) { tab in
//                    HStack {
                        //                        Image(systemName: tab.iconName)
                        Text(tab)
                        .width(200)
//                    }
                }
            }
            .pickerStyle(.segmented)
            
            switch ProjectSidebarTab(rawValue: self.currentTab) {
            case .none:
                FatalErrorIfDebugView()
            case .some(let tab):
                switch tab {
                case .layers:
//                    @Bindable var viewModel = tab.viewModelType.init()
                    SidebarListScrollView(graph: graph,
                                          sidebarViewModel: graph.layersSidebarViewModel,
                                          tab: tab,
                                          syncStatus: syncStatus)
                case .assets:
                    FatalErrorIfDebugView()
                }
            }
        }
        // TODO: see note in `DeriveSidebarList`
        .onChange(of: graph.nodes.keys.count) {
            dispatch(DeriveSidebarList())
        }
    }
}

struct SidebarListScrollView<SidebarObservable>: View where SidebarObservable: ProjectSidebarObservable {
    @State private var isBeingEditedAnimated = false
    
    @Bindable var graph: GraphState
    @Bindable var sidebarViewModel: SidebarObservable
    let tab: ProjectSidebarTab
    let syncStatus: iCloudSyncStatus
    
    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            listView
            Spacer()
            SidebarFooterView(sidebarViewModel: sidebarViewModel,
                              syncStatus: syncStatus)
        }
    }
    
    // Note: sidebar-list-items is a flat list;
    // indentation is handled by calculated indentations.
    @MainActor
    var listView: some View {
        ScrollView(.vertical) {
            // use .topLeading ?
            ZStack(alignment: .leading) {
                
                // HACK
                if sidebarViewModel.items.isEmpty {
//                    fakeSidebarListItem
                    Color.clear
                }
                
                ForEach(sidebarViewModel.items) { item in
                    let selection = sidebarViewModel.selectionState
                        .getSelectionStatus(item.id)
                    
                    SidebarListItemSwipeView(
                        graph: graph,
                        sidebarViewModel: sidebarViewModel,
                        gestureViewModel: item,
//                        layer: layerNodesForSidebarDict[item.id.asLayerNodeId]?.layer ?? .rectangle,
                        isClosed: sidebarViewModel.collapsedGroups.contains(item.id),
                        selection: selection)
                    .zIndex(item.zIndex) // TODO: replace wi
                    .transition(.move(edge: .top).combined(with: .opacity))
                } // ForEach
                
            } // ZStack
            
            // Need to specify the amount space (height) the sidebar items all-together need,
            // so that scroll view doesn't interfere with e.g. tap gestures on views deeper inside
            // (e.g. the tap gesture on the circle in edit-mode)
            .frame(height: Double(CUSTOM_LIST_ITEM_VIEW_HEIGHT * sidebarViewModel.items.count),
                   alignment: .top)
        
//            #if DEV_DEBUG
//            .border(.purple)
//            #endif
        } // ScrollView // added
        .scrollContentBackground(.hidden)
//        .background(WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE)
        
//        .background {
//            Color.yellow.opacity(0.5)
//        }
        
//        #if DEV_DEBUG
//        .border(.green)
//        #endif

        
#if !targetEnvironment(macCatalyst)
        .animation(.spring(), value: selections)
#endif
        // TODO: remove some of these animations ?
        .animation(.spring(), value: isBeingEdited)
        .animation(.spring(), value: sidebarViewModel.proposedGroup)
//        .animation(.spring(), value: sidebarDeps)
//        .animation(.easeIn, value: sidebarViewModel.items)
        
        .onChange(of: isBeingEdited) { _, newValue in
            // This handler enables all animations
            isBeingEditedAnimated = newValue
//            self.sidebarViewModel.editModeToggled(to: isBeingEdited)
        }
    }

    // HACK for proper width even when sidebar is empty
    // TODO: revisit and re-organize UI to avoid this hack
//    @ViewBuilder @MainActor
//    var fakeSidebarListItem: some View {
//        
//        let item = SidebarListItem.fakeSidebarListItem
//        
//        SidebarListItemSwipeView(
//            graph: $graph,
//            item: item,
//            name: item.layer.value,
//            layer: .rectangle,
//            current: .none,
//            proposedGroup: .none,
//            isClosed: true,
//            selection: .none,
//            isBeingEdited: false,
//            activeGesture: $activeGesture,
//            activeSwipeId: $activeSwipeId)
//        .opacity(0)
//    }
}

// TODO: move
import StitchViewKit
import OrderedCollections

protocol ProjectSidebarObservable: AnyObject, Observable where ItemViewModel.ID == EncodedItemData.ID,
                                                               Self.ItemViewModel.SidebarViewModel == Self {
//                                                               ExcludedGroups: Equatable {
    associatedtype ItemViewModel: SidebarItemSwipable
    associatedtype EncodedItemData: StitchNestedListElement

//    typealias ItemData = ItemViewModel.Item
    typealias ItemID = ItemViewModel.ID
    typealias SidebarSelectionState = SidebarSelectionObserver<ItemID>
    typealias SidebarGroupsDict = OrderedDictionary<Self.ItemID, [Self.ItemID]>
    typealias ExcludedGroups = [ItemID: [ItemViewModel]]
    typealias HorizontalDrag = SidebarCursorHorizontalDrag<ItemViewModel>
    
    var isEditing: Bool { get set }
    var items: [ItemViewModel] { get set }
    // the [parentId: child-ids] that are not currently shown
    var excludedGroups: ExcludedGroups { get set }
    var expandedSidebarItems: Set<ItemID> { get }
    
    var proposedGroup: ProposedGroup<ItemID>? { get set }
    var cursorDrag: HorizontalDrag? { get set }

    // groups currently opened or closed;
    // an item's id is added when its group closed,
    // removed when its group opened;
    // NOTE: a supergroup parent closing/opening does NOT affect a subgroup's closed/open status
    var collapsedGroups: Set<ItemID> { get set }
    
    var selectionState: SidebarSelectionState { get set }

    var activeSwipeId: ItemID? { get set }
    var activeGesture: SidebarListActiveGesture<ItemID> { get set }
    var implicitlyDragged: Set<ItemID> { get set }
    var currentItemDragged: SidebarDraggedItem<ItemID>? { get set }
    var orderedEncodedData: [EncodedItemData] { get set }
    var graphDelegate: GraphState? { get set }
    
//    func editModeToggled(to isEditing: Bool)
    func canBeGrouped() -> Bool
    func canUngroup() -> Bool
//    func canDuplicate() -> Bool
    
    @MainActor
    func didGroupExpand(_ id: ItemID)
//    @MainActor func sidebarListItemGroupOpened(openedParent: ItemID)

    func sidebarGroupCreated()
    func didItemsDelete(ids: Set<ItemID>)
}

extension ProjectSidebarObservable {
    var inspectorFocusedLayers: InspectorFocusedData<ItemID> {
        get {
            self.selectionState.inspectorFocusedLayers
        }
        set(newValue) {
            self.selectionState.inspectorFocusedLayers = newValue
        }
    }
    
    func initializeDelegate(graph: GraphState) {
        self.graphDelegate = graph
        self.update(from: self.orderedEncodedData)
    }
    
    func update(from encodedData: [Self.EncodedItemData]) {
        self.sync(from: encodedData)
    }
    
    func sync(from encodedData: [Self.EncodedItemData]) {
        self.orderedEncodedData = encodedData
        
        guard let graph = self.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let existingViewModels = self.items.reduce(into: [Self.ItemID : Self.ItemViewModel]()) { result, viewModel in
            result.updateValue(viewModel, forKey: viewModel.id)
        }
        
        self.items = self.recursiveSync(elements: encodedData,
                                        existingViewModels: existingViewModels,
                                        graph: graph)
    }
    
    func recursiveSync(elements: [Self.EncodedItemData],
                       existingViewModels: [Self.ItemID : Self.ItemViewModel],
                       graph: GraphState,
                       currentNestingLevel: Int = 0,
                       parentId: Self.ItemID? = nil) -> [Self.ItemViewModel] {
        // Tracks row counter
        var currentRowIndex = 0
        return self.recursiveSync(elements: elements,
                                  existingViewModels: existingViewModels,
                                  graph: graph,
                                  currentRowIndex: &currentRowIndex)
    }
    
    private func recursiveSync(elements: [Self.EncodedItemData],
                               existingViewModels: [Self.ItemID : Self.ItemViewModel],
                               graph: GraphState,
                               currentRowIndex: inout Int,
                               currentNestingLevel: Int = 0,
                               parentId: Self.ItemID? = nil) -> [Self.ItemViewModel] {
        elements.flatMap { element in
            let newLocation = Self.setLocation(rowIndex: currentRowIndex,
                                               nestingLevel: currentNestingLevel)
            // Increment row index for future elements
            currentRowIndex += 1

            let viewModel = existingViewModels[element.id] ?? .init(id: element.id,
                                                                    location: newLocation,
                                                                    parentId: parentId,
                                                                    sidebarViewModel: self,
                                                                    graph: graph)
            
            viewModel.location = newLocation
            viewModel.parentId = parentId
            
            if element.isExpandedInSidebar ?? false,
               let children = element.children {
                let childrenViewModels = self.recursiveSync(elements: children,
                                                            existingViewModels: existingViewModels,
                                                            graph: graph,
                                                            currentRowIndex: &currentRowIndex,
                                                            currentNestingLevel: currentNestingLevel + 1,
                                                            parentId: element.id)
                return [viewModel] + childrenViewModels
            }
            
            return [viewModel]
        }
    }
    
    static func setLocation(rowIndex: Int,
                            nestingLevel: Int) -> CGPoint {
        .init(x: CUSTOM_LIST_ITEM_INDENTATION_LEVEL * nestingLevel,
              y: CUSTOM_LIST_ITEM_VIEW_HEIGHT * rowIndex)
    }
}

@Observable
final class LayersSidebarViewModel: ProjectSidebarObservable {
    var isEditing = false
    var items: [SidebarItemGestureViewModel] = []
    var selectionState = SidebarSelectionObserver<NodeId>()
    var orderedEncodedData: OrderedSidebarLayers
    
    var activeSwipeId: NodeId?
    var activeGesture: SidebarListActiveGesture<NodeId> = .none
    var implicitlyDragged = NodeIdSet()
    var currentItemDragged: SidebarDraggedItem<NodeId>? = nil
    var excludedGroups: [NodeId : [SidebarItemGestureViewModel]] = .init()
//    var expandedSidebarItems: Set<NodeId> = .init()
    var proposedGroup: ProposedGroup<NodeId>?
    var cursorDrag: SidebarCursorHorizontalDrag<SidebarItemGestureViewModel>?
    var collapsedGroups: Set<NodeId> = .init()
    
    weak var graphDelegate: GraphState?
    
    init(data: OrderedSidebarLayers) {
        self.orderedEncodedData = data
    }
}

extension LayersSidebarViewModel {
    var expandedSidebarItems: Set<SidebarListItemId> {
        self.getSidebarExpandedItems()
    }
    
    @MainActor
    func didGroupExpand(_ id: NodeId) {
        self.sidebarListItemGroupOpened(openedId: id)
    }
}

//struct LayersSidebarView: View {
//    @Bindable var graph: GraphState
//
//    let syncStatus: iCloudSyncStatus
//    
//    var body: some View {
//        VStack {
//            listView
//            Spacer()
//            // Note: previously was in an `.overlay(footer, alignment: .bottom)` which now seems unnecessary
//            SidebarFooterView(sidebarViewModel: graph.layersSidebarViewModel,
//                              syncStatus: syncStatus)
//        }
//    }
//
//    
//    
//    // HACK for proper width even when sidebar is empty
//    // TODO: revisit and re-organize UI to avoid this hack
//    @ViewBuilder @MainActor
//    var fakeSidebarListItem: some View {
//
//        let item = SidebarListItem.fakeSidebarListItem
//
//        SidebarListItemSwipeView(
//            graph: $graph,
//            item: item,
//            name: item.layer.value,
//            layer: .rectangle,
//            current: .none,
//            proposedGroup: .none,
//            isClosed: true,
//            selection: .none,
//            isBeingEdited: false,
//            activeGesture: $activeGesture,
//            activeSwipeId: $activeSwipeId)
//            .opacity(0)
//    }
//}
