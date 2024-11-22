//
//  PreviewUtils.swift
//  prototype
//
//  Created by Elliot Boschwitz on 4/6/22.
//

import SwiftUI
import StitchSchemaKit

#if DEV_DEBUG
let defaultOpacityNumber = 0.9
#else
let defaultOpacityNumber = 1.0
#endif

let defaultOpacity: PortValue = .number(defaultOpacityNumber)

let defaultScaleNumber = 1.0

let defaultImageSize = CGSize(width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width, height: 200).toLayerSize
