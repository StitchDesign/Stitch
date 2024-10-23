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
}

extension ProjectSidebarObservable {
    @MainActor
    func updateStackOnDrag(_ draggedItem: Self.ItemViewModel,
                  // all selections
                  selections: Set<Self.ItemID>) -> Bool {
        
        guard let draggedItemIndex = items.firstIndex(where: { $0.id == draggedItem.id }) else {
            print("getStack: no dragged item index")
            return false
        }
        
        // All items that were dragged along, whether explicitly or implicitly selected
        let draggedAlong = self.getDraggedAlong(draggedItem,
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
        
//        log("getStack: nonDraggedItemsAbove: \(nonDraggedItemsAbove.map(\.id))")
//        log("getStack: nonDraggedItemsBelow: \(nonDraggedItemsBelow.map(\.id))")
        
        return true
    }
    
//    func rearrangeChunk(selectedParentItem: Self.ItemViewModel,
//                        selections: Set<Self.ItemID>,
//                        implicitlyDragged: Set<Self.ItemID>) -> [Self.ItemViewModel] {
//        
//        guard let selectedParentItemIndex: Int = self.items.firstIndex(where: { $0.id == selectedParentItem.id }) else {
//            print("rearrangeChunk: no selected parent item index for \(selectedParentItem.id)")
//            return []
//        }
//        
//        guard let chunkEnderIndex: Int = self.getChunkEnderIndex(
//            selectedParentItem: selectedParentItem,
//            selectedParentItemIndex: selectedParentItemIndex, 
//            selections: selections) else {
//            
//            print("rearrangeChunk: no chunkEnderIndex for \(selectedParentItem.id)")
//            return []
//        }
//        log("chunkEnderIndex: \(chunkEnderIndex)")
//        
//        //        let chunk = flatMasterList[selectedParentItemIndex...chunkEnderIndex]
//        
//        // exclude the parent itself?
//        //    let chunk = flatMasterList[(selectedParentItemIndex + 1)...chunkEnderIndex]
//        
//        // excluded chunkEnder?
//        let chunk = self.items[(selectedParentItemIndex + 1)...(chunkEnderIndex - 1)]
//        
//        let explicitlyDragged = chunk.filter { $0.isSelected(selections) }
//        let implicitlyDragged = chunk.filter { $0.implicitlyDragged(implicitlyDragged) }
//        
////        explicitlyDragged.wipeIndentationLevelsOfSelectedItems(selections: selections)
////        
////        // Must also wipe the indentation level of the selectedParentItem
////        selectedParentItem.wipeIndentationLevel()
////        
////        // Also, the implicitly-dragged children can at most have +1 indentation level,
////        // since their selected parent was made top level (i.e. identation level 0).
////        implicitlyDragged.forEach { item in
////            //        item.indentationLevel = 1
////            item.setIndentToOneLevel()
////        }
//        
//        return [selectedParentItem] + implicitlyDragged + explicitlyDragged
//    }
    
    
    // THE INDEX OF THE DOWN-THE-LIST TOP LEVEL ITEM that ends the chunk
//    func getChunkEnderIndex(selectedParentItem: Self.ItemViewModel,
//                            selectedParentItemIndex: Int,
//                            selections: Set<Self.ItemID>) -> Int? {
//        
//        let itemsAndIndices = self.items.enumerated()
//        
//        for itemAndIndex in itemsAndIndices {
//            let index = itemAndIndex.offset
//            let item = itemAndIndex.element
//            
//            if index > selectedParentItemIndex
//                && item.indentationLevel.value == 0
//                && item.isSelected(selections) {
//                print("getChunkEnderIndex: found selected chunk ender index: \(index), item \(item)")
//                return index
//            }
//        }
//        
//        // It can happen that there is no top level item below us that is selected.
//        // In that case, we just grab the index of the first top level item below us.
//        for itemAndIndex in self.items.enumerated() {
//            let index = itemAndIndex.offset
//            let item = itemAndIndex.element
//            
//            if index > selectedParentItemIndex
//                && item.indentationLevel.value == 0 {
//                print("getChunkEnderIndex: found chunk ender index: \(index), item \(item)")
//                return index
//            }
//        }
//        
//        // TODO: what happens if there's no item AT ALL below us?
//        // just return the last item in the chunk + 1 ?
//        if let maxIndex = itemsAndIndices.map(\.offset).max() {
//            print("getChunkEnderIndex: no layers below at all; will use max index \(maxIndex) chunk ender index")
//            // +1, so that we think we're going to some "imaginary" layer below us
//            return maxIndex + 1
//        }
//        
//        print("getChunkEnderIndex: no chunk ender index")
//        return nil
//    }
}

