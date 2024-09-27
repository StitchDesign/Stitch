//
//  SidebarListItemHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/27/24.
//

import Foundation
import SwiftUI



extension SidebarListItem {

    //extension SidebarLayerData {
    
    func isSelected(_ selections: SidebarListItemIdSet) -> Bool {
        selections.contains(self.id)
    }
    
    func implicitlyDragged(_ implicitlyDraggedItems: SidebarListItemIdSet) -> Bool {
        implicitlyDraggedItems.contains(self.id)
    }
    
    func wipeIndentationLevel() -> Self {
        var item = self
        item.previousLocation.x = .zero
        item.location.x = .zero
        item.parentId = nil
        return item
    }
    
    func setIndentToOneLevel() -> Self {
        var item = self
        item.previousLocation.x = CGFloat(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)
        item.location.x = CGFloat(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)
        return item
    }
}

func getStack(_ draggedItem: SidebarListItem,
              items: [SidebarListItem],
              // all selections
              selections: SidebarListItemIdSet
//              ,
              // all implicitly dragged
//              implicitlyDraggedItems: SidebarListItemIdSet
) -> [SidebarListItem]? {
        
    guard let draggedItemIndex = items.firstIndex(where: { $0.id == draggedItem.id }) else {
        print("getStack: no dragged item index")
        return nil
    }
    
    
    // All items that were dragged along, whether explicitly or implicitly selected
    let draggedAlong = getDraggedAlong(draggedItem,
                                       allItems: items,
                                       acc: .init())
    
    // Items that were dragged along but not explicitly selected
    let implicitlyDraggedItems: SidebarListItemIdSet = getImplicitlyDragged(
        items: items,
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
    
    var draggedResult = [SidebarListItem]()
    var itemsHandledBySomeChunk = SidebarListItemIdSet()
    for draggedItem in allDraggedItems {
        print("getStack: on draggedItem \(draggedItem.id)")

        if itemsHandledBySomeChunk.contains(draggedItem.id) {
            print("getStack: draggedItem \(draggedItem.id) was already handled by some chunk")
            continue
        }
                
        // An explicitly-dragged parent kicks off a "chunk"
        if draggedItem.isGroup,
           draggedItem.isSelected(selections) {
            print("getStack: draggedItem \(draggedItem.id) starts a chunk")
            // wipe the draggedItem's
            let chunk = rearrangeChunk(
                selectedParentItem: draggedItem,
                selections: selections,
                implicitlyDragged: implicitlyDraggedItems,
                flatMasterList: items)
            
            itemsHandledBySomeChunk = itemsHandledBySomeChunk.union(SidebarListItemIdSet.init(chunk.map(\.id)))
            draggedResult += chunk
        }

        // Explicitly selected items get their indents wiped
        else if draggedItem.isSelected(selections) {
            print("getStack: draggedItem \(draggedItem.id) is explicitly selected")
            var draggedItem = draggedItem
            draggedItem = draggedItem.wipeIndentationLevel()
            draggedResult.append(draggedItem)
        }
 
        else {
            print("getStack: draggedItem \(draggedItem.id) is only implicitly-selected")
            draggedResult.append(draggedItem)
        }
    }
    
    let rearrangedMasterList = nonDraggedItemsAbove + draggedResult + nonDraggedItemsBelow
    
    // Use the newly-reordered masterList's indices to update each master list item's y position
    let _rearrangedMasterList = setYPositionByIndices(
        originalItemId: draggedItem.id,
        rearrangedMasterList,
        // treat as drag ended so that we update previousLocation etc.
        isDragEnded: true)
    
    return _rearrangedMasterList
}

func rearrangeChunk(selectedParentItem: SidebarListItem,
                    selections: SidebarListItemIdSet,
                    implicitlyDragged: SidebarListItemIdSet,
                    flatMasterList: [SidebarListItem]) -> [SidebarListItem] {
    
    guard let selectedParentItemIndex: Int = flatMasterList.firstIndex(where: { $0.id == selectedParentItem.id }) else {
        print("rearrangeChunk: no selected parent item index for \(selectedParentItem.id)")
        return []
    }
    
    guard let chunkEnderIndex: Int = getChunkEnderIndex(
        selectedParentItem: selectedParentItem,
        selectedParentItemIndex: selectedParentItemIndex, 
        selections: selections,
        flatMasterList: flatMasterList) else {
        
        print("rearrangeChunk: no chunkEnderIndex for \(selectedParentItem.id)")
        return []
    }
    
    //    let chunk = flatMasterList[selectedParentItemIndex...chunkEnderIndex]
    
    // exclude the parent itself?
    //    let chunk = flatMasterList[(selectedParentItemIndex + 1)...chunkEnderIndex]
    
    // excluded chunkEnder?
    let chunk = flatMasterList[(selectedParentItemIndex + 1)...(chunkEnderIndex - 1)]
    
    let explicitlyDragged = chunk.filter { $0.isSelected(selections) }
    let implicitlyDragged = chunk.filter { $0.implicitlyDragged(implicitlyDragged) }
    
    let wipedExplicitlyDragged = wipeIndentationLevelsOfSelectedItems(
        items: explicitlyDragged, 
        selections: selections)
    
    // Must also wipe the indentation level of the selectedParentItem
    var selectedParentItem = selectedParentItem
    selectedParentItem = selectedParentItem.wipeIndentationLevel()
    
    // Also, the implicitly-dragged children can at most have +1 indentation level,
    // since their selected parent was made top level (i.e. identation level 0).
    let oneIndentLevelImplicitlyDragged = implicitlyDragged.map { item in
        var item = item
//        item.indentationLevel = 1
        return item.setIndentToOneLevel()
    }
    
    return [selectedParentItem] + oneIndentLevelImplicitlyDragged + wipedExplicitlyDragged
}


// THE INDEX OF THE DOWN-THE-LIST TOP LEVEL ITEM that ends the chunk
func getChunkEnderIndex(selectedParentItem: SidebarListItem,
                        selectedParentItemIndex: Int,
                        selections: SidebarListItemIdSet,
                        flatMasterList: [SidebarListItem]) -> Int? {
    
    for itemAndIndex in flatMasterList.enumerated() {
        let index = itemAndIndex.offset
        let item = itemAndIndex.element
        
        if index > selectedParentItemIndex
            && item.indentationLevel.value == 0
            && item.isSelected(selections) {
            print("getChunkEnderIndex: found selected chunk ender index: \(index)")
            return index
        }
    }
    
    // It can happen that there is no top level item below us that is selected.
    // In that case, we just grab the index of the first top level item below us.
    for itemAndIndex in flatMasterList.enumerated() {
        let index = itemAndIndex.offset
        let item = itemAndIndex.element
        
        if index > selectedParentItemIndex
            && item.indentationLevel.value == 0 {
            print("getChunkEnderIndex: found chunk ender index: \(index)")
            return index
        }
    }
    
    print("getChunkEnderIndex: no chunk ender index")
    return nil
}
