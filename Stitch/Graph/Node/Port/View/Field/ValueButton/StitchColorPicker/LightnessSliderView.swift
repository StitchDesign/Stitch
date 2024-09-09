//
//  LightnessPickerView.swift
//  whatever
//
//  Created by Christian J Clampitt on 10/26/23.
//

import SwiftUI
import StitchSchemaKit

// https://stackoverflow.com/questions/73091627/what-is-the-difference-between-alpha-and-lightness-in-hsla-color-values

struct LightnessSliderView: View {

    // binding passed down from parent; represents color that user actually sees
    @Binding var chosenColor: Color
    let graph: GraphState

    var body: some View {
        lightnessSlider
    }

    var lightnessSlider: some View {
        HSLSliderView(chosenColor: $chosenColor,
                      sliderColors: lightnessSliderColors,
                      graph: graph) { color, progress in

            // Never allow 0 or 1 for lightness, since that shifts the hue.
            var progress = progress
            if progress == 1 {
                progress = 0.99
            } else if progress == .zero {
                progress = 0.0001
            }

            return HSLColor(hue: color.hue,
                            saturation: color.saturation,
                            lightness: progress,
                            alpha: color.alpha)
                .toColor

        }  bubbleUpdate: { color in
            var newPosition = Stitch.transition(
                color.lightness,
                start: 0,
                end: HSLSliderView.sliderGradientHeight - HSLSliderView.circleWidth)
            return newPosition
        }
    }

    var lightnessSliderColors: [Color] {
        HSLSliderView.spectrumRange.map {
            Color(hue: self.chosenColor.hsl.hue,
                  saturation: 1.0,
                  lightness: CGFloat($0) / HSLSliderView.spectrumCeiling,
                  opacity: 1.0)
        }
    }
}

struct LightnessPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LightnessSliderView(chosenColor: Binding.constant(Color.green),
                            graph: .createEmpty())

            .rotation3DEffect(Angle(degrees: -90),
                              axis: (x: 0.0, y: 1.0, z: 90.0))
            .scaleEffect(5)
    }
}
