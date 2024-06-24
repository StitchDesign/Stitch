import SwiftUI

struct HueSliderView: View {
    @Binding var chosenColor: Color
    let graph: GraphState

    var body: some View {
        HSLSliderView(chosenColor: $chosenColor,
                      sliderColors: hueSliderColors,
                      graph: graph) { color, gestureProgress in
            HSLColor(hue: gestureProgress,
                     saturation: color.saturation,
                     lightness: color.lightness,
                     alpha: color.alpha)
                .toColor
        } bubbleUpdate: { color in
            log("HuePickerView: bubbleUpdate: color.hue: \(color.hue)")
            let newPosition = Stitch.transition(
                color.hue,
                start: 0,
                end: HSLSliderView.sliderGradientHeight - HSLSliderView.circleWidth)
            log("HuePickerView: bubbleUpdate: newPosition: \(newPosition)")
            return newPosition
        }
    }

    // Colors for displayin the slider
    var hueSliderColors: [Color] {
        HSLSliderView.spectrumRange.map {
            Color(hue: CGFloat($0) / HSLSliderView.spectrumCeiling,
                  saturation: 1.0,
                  lightness: 0.5, // 0.5 lightness is full color
                  opacity: 1.0)
        }
    }

}

struct ColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        HueSliderView(chosenColor: Binding.constant(Color.orange),
                      graph: .init(id: .init(), store: nil))
    }
}
