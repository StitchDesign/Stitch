//
//  StitchAIRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIRequestBodyFormattable_V0 {
    protocol StitchAIRequestBodyFormattable: Encodable {
        associatedtype ResponseFormat: Encodable
        
        var model: String { get }
        var n: Int { get }
        var temperature: Double { get }
        var response_format: ResponseFormat { get }
        var messages: [OpenAIMessage] { get }
        var stream: Bool { get }
    }
}
