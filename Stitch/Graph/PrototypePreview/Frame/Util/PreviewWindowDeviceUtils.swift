//
//  PreviewWindowDevice.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/20/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let PREVIEW_WINDOW_MIN_DIMENSION: CGFloat = 200

// Right-hand side padding for preview window
// TODO: previously was -20 and -38; where does this value come from?
let PREVIEW_WINDOW_PADDING: Double = -16

extension CGSize {
    static let defaultPreviewWindowDeviceSize = PreviewWindowDevice.defaultPreviewWindowDeviceSize
}

/// The device the preview window is emulating, e.g. iPhone 14.
/// Differs from the user's device, i.e. the device on which Stitch is running (e.g. MacBook Air).
typealias PreviewWindowDevice = PreviewSize

extension PreviewWindowDevice {
    static let defaultPreviewWindowDevice = DEFAULT_PREVIEW_OPTION
    static let defaultPreviewWindowDeviceSize = DEFAULT_PREVIEW_SIZE
    
    static let allPreviewDeviceSizes = PreviewWindowDevice.allCases
        .filter { $0 != .custom }
        .map { $0.previewWindowDimensions }
    
    static let DEFAULT_PREVIEW_OPTION: PreviewWindowDevice = PreviewWindowDevice.defaultOption

    static let DEFAULT_PREVIEW_SIZE: CGSize = DEFAULT_PREVIEW_OPTION.previewWindowDimensions
    
    // Source: https://blisk.io/devices
    var previewWindowDimensions: CGSize {
        switch self {
        // iPhones
        case .iPhone14Pro:
            return CGSize(width: 393, height: 852)
        case .iPhone14ProMax:
            return CGSize(width: 430, height: 932)
        case .iPhone14, .iPhone13, .iPhone13Pro, .iPhone12, .iPhone12Pro:
            return StitchDocument.defaultPreviewWindowSize
        case .iPhone13mini, .iPhone12mini, .iPhone11Pro:
            return CGSize(width: 375, height: 812)
        case .iPhone14Plus, .iPhone13ProMax, .iPhone12ProMax:
            return CGSize(width: 428, height: 926)
        case .iPhoneSe2ndGen:
            return CGSize(width: 375, height: 667)
        case .iPhone11, .iPhone11ProMax:
            return CGSize(width: 414, height: 896)
        case .iPhoneSE1stGen:
            return CGSize(width: 320, height: 568)

        // iPads
        case .iPadMini6thGen:
            return CGSize(width: 744, height: 1133)
        case .iPad9thGen:
            return CGSize(width: 810, height: 1080)
        case .iPadPro12Inch:
            return CGSize(width: 1024, height: 1366)
        case .iPadPro11Inch:
            return CGSize(width: 834, height: 1194)
        case .iPadAir4thGen:
            return CGSize(width: 820, height: 1180)
        case .iPadMini5thGen:
            return CGSize(width: 768, height: 1024)
        case .iPadAir3rdGen, .iPadPro10Inch:
            return CGSize(width: 834, height: 1112)

        case .MacBookAir, .MacBookPro:
            return .init(width: 1440, height: 900)
        case .MacBook:
            return .init(width: 2304, height: 1440)

        case .iMacRetina24Inch:
            return .init(width: 2240, height: 1260)
        case .iMacRetina27Inch:
            return .init(width: 2560, height: 1440)
        case .iMacProRetina27Inch:
            return .init(width: 3200, height: 1800)

        case .custom:
            log("getPreviewWindowDeviceDimensions error: shouldn't be called on custom type.")
            #if DEV_DEBUG
            fatalError()
            #endif
            return Self.DEFAULT_PREVIEW_SIZE
        }
    }

    var isIPhone: Bool {
        switch self {
        case .iPhone14, .iPhone14Plus, .iPhone14Pro, .iPhone14ProMax, .iPhone13, .iPhone13mini, .iPhone13ProMax, .iPhone13Pro, .iPhone12, .iPhone12mini, .iPhone12ProMax, .iPhone12Pro, .iPhoneSe2ndGen, .iPhone11ProMax, .iPhone11Pro, .iPhone11, .iPhoneSE1stGen:
            return true
        default:
            return false
        }
    }

