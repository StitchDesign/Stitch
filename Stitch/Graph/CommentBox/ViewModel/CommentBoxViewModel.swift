//
//  CommentBoxViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/5/24.
//

import StitchSchemaKit
import SwiftUI

typealias CommentBoxesDict = [UUID: CommentBoxViewModel]

@Observable
final class CommentBoxViewModel {
    var id: UUID = .init()
    var groupId: NodeId?
    var title: String = "Comment"
    var color: Color
    var nodes: NodeIdSet = .init()
    var previousPosition: CGPoint = .zero
    var position: CGPoint = .zero
    var size: CGSize = .zero
    var zIndex: Double = .zero
    var expansionBox: CommentExpansionBox = .init()

    init(groupId: NodeId? = nil,
         title: String = "Comment",
         color: Color = CommentBoxViewModel.colorOptions.randomElement() ?? .blue,
         nodes: NodeIdSet = .init(),
         position: CGPoint = .zero,
         size: CGSize = .zero,
         expansionBox: CommentExpansionBox = .init(),
         zIndex: Double = .zero) {
        self.groupId = groupId
        self.title = title
        self.color = color
        self.nodes = nodes
        self.position = position
        self.previousPosition = position
        self.size = size
        self.zIndex = zIndex
    }
}

extension CommentBoxViewModel: SchemaObserver {
    @MainActor
    static func createObject(from entity: CommentBoxData) -> Self {
        Self.init(groupId: entity.groupId,
                  title: entity.title,
                  color: entity.color,
                  nodes: entity.nodes,
                  position: entity.position,
                  size: entity.size,
                  zIndex: entity.zIndex)
    }

    @MainActor
    func update(from schema: CommentBoxData) {
        self.id = schema.id
        self.groupId = schema.groupId
        self.title = schema.title
        self.color = schema.color
        self.nodes = schema.nodes
        self.position = schema.position
        self.size = schema.size
        self.zIndex = schema.zIndex
    }

    func createSchema() -> CommentBoxData {
        CommentBoxData(
            id: self.id,
            groupId: self.groupId,
            title: self.title,
            color: self.color,
            nodes: self.nodes,
            position: self.position,
            size: self.size,
            zIndex: self.zIndex
        )
    }
    
    func onPrototypeRestart() { }
}

// TODO: move to view
struct CommentExpansionBox: Equatable, Hashable {
    var nodes: NodeIdSet = .init()

    // set nil after gesture completes;
    // set non-nil when gesture first starts
    var expansionDirection: ExpansionDirection?

    // size is always positive numbers
    var size: CGSize = .zero
    var previousSize: CGSize = .zero

    // drag gesture start
    var startPoint: CGPoint = .zero

    // drag gesture current
    var endPoint: CGPoint = .zero

    var anchorCorner: CGPoint = .zero
}

extension CommentBoxesDict {
    mutating func sync(from commentBoxesData: [CommentBoxData]) {
        commentBoxesData.forEach { data in
            if let existingViewModel = self.get(data.id) {

            }
        }
    }
}

struct CommentBoxBounds: Equatable, Codable, Hashable {
    var titleBounds: CGRect = .zero
    var borderBounds: CGRect = .zero
}

// typealias CommentBoxBoundsDict = [CommentBoxId: CGRect]
typealias CommentBoxBoundsDict = [CommentBoxId: CommentBoxBounds]
