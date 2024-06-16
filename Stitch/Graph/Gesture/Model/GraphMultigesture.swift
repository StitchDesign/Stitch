//
//  GraphMultigesture.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import SwiftUI
import StitchSchemaKit

enum FirstActiveGesture: Equatable, Hashable {
    case graph, node, none
}

struct GraphMultigesture: Equatable, Hashable {
    /*
     The "first active [drag/pan] gesture" on the graph: graph vs node vs none

     e.g. ".node" means we were dragging the node BEFORE we started dragging the graph;

     If we (1) started dragging the graph, then (2) started dragging the node,
     the `firstActiveGesture` would be `.graph`.
     If we then (3) stopped dragging the graph, the `firstActive` would become `.node`
     If we then (4) stopped dragging the node, the `firstActive` would become `.none`
     */
    var firstActive: FirstActiveGesture = .none

    // Is the graph currently being dragged?
    // Only true when user actively dragging the graph;
    // false eg when momentum running.
    var graphIsDragged = false

    var draggedNode: NodeId?

    // Are any nodes currently being dragged?
    var nodeIsDragged: Bool {
        self.draggedNode.isDefined
    }

    // The last translation from the node(s) dragging;
    var lastNodeTranslation: CGSize = .zero

    // How much the graph has been translated *on this current graph drag gesture*.
    // Updated during graph drag;
    // Added to `accumulated` and then reset when graph drag ends
    var runningGraphTranslation: CGSize?

    // TODO: why is this needed?
    // How much we translated the graph BEFORE we drag any nodes.
    var runningGraphTranslationBeforeNodeDragged: CGSize?

    // Graph translations accumulated *while this node has been dragging*;
    // pertains to nodes, but only one single value FOR ALL nodes,
    // since all nodes sit on same graph.
    var accumulatedGraphTranslation: CGSize = .zero
}

extension GraphMovementObserver {

    var firstActive: FirstActiveGesture {
        get {
            self.graphMultigesture.firstActive
        } set(newValue) {
            self.graphMultigesture.firstActive = newValue
        }
    }

    var graphIsDragged: Bool {
        get {
            self.graphMultigesture.graphIsDragged
        } set(newValue) {
            self.graphMultigesture.graphIsDragged = newValue
        }
    }

    var draggedNode: NodeId? {
        get {
            self.graphMultigesture.draggedNode
        } set(newValue) {
            self.graphMultigesture.draggedNode = newValue
        }
    }

    var lastNodeTranslation: CGSize {
        get {
            self.graphMultigesture.lastNodeTranslation
        } set(newValue) {
            self.graphMultigesture.lastNodeTranslation = newValue
        }
    }

    var runningGraphTranslation: CGSize? {
        get {
            self.graphMultigesture.runningGraphTranslation
        } set(newValue) {
            self.graphMultigesture.runningGraphTranslation = newValue
        }
    }

    var runningGraphTranslationBeforeNodeDragged: CGSize? {
        get {
            self.graphMultigesture.runningGraphTranslationBeforeNodeDragged
        } set(newValue) {
            self.graphMultigesture.runningGraphTranslationBeforeNodeDragged = newValue
        }
    }

    var accumulatedGraphTranslation: CGSize {
        get {
            self.graphMultigesture.accumulatedGraphTranslation
        } set(newValue) {
            self.graphMultigesture.accumulatedGraphTranslation = newValue
        }
    }

    var nodeIsDragged: Bool {
        self.graphMultigesture.draggedNode.isDefined
    }
}
