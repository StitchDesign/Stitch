//
//  HSLSliderView.swift
//  whatever
//
//  Created by Christian J Clampitt on 10/26/23.
//

import SwiftUI
import StitchSchemaKit

// (current color as HSL, normalized gesture progress) -> new color
typealias HSLSliderUpdate = (HSLColor, CGFloat) -> Color

// (color as HSL) -> new Y offset for bubble
typealias HSLSlideBubbleAdjustment = (HSLColor) -> CGFloat

struct HSLSliderView: View {
    static let sliderGradientHeight: CGFloat = 200
    static let spectrumCeiling: CGFloat = 359.0
    static let spectrumRange = Array(0...Int(Self.spectrumCeiling))
    static let circleWidth: CGFloat = 20

    @State private var isDragging: Bool = false
    @State private var startLocation: CGFloat = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGFloat?
    @State private var previousPosition: CGFloat = Self.sliderGradientHeight - Self.circleWidth // 200.0

    // binding passed down from parent; represents color that user actually sees
    @Binding var chosenColor: Color

    // An array of colors representing the
    let sliderColors: [Color]
    let graph: GraphState
    let colorUpdate: HSLSliderUpdate
    let bubbleUpdate: HSLSlideBubbleAdjustment
    
    var normalizedProgressFromGesture: CGFloat {
        self.normalizeGesture() / Self.sliderGradientHeight
    }
    
    // pass in a function instead?
    var currentColor: Color {
        colorUpdate(self.chosenColor.hsl,
                    normalizedProgressFromGesture)
    }

    /// Normalize our gesture to be between 0 and 200, where 200 is the height.
    /// At 0, the users finger is on top and at 200 the users finger is at the bottom
    func normalizeGesture() -> CGFloat {
        let offset = self.position ?? self.previousPosition
        let maxY = max(0, offset)
        let minY = min(maxY, Self.sliderGradientHeight)
        return minY
    }

    var slider: some View {
        LinearGradient(gradient: Gradient(colors: sliderColors),
                       startPoint: .top,
                       endPoint: .bottom)
            .frame(width: Self.circleWidth - 5,
                   height: Self.sliderGradientHeight)
            .background {
                //            isAlpha ? Color.white : .clear
                Color.white // so that alpha slider has a background
            }
            .cornerRadius(5)
            .shadow(radius: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white, lineWidth: 2.0)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ value in

                        // first initialization
                        if self.position == nil {
                            self.position = value.startLocation.y
                            self.previousPosition = value.startLocation.y
                        }

                        withAnimation(.spring().speed(2)) {
                            var newPosition = self.previousPosition + value.translation.height
                            //                            let maxY = Self.sliderGradientHeight - Self.circleWidth
                            let maxY = Self.sliderGradientHeight
                            if newPosition < 0 {
                                newPosition = 0
                            } else if newPosition > maxY {
                                newPosition = maxY
                            }

                            self.position = newPosition

                            // log("HSLSliderView: Drag onChanged: self.position is now: \(self.position)")

                        } // withAnimation

                        // Always update color
                        self.chosenColor = self.currentColor

                    })
                    .onEnded({ (_) in
                        if let position = self.position {
                            self.previousPosition = position
                            self.position = nil
                            
                            DispatchQueue.main.async { [weak graph] in
                                graph?.encodeProjectInBackground()
                            }
                        }

                        // log("HSLSliderView: Drag onEnded: self.previousPosition is now: \(self.previousPosition)")
                    })
            )
    }

    var bubble: some View {
        Circle()
            .foregroundColor(.white)
            .frame(width: Self.circleWidth,
                   height: Self.circleWidth)
            .shadow(radius: 5)
            .overlay {
                RoundedRectangle(cornerRadius: Self.circleWidth / 2.0)
                    .stroke(Color.white
                                .opacity(0.2),
                            lineWidth: 2.0)
            }
            //            .offset(y: self.position ?? self.previousPosition)
            .offset(y: self.adjustedBubblePosition)
            .allowsHitTesting(false)
    }

    // For better appearance,
    // only visually move up the bubble a bit;
    // don't need to change DragGesture logic etc.
    var adjustedBubblePosition: CGFloat {
        (self.position ?? self.previousPosition) - Self.circleWidth/2
    }

    var debugInfo: some View {
        VStack(alignment: .leading) {
            Text("position: \(position.debugDescription)")
            Text("previousPosition: \(previousPosition.description)")
        }
        .border(.gray)
        .frame(width: 500, height: 200)
        .fixedSize(horizontal: true, vertical: true)
    }

    var body: some View {
        // `(alignment: .top)` required to start bubble's offset
        ZStack(alignment: .top) {
            slider
            bubble
            //            debugInfo.offset(x: 150)
        }
        .onAppear {
            let newPosition = bubbleUpdate(self.chosenColor.hsl)
            // only update previousPosition, not position, so that we can immediately just to wherever user drags when slider first created
            self.position = nil
            self.previousPosition = newPosition

        }
    }

}

#Preview {
    //    HSLSliderView(chosenColor: <#Binding<Color>#>, sliderColors: <#[Color]#>, colorUpdate: <#HSLSliderUpdate#>)
    //    let hsl = HSLColor(hue: 1, saturation: 0.5, brightness: 0.5, alpha: 0.5)
    AlphaSliderView(
        chosenColor: .constant(Color(hue: 1,
                                     saturation: 0.5,
                                     brightness: 0.5,
                                     //                                     opacity: 0.5))
                                     opacity: 0.75)), 
        graph: .init(id: .init(), store: nil)
    )
    //    .rotationEffect(.degrees(90))
    //    .scaleEffect(5)
    //    .scaleEffect(2)
}
