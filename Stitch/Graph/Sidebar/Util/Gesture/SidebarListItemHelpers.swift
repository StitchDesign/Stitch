//
//  SidebarListItemHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/27/24.
//

import Foundation
import SwiftUI



extension SidebarItemSwipable {

    //extension SidebarLayerData {
    
    func isSelected(_ selections: Set<Self.ID>) -> Bool {
        selections.contains(self.id)
    }
    
    func implicitlyDragged(_ implicitlyDraggedItems: Set<Self.ID>) -> Bool {
        implicitlyDraggedItems.contains(self.id)
    }
    
    func wipeIndentationLevel() {
        self.previousLocation.x = .zero
        self.location.x = .zero
        
        // TODO: update parent logic
//        self.parentId = nil
    }
    
    func setIndentToOneLevel() {
        self.previousLocation.x = CGFloat(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)
        self.location.x = CGFloat(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)
    }
}

extension ProjectSidebarObservable {
    func updateStackOnDrag(_ draggedItem: Self.ItemViewModel,
                  // all selections
                  selections: Set<Self.ItemID>) -> Bool {
        
        guard let draggedItemIndex = items.firstIndex(where: { $0.id == draggedItem.id }) else {
            print("getStack: no dragged item index")
            return false
        }
        
        // All items that were dragged along, whether explicitly or implicitly selected
        let draggedAlong = self.getDraggedAlong(draggedItem,
                                                acc: .init(),
                                                selections: selections)
        
        // Items that were dragged along but not explicitly selected
        let implicitlyDraggedItems = self.getImplicitlyDragged(
            draggedAlong: draggedAlong, 
            selections: selections)
        
        let nonDraggedItemsAbove = items.enumerated().compactMap { itemAndIndex in
            itemAndIndex.offset < draggedItemIndex ? itemAndIndex.element : nil
        }.filter { !$0.isSelected(selections) && !$0.implicitlyDragged(implicitlyDraggedItems)}
        
        let nonDraggedItemsBelow = items.enumerated().compactMap { itemAndIndex in
            itemAndIndex.offset > draggedItemIndex ? itemAndIndex.element : nil
        }.filter { !$0.isSelected(selections) && !$0.implicitlyDragged(implicitlyDraggedItems)}
        
        print("getStack: nonDraggedItemsAbove: \(nonDraggedItemsAbove.map(\.id))")
        print("getStack: nonDraggedItemsBelow: \(nonDraggedItemsBelow.map(\.id))")
        
        // All items either explicitly-dragged (because selected) or implicitly-dragged (because a child of a selected parent)
        let allDraggedItems = items.filter { $0.isSelected(selections) || $0.implicitlyDragged(implicitlyDraggedItems) }
        
        var draggedResult = [Self.ItemViewModel]()
        var itemsHandledBySomeChunk = Set<ItemID>()
        for draggedItem in allDraggedItems {
            print("getStack: on draggedItem \(draggedItem.id)")
            
            if itemsHandledBySomeChunk.contains(draggedItem.id) {
                print("getStack: draggedItem \(draggedItem.id) was already handled by some chunk")
                continue
            }
            
            let draggedItemIsSelected = draggedItem.isSelected(selections)
            
            // An explicitly-dragged parent kicks off a "chunk"
            if draggedItem.isGroup,
               draggedItemIsSelected {
                print("getStack: draggedItem \(draggedItem.id) starts a chunk")
                // wipe the draggedItem's
                let chunk = self.rearrangeChunk(
                    selectedParentItem: draggedItem,
                    selections: selections,
                    implicitlyDragged: implicitlyDraggedItems)
                
                itemsHandledBySomeChunk = itemsHandledBySomeChunk.union(Set<ItemID>(chunk.map(\.id)))
                draggedResult += chunk
            }
            
            // Explicitly selected items get their indents wiped
            else if draggedItemIsSelected {
                print("getStack: draggedItem \(draggedItem.id) is explicitly selected")
                var draggedItem = draggedItem
                draggedItem.wipeIndentationLevel()
                draggedResult.append(draggedItem)
            }
            
            else {
                print("getStack: draggedItem \(draggedItem.id) is only implicitly-selected")
                draggedResult.append(draggedItem)
            }
        }
        
        self.items = nonDraggedItemsAbove + draggedResult + nonDraggedItemsBelow
        
        // Use the newly-reordered masterList's indices to update each master list item's y position
        self.setYPositionByIndices(
            originalItemId: draggedItem.id,
            // treat as drag ended so that we update previousLocation etc.
            isDragEnded: true)
        
        return true
    }
    
