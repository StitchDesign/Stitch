//
//  _SidebarListLabelViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemLeftLabelView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    @State private var isBeingEditedAnimated = false
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var itemViewModel: SidebarViewModel.ItemViewModel
    let fontColor: Color
    
    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    @MainActor
    var masks: Bool {
        self.itemViewModel.isMasking
    }
    
    var body: some View {
        HStack(spacing: 4) {
            
            SidebarListItemChevronView(sidebarViewModel: sidebarViewModel,
                                       item: itemViewModel,
                                       fontColor: fontColor)
//                                           isHidden: isHidden)
            .opacity(itemViewModel.isGroup ? 1 : 0)
                // .border(.green)
//            }
  
            Image(systemName: itemViewModel.sidebarLeftSideIcon)
                .scaledToFit()
                .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                       height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
                .foregroundColor(fontColor)
                .overlay(alignment: .bottomLeading) {
                    ZStack {
                        
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                        
                        Image(systemName: MASKS_LAYER_ABOVE_ICON_NAME)
                            .resizable()
                            .scaledToFit()
                            .padding(2)
                            .offset(x: -0.5)
                            .foregroundColor(fontColor)
                    }
                    .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT/2,
                           height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT/2)
                    .foregroundColor(fontColor)
                    .opacity(masks ? 1 : 0)
                    .animation(.linear, value: masks)
                    .cornerRadius(4)
                }
            
            label
                .foregroundColor(fontColor)
        }
        .padding(.leading, 4)
        .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
    }
    
    var label: some View {
        Group {
            if isBeingEdited {
                SidebarListLabelEditView(item: self.itemViewModel,
                                         fontColor: fontColor,
                                         graph: graph,
                                         document: document)
                .truncationMode(.tail)
#if targetEnvironment(macCatalyst)
                .padding(.trailing, 44)
#else
                .padding(.trailing, 60)
#endif
            } else {
                SidebarListLabelEditView(item: self.itemViewModel,
                                         fontColor: fontColor,
                                         graph: graph,
                                         document: document)
            }
        }
        .lineLimit(1)
    }
}

struct SidebarListLabelEditView<ItemViewModel>: View where ItemViewModel: SidebarItemSwipable {
    
    // Do we need to add another focused field type here?
    // If this is focused, you don't want
    
    @Bindable var item: ItemViewModel
    let fontColor: Color
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
        
    @State var edit: String = ""
        
    @MainActor
    var isFocused: Bool {
        switch document.reduxFocusedField {
        case .sidebarLayerTitle(let idString):
            let k = item.id.description == idString
            // log("SidebarListLabelEditView: isFocused: \(k) for \(id)")
            return k
        default:
            // log("SidebarListLabelEditView: isFocused: false")
            return false
        }
    }
    
    
    var debugId: String {
#if DEV_DEBUG
        " \(self.item.id.debugFriendlyId)"
#else
        ""
#endif
    }
    
    var body: some View {
        Group {
            if isFocused {
                StitchTextEditingBindingField(currentEdit: self.$edit,
                                              fieldType: .sidebarLayerTitle(self.item.id.description),
                                              font: SIDEBAR_LIST_ITEM_FONT,
                                              fontColor: fontColor,
                                              fieldEditCallback: { (newEdit: String, isCommitting: Bool) in
                    self.item.didLabelEdit(to: newEdit,
                                           isCommitting: isCommitting,
                                           graph: graph)
                })
            } else {
                StitchTextView(string: edit + debugId,
                               font: SIDEBAR_LIST_ITEM_FONT,
                               fontColor: fontColor)
                .padding(.top, 1)
            }
        }
         // Not just initialization but also e.g. whenever canvas item updates the layer node's title
        .onChange(of: self.item.name, initial: true) { oldValue, newValue in
            
            // HACK: for edge case where item.name defaults to full layer name *during an active edit* (empty custom-title defaults to full layer name).
            // TODO: debug why this doesn't happen with edit-fields on canvas item's title
            if oldValue.count == 1, newValue == self.item.layerFullName {
                self.edit = ""
            } else {
                self.edit = self.item.name
            }
        }
        .onTapGesture(count: 2) {
            dispatch(ReduxFieldFocused(focusedField: .sidebarLayerTitle(self.item.id.description)))
        }
    }
    
}


struct SidebarListItemRightLabelView<ItemViewModel>: View where ItemViewModel: SidebarItemSwipable {
    @State private var isBeingEditedAnimated = false

    let item: ItemViewModel
    let sidebar: ItemViewModel.SidebarViewModel
    let isBeingEdited: Bool // is sidebar being edited?
    let fontColor: Color

    var body: some View {
        HStack(spacing: .zero) {
            if isBeingEditedAnimated {
                HStack(spacing: .zero) {
                    SidebarListItemSelectionCircleView(item: item,
                                                       sidebar: sidebar,
                                                       fontColor: fontColor,
                                                       isBeingEdited: isBeingEdited)
                        .padding(.trailing, 4)

                    SidebarListDragIconView()
                        .padding(.trailing, 4)
                }
                .transition(.slideInAndOut)
            }
        } // HStack
        // Animate padding so that icons and completely animate off screen
        .padding(.trailing, isBeingEditedAnimated ? 4 : 0)
        .stitchAnimated(willAnimateBinding: $isBeingEditedAnimated,
                        willAnimateState: isBeingEdited,
                        animation: .stitchAnimation(duration: 0.25))
        .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
    }
}

let EDIT_MODE_HAMBURGER_DRAG_ICON = "line.3.horizontal"
let EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR: Color = .gray // Always gray, whether light or dark mode

// TODO: on iPad, dragging the hamburger icon should immediately drag the sidebar-item without need for long press first
struct SidebarListDragIconView: View {
    var body: some View {
        Image(systemName: EDIT_MODE_HAMBURGER_DRAG_ICON)
        // TODO: Should use white if this sidebar layer is selected?
            .foregroundColor(EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR)
            .scaleEffect(1.2)
            .frame(width: SIDEBAR_ITEM_ICON_LENGTH,
                   height: SIDEBAR_ITEM_ICON_LENGTH)
            .padding(4)
    }
}

#if targetEnvironment(macCatalyst)
let SIDEBAR_ITEM_ICON_LENGTH: CGFloat = 14
#else
let SIDEBAR_ITEM_ICON_LENGTH: CGFloat = 25
#endif
