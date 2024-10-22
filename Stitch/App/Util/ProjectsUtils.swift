//
//  ProjectsUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/14/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit


@MainActor
func isPhoneDevice() -> Bool {
    let k = UIDevice.current.userInterfaceIdiom == .phone
    log("isPhoneDevice: \(k)")
    return k
}

func isMac() -> Bool {
    #if targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
}

enum SampleApp: String, CaseIterable {
    case MusicPlayer = "Music Player"
    case MicRecorder = "Microphone Recorder"
}