    func rearrangeChunk(selectedParentItem: Self.ItemViewModel,
                        selections: Set<Self.ItemID>,
                        implicitlyDragged: Set<Self.ItemID>) -> [Self.ItemViewModel] {
        
        guard let selectedParentItemIndex: Int = self.items.firstIndex(where: { $0.id == selectedParentItem.id }) else {
            print("rearrangeChunk: no selected parent item index for \(selectedParentItem.id)")
            return []
        }
        
        guard let chunkEnderIndex: Int = self.getChunkEnderIndex(
            selectedParentItem: selectedParentItem,
            selectedParentItemIndex: selectedParentItemIndex, 
            selections: selections) else {
            
            print("rearrangeChunk: no chunkEnderIndex for \(selectedParentItem.id)")
            return []
        }
        log("chunkEnderIndex: \(chunkEnderIndex)")
        
        //        let chunk = flatMasterList[selectedParentItemIndex...chunkEnderIndex]
        
        // exclude the parent itself?
        //    let chunk = flatMasterList[(selectedParentItemIndex + 1)...chunkEnderIndex]
        
        // excluded chunkEnder?
        let chunk = self.items[(selectedParentItemIndex + 1)...(chunkEnderIndex - 1)]
        
        let explicitlyDragged = chunk.filter { $0.isSelected(selections) }
        let implicitlyDragged = chunk.filter { $0.implicitlyDragged(implicitlyDragged) }
        
        explicitlyDragged.wipeIndentationLevelsOfSelectedItems(selections: selections)
        
        // Must also wipe the indentation level of the selectedParentItem
        selectedParentItem.wipeIndentationLevel()
        
        // Also, the implicitly-dragged children can at most have +1 indentation level,
        // since their selected parent was made top level (i.e. identation level 0).
        implicitlyDragged.forEach { item in
            //        item.indentationLevel = 1
            item.setIndentToOneLevel()
        }
        
        return [selectedParentItem] + implicitlyDragged + explicitlyDragged
    }
    
    
    // THE INDEX OF THE DOWN-THE-LIST TOP LEVEL ITEM that ends the chunk
    func getChunkEnderIndex(selectedParentItem: Self.ItemViewModel,
                            selectedParentItemIndex: Int,
                            selections: Set<Self.ItemID>) -> Int? {
        
        let itemsAndIndices = self.items.enumerated()
        
        for itemAndIndex in itemsAndIndices {
            let index = itemAndIndex.offset
            let item = itemAndIndex.element
            
            if index > selectedParentItemIndex
                && item.indentationLevel.value == 0
                && item.isSelected(selections) {
                print("getChunkEnderIndex: found selected chunk ender index: \(index), item \(item)")
                return index
            }
        }
        
        // It can happen that there is no top level item below us that is selected.
        // In that case, we just grab the index of the first top level item below us.
        for itemAndIndex in self.items.enumerated() {
            let index = itemAndIndex.offset
            let item = itemAndIndex.element
            
            if index > selectedParentItemIndex
                && item.indentationLevel.value == 0 {
                print("getChunkEnderIndex: found chunk ender index: \(index), item \(item)")
                return index
            }
        }
        
        // TODO: what happens if there's no item AT ALL below us?
        // just return the last item in the chunk + 1 ?
        if let maxIndex = itemsAndIndices.map(\.offset).max() {
            print("getChunkEnderIndex: no layers below at all; will use max index \(maxIndex) chunk ender index")
            // +1, so that we think we're going to some "imaginary" layer below us
            return maxIndex + 1
        }
        
        print("getChunkEnderIndex: no chunk ender index")
        return nil
    }
}

