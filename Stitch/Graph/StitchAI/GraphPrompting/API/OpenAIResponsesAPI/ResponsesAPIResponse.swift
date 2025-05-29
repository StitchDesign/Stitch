//
//  ResponsesAPIResponse.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/28/25.
//

import Foundation
import SwiftUI


// MARK: models for receiving a streamed-chunk from OpenAI's Responses API

/// Streams tokens (plus reasoning) from the Responses API.

struct SSEType: Codable {
    let type: String
}

/// {"type":"response.created", …}
struct ResponseCreated: Codable, Equatable, Hashable {
    var sequenceNumber: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
    }
}

/// {"type":"response.in_progress", …}
struct ResponseInProgress: Codable, Equatable, Hashable {
    var sequenceNumber: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
    }
}

/// {"type":"response.output_item.added", …}
struct ResponseOutputItemAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
    }
}

/// {"type":"response.content_part.added", …}
struct ResponseContentPartAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
    }
}

/// {"type":"response.output_text.delta", …}
struct ResponseOutputTextDelta: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var delta: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

/// {"type":"response.reasoning_summary_text.delta", …}
struct ResponseReasoningSummaryTextDelta: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int
    var delta: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
        case delta
    }
}

/// {"type":"response.reasoning_summary_text.done", …}
struct ResponseReasoningSummaryTextDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int
    // no `delta` here since it's a “done” marker

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.reasoning_summary_part.added", …}
struct ResponseReasoningSummaryPartAdded: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.reasoning_summary_part.done", …}
struct ResponseReasoningSummaryPartDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var summaryIndex: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case summaryIndex = "summary_index"
    }
}

/// {"type":"response.output_item.done", …}
struct ResponseOutputItemDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var outputIndex: Int
    var item: OutputItemDoneItem

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
        case item
    }
}

struct OutputItemDoneItem: Codable, Equatable, Hashable {
    var id: String
    var type: String
    var summary: [SummaryText]

    enum CodingKeys: String, CodingKey {
        case id, type, summary
    }
}

struct SummaryText: Codable, Equatable, Hashable {
    var type: String
    var text: String

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}

/// {"type":"response.output_text.done", …}
struct ResponseOutputTextDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var text: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case text
    }
}

/// {"type":"response.content_part.done", …}
struct ResponseContentPartDone: Codable, Equatable, Hashable {
    var sequenceNumber: Int
    var itemId: String
    var outputIndex: Int
    var contentIndex: Int
    var part: ContentPart

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
    }
}

struct ContentPart: Codable, Equatable, Hashable {
    var type: String
    var annotations: [String]  // or a more specific type if known
    var text: String

    enum CodingKeys: String, CodingKey {
        case type, annotations, text
    }
}
