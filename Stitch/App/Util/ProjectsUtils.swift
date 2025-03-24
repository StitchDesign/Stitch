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
let isPhoneDevice = UIDevice.current.userInterfaceIdiom == .phone

enum SampleApp: String, CaseIterable {
    case MusicPlayer = "Music Player"
    case MicRecorder = "Microphone Recorder"
}
