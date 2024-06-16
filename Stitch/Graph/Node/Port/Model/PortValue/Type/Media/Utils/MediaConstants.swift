//
//  MediaConstants.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/20/21.
//

import AVFoundation
import Foundation
import StitchSchemaKit
import SwiftUI
import Vision

// MARK: - MISC
let IMPORT_BUTTON_DISPLAY = "Import"
let IMPORT_BUTTON_ID = UUID()
let MEDIA_EMPTY_ID = UUID()
let MEDIA_EMPTY_NAME = "None"
let MEDIA_INPUT_INDEX_IMPORT = 0

// MARK: - IMAGE

let IMAGE_EMPTY = UIImage(named: "nilImage")!

// MARK: - VIDEO

let VIDEO_INPUT_INDEX_SCRUBTIME = 2

// MARK: - CORE ML CLASSIFICATION

let MOBILENETV2_STRING = "MobileNetV2"

let RESNET50_STRING = "Resnet50"

let SQUEEZENET_STRING = "SqueezeNet"

let CORE_ML_NO_RESULTS = "No Results"

enum DefaultMediaOption: CaseIterable {
    case model3dToyRobot
    case imageClassifierResnet
    case objectDetectionYolo
}

extension DefaultMediaOption {    
    var url: URL {
        switch self {
        case .model3dToyRobot:
            return default3DModelToyRobotAsset
        case .imageClassifierResnet:
            return CORE_ML_CLASSIFICATION_RESNET50_URL
        case .objectDetectionYolo:
            return CORE_ML_DETECTION_DEFAULT_URL
        }
    }
    
    var name: String {
        switch self {
        case .model3dToyRobot:
            return "Vintage Toy Robot"
        case .imageClassifierResnet:
            return RESNET50_STRING
        case .objectDetectionYolo:
            return YOLOv3TINY_STRING
        }
    }
    
    var mediaKey: MediaKey {
        self.url.mediaKey
    }
    
    static func getDefaultOptions(for nodeKind: NodeKind,
                                  isMediaCurrentlySelected: Bool) -> [FieldValueMedia] {
        
        switch nodeKind.mediaType {
            
        case .coreML:
            guard let patch = nodeKind.getPatch else {
                // Only patch nodes have default media options for coreML media-type
                return [.none]
            }
            
            switch patch {
            case .coreMLClassify:
                return [isMediaCurrentlySelected ? .none : .defaultMedia(.imageClassifierResnet)]
            case .coreMLDetection:
                return [isMediaCurrentlySelected ? .none : .defaultMedia(.objectDetectionYolo)]
            default:
                return []
            }
            
        case .model3D:
            return [isMediaCurrentlySelected ? .none : .defaultMedia(.model3dToyRobot)]
            
        default:
            return [.none]
        }
    }
}

let CORE_ML_CLASSIFICATION_RESNET50_URL: URL = Resnet50.urlOfModelInThisBundle

// MARK: - CORE ML DETECTION

let YOLOv3TINY_STRING = "YOLOv3Tiny"

let CORE_ML_DETECTION_DEFAULT_URL: URL = YOLOv3Tiny.urlOfModelInThisBundle

// let CORE_ML_CLASSIFICATION_SQUEEZENET_URL: URL = SqueezeNet.urlOfModelInThisBundle

// MARK: - 3D MODEL

let default3DModelSize = CGSize(width: 250, height: 250).toLayerSize

// MARK: - CAMERA
let CAMERA_FEED_MEDIA_TYPE = AVMediaType.video
let CAMERA_DESCRIPTION = "Camera"
