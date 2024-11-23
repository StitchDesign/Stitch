//
//  InteractionPatchNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/12/23.
//

import Foundation
import StitchSchemaKit

final class InteractiveLayer {
    let id: PreviewCoordinate
    weak var delegate: InteractiveLayerDelegate?
    
    init(id: PreviewCoordinate) {
        self.id = id
    }
    
    @MainActor var singleTapped: Bool = false
    @MainActor var doubleTapped: Bool = false
    
    @MainActor var firstPressEnded: TimeInterval?
    @MainActor var secondPressEnded: TimeInterval?

    @MainActor var isDown: Bool = false

    @MainActor var dragStartingPoint: CGPoint?
    
    // Used by Press Interaction Node for Position output
    @MainActor var lastTappedLocation: CGPoint?

    // Currently still used for Scroll Interaction Node's rubberbanding etc.
    @MainActor var scrollAnimationState: ScrollAnimationState = .init()
    
    @MainActor var dragVelocity: CGSize = .zero
    @MainActor var dragTranslation: CGSize = .zero
    
    @MainActor var childSize: CGSize = .zero
    @MainActor var parentSize: CGSize = .zero
}

extension InteractiveLayer {
    @MainActor
    var layerPosition: CGPoint {
        self.delegate?.getPosition() ?? .zero
    }
    
    @MainActor
    func onPrototypeRestart() {
        self.firstPressEnded = nil
        self.secondPressEnded = nil
        self.lastTappedLocation = nil
    }
}

protocol InteractiveLayerDelegate: AnyObject {
    @MainActor func getPosition() -> CGPoint
}
