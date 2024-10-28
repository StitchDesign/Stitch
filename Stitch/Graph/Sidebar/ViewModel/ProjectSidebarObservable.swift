//
//  ProjectSidebarObservable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI
import StitchViewKit

protocol ProjectSidebarObservable: AnyObject, Observable where ItemViewModel.ID == EncodedItemData.ID,
                                                               Self.ItemViewModel.SidebarViewModel == Self {
    associatedtype ItemViewModel: SidebarItemSwipable
    associatedtype EncodedItemData: StitchNestedListElement

    typealias ItemID = ItemViewModel.ID
    typealias SidebarSelectionState = SidebarSelectionObserver<ItemID>
    typealias ExcludedGroups = [ItemID: [ItemViewModel]]
    
    var isEditing: Bool { get set }

    var items: [ItemViewModel] { get set }

    var selectionState: SidebarSelectionState { get set }

    var activeSwipeId: ItemID? { get set }

    var activeGesture: SidebarListActiveGesture<ItemID> { get set }


    var currentItemDragged: Self.ItemID? { get set }
    
    var graphDelegate: GraphState? { get set }
    
    func canBeGrouped() -> Bool
    
    func canUngroup() -> Bool

    func sidebarGroupCreated()
    
    @MainActor
    func sidebarGroupUncreatedViaEditMode(groupId: Self.ItemID, children: [Self.ItemID])
    
    func didItemsDelete(ids: Set<ItemID>)
}

extension ProjectSidebarObservable {
    var proposedGroup: Self.ItemViewModel? {
        guard let currentItemDragged = self.currentItemDragged else { return nil }
        return self.items.get(currentItemDragged)?.parentDelegate
    }
    
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
        
        self.items.recursiveForEach {
            $0.sidebarDelegate = self
        }
    }
    
    @MainActor func persistSidebarChanges(encodedData: [Self.EncodedItemData]? = nil) {
        // Create new encodable data
        let encodedData: [Self.EncodedItemData] = encodedData ?? self.createdOrderedEncodedData()
        
        // Refreshes view
        self.update(from: encodedData)
        
        self.graphDelegate?.encodeProjectInBackground()
    }
    
    @MainActor func createdOrderedEncodedData() -> [Self.EncodedItemData] {
        self.items.map { item in
            item.createSchema()
        }
    }
    
    func update(from encodedData: [Self.EncodedItemData]) {
        self.sync(from: encodedData)
    }
    
    func sync(from encodedData: [Self.EncodedItemData]) {
        let existingViewModels = self.items.reduce(into: [Self.ItemID : Self.ItemViewModel]()) { result, viewModel in
            result.updateValue(viewModel, forKey: viewModel.id)
        }
        
        self.items = self.recursiveSync(elements: encodedData,
                                        existingViewModels: existingViewModels)
        self.items.updateSidebarIndices()
    }
    
    func recursiveSync(elements: [Self.EncodedItemData],
                       existingViewModels: [Self.ItemID : Self.ItemViewModel],
                       parent: Self.ItemViewModel? = nil) -> [Self.ItemViewModel] {
        elements.map { element in
            let viewModel = existingViewModels[element.id] ?? .init(data: element,
                                                                    parentDelegate: parent,
                                                                    sidebarViewModel: self)
            
            viewModel.update(from: element)
            
            guard let children = element.children else {
                viewModel.children = nil
                viewModel.isExpandedInSidebar = nil
                return viewModel
            }
            
            let childrenViewModels = self.recursiveSync(elements: children,
                                                        existingViewModels: existingViewModels,
                                                        parent: viewModel)
            viewModel.children = childrenViewModels
            return viewModel
        }
    }
}
