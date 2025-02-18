//
//  OpenAIRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI

protocol OpenAIRequestable: Encodable {
    associatedtype FormatType: OpenAIResponseFormatable
    
    var model: String { get }
    var n: Int { get }
    var temperature: Double { get }
    var response_format: FormatType { get }
}

protocol OpenAIResponseFormatable: Encodable {
    associatedtype JsonSchema: OpenAIJsonSchema
    
    var type: String { get }
    var json_schema: JsonSchema { get }
}

protocol OpenAIJsonSchema: Encodable {
    associatedtype Schema: Encodable
    
    var name: String { get }
    var schema: Schema { get }
}

struct OpenAIMessage: Codable {
    let role: OpenAIRole
    let content: String
}

enum OpenAIRole: String, Codable {
    case system
    case assistant
    case user
}
