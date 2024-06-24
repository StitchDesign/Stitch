//
//  JustifiedLayerTextView.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/3/22.
//

import SwiftUI
import StitchSchemaKit

// SwiftUI does not (yet) support justified text
struct JustifiedLayerTextView: UIViewRepresentable {
    let text: String
    let color: Color
    let font: UIFont

    var uiColor: UIColor {
        UIColor(color)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.textAlignment = .justified
        textView.text = text
        textView.textColor = uiColor
        textView.backgroundColor = .clear
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.textColor = uiColor
        uiView.font = font
    }
}
