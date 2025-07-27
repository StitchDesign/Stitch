//
//  AICodeGenRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import Foundation

//struct AICodeGenFromImageInputs: Codable {
//    let user_prompt: String
//    let image_data: OpenAIUserImageContent
//}

struct OpenAIUserTextContent: Encodable {
    let type = "text"
    let text: String
}

struct OpenAIUserImageContent: Encodable {
    var type = "image_url"
    var image_url: OpenAIImageUrl
    
    init(base64Image: String) {
        self.image_url = .init(base64Image: base64Image)
    }
}

struct OpenAIImageUrl {
    let base64Image: String
    var detail = "high"
}

extension OpenAIImageUrl: Encodable {
    enum CodingKeys: String, CodingKey {
        case url
        case detail
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let urlString = "data:image/jpeg;base64,\(base64Image)"
        try container.encode(urlString, forKey: .url)
        try container.encode(self.detail, forKey: .detail)
    }
    
//    init(from decoder: any Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let decodedString = try container.decode(String.self, forKey: .url)
//        self.base64Image = String(decodedString.dropFirst("data:image/jpeg;base64,".count))
//        self.detail = try container.decode(String.self, forKey: .detail)
//    }
}


// MARK: - old way
enum OpenAIMessageContent: Encodable {
    case text(String)
    case image(url: String, detail: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
            
        case .image(let url, let detail):
            try container.encode("image_url", forKey: .type)
            try container.encode(["url": url, "detail": detail], forKey: .imageURL)
        }
    }
}
