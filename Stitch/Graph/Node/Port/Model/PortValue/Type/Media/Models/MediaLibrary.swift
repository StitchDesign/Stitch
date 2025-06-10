//
//  MediaLibrary.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias MediaLibrary = [MediaKey: URL]

extension MediaLibrary {
    
    // TODO: JUNE 9: how to handle media defaults in StitchAppClip ?
    static func getDefaultLibraryDeps() -> [URL] {
        // DefaultMediaOption.allCases.map { $0.url }
        []
    }

    static func getAllDefaultMediaKeys() -> [MediaKey] {
        // Self.getDefaultLibraryDeps().map { $0.mediaKey }
        []
    }
}
