//
//  SaturationPickerview.swift
//  whatever
//
//  Created by Christian J Clampitt on 10/26/23.
//

import SwiftUI
import StitchSchemaKit

struct SaturationSliderView: View {

    // binding passed down from parent; represents color that user actually sees
    @Binding var chosenColor: Color
    let graph: GraphState

    var body: some View {
        saturationSlider
    }

    var saturationSlider: some View {
        HSLSliderView(chosenColor: $chosenColor,
                      sliderColors: saturationSliderColors,
                      graph: graph) { color, progress in
            HSLColor(hue: color.hue,
                     // NEVER allow .zero for saturation or lightness; causes hue to shift to red
                     saturation: max(0.00001, progress),
                     lightness: color.lightness,
                     alpha: color.alpha)
                .toColor

        } bubbleUpdate: { color in
            var newPosition = Stitch.transition(
                color.saturation,
                start: 0,
                end: HSLSliderView.sliderGradientHeight - HSLSliderView.circleWidth)
            return newPosition
        }
    }

    // saturation slider should use current hue
    var saturationSliderColors: [Color] {
        HSLSliderView.spectrumRange.map {
            Color(hue: chosenColor.hsl.hue,
                  saturation: CGFloat($0) / HSLSliderView.spectrumCeiling,
                  lightness: 0.5, // 0.5 lightness is full color
                  opacity: 1.0)
        }
    }
}

struct SaturationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        SaturationSliderView(chosenColor: Binding.constant(Color.blue),
                             graph: .createEmpty())
            .rotation3DEffect(Angle(degrees: -90),
                              axis: (x: 0.0, y: 1.0, z: 90.0))
            .scaleEffect(5)
    }
}
