//
//  RestrictedSwiftUIScopeJSON.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/20/25.
//

import Foundation


let restrictedScopeSwiftUIJSON = """
{
  "inputs" : {
    "Blend Mode" : ".blendMode",
    "Blur" : ".blur",
    "Blur Radius" : ".blur",
    "Brightness" : ".brightness",
    "Clipped" : ".clipped",
    "Color" : {
      "Rectangle" : ".fill",
      "Oval"      : ".fill",
      "Text"      : ".foregroundColor"
    },
    "Color Invert" : ".colorInvert",
    "Contrast" : ".contrast",
    "Corner Radius" : ".cornerRadius",
    "Hue Rotation" : ".hueRotation",
    "Opacity" : ".opacity",
    "Padding" : ".padding",
    "Position" : ".position",
    "Saturation" : ".saturation",
    "Scale" : ".scaleEffect",
    "Size" : ".frame",
    "Z Index" : ".zIndex"
  },
  "layers" : {
    "Oval" : "Ellipse",
    "Rectangle" : "Rectangle",
    "Text" : "Text"
  }
}
"""