    var isIPad: Bool {
        switch self {
        case .iPadMini6thGen, .iPad9thGen, .iPadPro12Inch, .iPadPro11Inch, .iPadAir4thGen, .iPadMini5thGen, .iPadAir3rdGen, .iPadPro10Inch:
            return true
        default:
            return false
        }
    }

    var isMacBook: Bool {
        switch self {
        case .MacBook, .MacBookAir, .MacBookPro:
            return true
        default:
            return false
        }
    }

    var isIMac: Bool {
        switch self {
        case .iMacRetina24Inch, .iMacRetina27Inch, .iMacProRetina27Inch:
            return true
        default:
            return false
        }
    }
}

extension PreviewSize {
    public static let defaultOption = Self.iPhone14
}

func checkDimensionsMatchDevice(size: CGSize) -> PreviewWindowDevice {
    for previewSize in PreviewWindowDevice.allCases {
        if previewSize.previewWindowDimensions == size {
            return previewSize
        }
    }

    // Return custom size if no matching cases
    return .custom
}

/// Calculates scaling needed to fit preview in `GraphView`.
/// Rules:
/// 1. height can't be more than 66% of device pixels
/// 2. width can't be more than 25% of device pixels
func calcSmallPreviewWindowScale(previewSize: CGSize,
                                 deviceSize: CGSize) -> Double {

    let previewHeightRatio = previewSize.height / deviceSize.height
    let previewWidthRatio = previewSize.width / deviceSize.width
    let maxOffsetNeeded = max(previewHeightRatio / 0.66, previewWidthRatio / 0.25)
    let scale = Double(1 / maxOffsetNeeded)

    // We must round the scale's decimal places to the number of digits
    // within our (assumed to be integer) device screen size (whichever screen size dimension is smaller).
    return adjustPreviewWindowScale(deviceSize: deviceSize,
                                    scale: scale)
}


// Returns dimensions for minimized preview window
func getSmallPreviewWindowSize(windowSize: CGSize,
                               scale: Double) -> CGSize {
    let fullWidth: Double = scale * windowSize.width
    let fullHeight: Double = scale * windowSize.height
    return CGSize(width: fullWidth, height: fullHeight)
}

// Returns scaling needed for full screen preview (except for iPhone scenario)
func calcFullPreviewWindowScale(windowSize: CGSize, deviceSize: CGSize) -> Double {
    let widthScale = deviceSize.width / windowSize.width
    let heightScale = deviceSize.height / windowSize.height
    let scale = min(widthScale, heightScale)
    return adjustPreviewWindowScale(deviceSize: deviceSize,
                                    scale: scale)
}

// We use string formatting since even a "rounded" Swift Double can have additional e.g. 0001 in the decimal places.
// See this comment:
// https://stackoverflow.com/questions/27338573/rounding-a-double-value-to-x-number-of-decimal-places-in-swift#comment63932736_32581409
func adjustPreviewWindowScale(deviceSize: CGSize,
                              scale: Double) -> Double {

    // We must round the scale's decimal places to the number of digits
    // within our (assumed to be integer) device screen size (whichever screen size dimension is smaller).
    let smallestDeviceScreenDimension: Int = Int(min(deviceSize.width, deviceSize.height))
    let places = String(smallestDeviceScreenDimension).count

    let formatString = "%.\(places)f"
    let formatted = String(format: formatString, scale)

    //    log("adjustPreviewWindowScale: scale: \(scale)")
    //    log("adjustPreviewWindowScale: smallestDeviceScreenDimension: \(smallestDeviceScreenDimension)")
    //    log("adjustPreviewWindowScale: formatString: \(formatString)")
    //    log("adjustPreviewWindowScale: formatted: \(formatted)")
    //    log("adjustPreviewWindowScale: places: \(places)")

    if let adjustedScale = Double(formatted) {
        //        log("adjustPreviewWindowScale: adjustedScale: \(adjustedScale)")
        return adjustedScale
    } else {
        log("adjustPreviewWindowScale: could not create double from formatted string: \(formatted)")
        return scale
    }
}
