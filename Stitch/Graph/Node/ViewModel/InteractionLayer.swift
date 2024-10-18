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
    
    var singleTapped: Bool = false
    var doubleTapped: Bool = false
    
    var firstPressEnded: TimeInterval?
    var secondPressEnded: TimeInterval?

    var isDown: Bool = false

    var dragStartingPoint: CGPoint?
    
    // Used by Press Interaction Node for Position output
    var lastTappedLocation: CGPoint?

    // Currently still used for Scroll Interaction Node's rubberbanding etc.
    var scrollAnimationState: ScrollAnimationState = .init()
    
    var dragVelocity: CGSize = .zero
    var dragTranslation: CGSize = .zero
    
    var childSize: CGSize = .zero
    var parentSize: CGSize = .zero
}

extension InteractiveLayer {
    var layerPosition: CGPoint {
        self.delegate?.getPosition() ?? .zero
    }
    
    func onPrototypeRestart() {
        self.firstPressEnded = nil
        self.secondPressEnded = nil
        self.lastTappedLocation = nil
    }
}

protocol InteractiveLayerDelegate: AnyObject {
    func getPosition() -> CGPoint
}
