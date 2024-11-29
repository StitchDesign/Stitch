//
//  AnimationUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI

/// Provides a handler to inform us when an animation completes.
struct AnimateCompletionHandler: @preconcurrency Animatable, ViewModifier {
    var percentage: CGFloat
    var onReachedDestination: () -> Void = {}

    var animatableData: CGFloat {
        get { percentage }

        set {
            percentage = newValue
            checkIfFinished()
        }
    }

    func body(content: Content) -> some View {
        content
    }

    func checkIfFinished() {
        if percentage == 1 {
            self.onReachedDestination()
        }
    }
}

/// Object which represents a boolean as a float. Used to track the progress of animations in views.
/// This fixes a limitation of `State` variables in views which don't convey the progress of animations.
class AnimatableBool: ObservableObject {
    @Published var value: CGFloat

    init(_ initialValue: Bool) {
        self.value = initialValue ? 1 : 0
    }

    func update(_ newValue: Bool) {
        self.value = newValue ? 1 : 0
    }

    var isTrue: Bool { value == 1 }
    var isFalse: Bool { value == 0 }
}

extension Animation {
    static let stitchAnimation = stitchAnimation()

    static func stitchAnimation(duration: CGFloat = 0.5) -> Animation {
        Animation.easeInOut(duration: duration)
    }
}

struct ScaleAndFade: AnimatableModifier {
    var animatableData: CGFloat
    var nodeLocation: CGPoint?
    var graphOffset: CGSize?

    var offset: CGPoint {
        let graphOffset = graphOffset ?? .zero

        if let location = nodeLocation {
            // This calculation focuses the zoom onto the group node we're traversing to
            let point = CGPoint(x: (location.x * animatableData) - graphOffset.width,
                                y: (location.y * animatableData) - graphOffset.height)
            return point
        } else {
            return .zero
        }
    }

    func body(content: Content) -> some View {
        // animatableData should only update opacity when between 10 and 1,
        // we subtract by 1 to normalize between 9 and 0
        let opacity: CGFloat = (10 - animatableData) / 9

        content
            .scaleEffect(animatableData)
            .offset(offset.toCGSize)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// Transition for getting entering view to scale in the same direction as the outgoing view.
    static func groupTraverse(isVisitingChild: Bool,
                              nodeLocation: CGPoint,
                              graphOffset: CGSize) -> AnyTransition {
        //        log("node location: \(nodeLocation)")

        return .asymmetric(insertion: groupTraverseIn(isVisitingChild: isVisitingChild,
                                                      nodeLocation: nodeLocation,
                                                      graphOffset: graphOffset),
                           removal: groupTraverseOut(isVisitingChild: isVisitingChild,
                                                     nodeLocation: nodeLocation,
                                                     graphOffset: graphOffset))
    }

    /// The animation which transitions into view.
    private static func groupTraverseIn(isVisitingChild: Bool,
                                        nodeLocation: CGPoint,
                                        graphOffset: CGSize) -> AnyTransition {
        .modifier(active: ScaleAndFade(animatableData: isVisitingChild ? 0 : 10),
                  identity: ScaleAndFade(animatableData: 1))
    }

    /// The animation upon a view dismissal. Node and graph offset is used to zoom into a child group
    /// node when accessed.
    private static func groupTraverseOut(isVisitingChild: Bool,
                                         nodeLocation: CGPoint,
                                         graphOffset: CGSize) -> AnyTransition {
        .modifier(active: ScaleAndFade(animatableData: isVisitingChild ? 10 : 0,
                                       nodeLocation: nodeLocation,
                                       graphOffset: graphOffset),
                  identity: ScaleAndFade(animatableData: 1))
    }

    /// Slide animation for views to enter and exit from one origin, rather than sliding in one
    /// continuous direction. Used for the preview window and sidebar.
    static var slideInAndOut: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .trailing))
    }

    static func slideInAndOut(edge: Edge) -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: edge),
            removal: .move(edge: edge))
    }
}

struct StitchAnimated: ViewModifier {
    @Binding var willAnimateBinding: Bool
    var willAnimateState: Bool
    var animation: Animation

    func body(content: Content) -> some View {
        content
            .onAppear {
                willAnimateBinding = willAnimateState
            }
            .onChange(of: willAnimateState) { willAnimate in
                withAnimation(animation) {
                    willAnimateBinding = willAnimate
                }
            }
    }
}
