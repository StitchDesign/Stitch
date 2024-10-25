//
//  AlphaPickerView.swift
//  whatever
//
//  Created by Christian J Clampitt on 10/26/23.
//

import SwiftUI
import StitchSchemaKit

struct AlphaSliderView: View {
    @Binding var chosenColor: Color
    let graph: GraphState

    var body: some View {
        alphaSlider
    }

    var alphaSlider: some View {
        HSLSliderView(chosenColor: $chosenColor,
                      sliderColors: alphaSliderColors,
                      graph: graph) { color, progress in
            HSLColor(hue: color.hue,
                     saturation: color.saturation,
                     lightness: color.lightness,
                     alpha: progress)
                .toColor
        } bubbleUpdate: { color in
            let newPosition = Stitch.transition(
                color.alpha,
                start: 0,
                end: HSLSliderView.sliderGradientHeight - HSLSliderView.circleWidth)
            return newPosition
        }
    }

    var alphaSliderColors: [Color] {
        HSLSliderView.spectrumRange.map { x in
            Color(hue: 1.0, // doesn't matter, since brightness=0 ignores hue
                  saturation: 1.0,
                  lightness: 0.0, // black-white
                  opacity: CGFloat(x) / HSLSliderView.spectrumCeiling
            )
        }
    }

}

struct AlphaPickerView_Previews: PreviewProvider {
    static var previews: some View {

        AlphaSliderView(chosenColor: Binding.constant(Color.indigo),
                        graph: .createEmpty())
            .rotation3DEffect(Angle(degrees: -90),
                              axis: (x: 0.0, y: 1.0, z: 90.0))
            .scaleEffect(5)
    }
}
