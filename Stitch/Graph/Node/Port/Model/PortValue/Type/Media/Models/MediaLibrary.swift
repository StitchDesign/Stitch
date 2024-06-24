//
//  MediaLibrary.swift
//  prototype
//
//  Created by Christian J Clampitt on 9/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias MediaLibrary = [MediaKey: URL]

extension MediaLibrary {
    static func getDefaultLibraryDeps() -> [URL] {
        DefaultMediaOption.allCases.map { $0.url }
    }

    static func getAllDefaultMediaKeys() -> [MediaKey] {
        Self.getDefaultLibraryDeps().map { $0.mediaKey }
    }
}
