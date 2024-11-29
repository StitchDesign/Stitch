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
    typealias SidebarSelectionState = Self
    typealias ExcludedGroups = [ItemID: [ItemViewModel]]
    
    @MainActor var isEditing: Bool { get set }

    @MainActor var items: [ItemViewModel] { get set }

    @MainActor var activeSwipeId: ItemID? { get set }

    @MainActor var activeGesture: SidebarListActiveGesture<ItemID> { get set }

    @MainActor var haveDuplicated: Bool { get set }
    
    @MainActor var optionDragInProgress: Bool { get set }
    
    @MainActor var primary: Set<ItemID> { get set }
    
    @MainActor var lastFocused: ItemID? { get set }
    
    @MainActor var currentItemDragged: Self.ItemID? { get set }
    
    @MainActor var graphDelegate: GraphState? { get set }

    @MainActor func sidebarGroupCreated()
    
    @MainActor
    func sidebarGroupUncreatedViaEditMode(groupId: Self.ItemID, children: [Self.ItemID])
 
    @MainActor
    func didItemsDelete(ids: Set<ItemID>)
}

extension ProjectSidebarObservable {
    // TODO: tech debt to remove
    var selectionState: Self { self }
    
    @MainActor
    var proposedGroup: Self.ItemViewModel? {
        guard let currentItemDragged = self.currentItemDragged else { return nil }
        return self.items.get(currentItemDragged)?.parentDelegate
    }
    
    @MainActor
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
    
    @MainActor
    func update(from encodedData: [Self.EncodedItemData]) {
        self.sync(from: encodedData)
    }
    
    @MainActor
    func sync(from encodedData: [Self.EncodedItemData]) {
        let existingViewModels = self.items.reduce(into: [Self.ItemID : Self.ItemViewModel]()) { result, viewModel in
            result.updateValue(viewModel, forKey: viewModel.id)
        }
        
        self.items = self.recursiveSync(elements: encodedData,
                                        existingViewModels: existingViewModels)
        self.items.updateSidebarIndices()
    }
    
    @MainActor
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
