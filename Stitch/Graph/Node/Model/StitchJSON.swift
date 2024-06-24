//
//  StitchJSON.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/26/23.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

extension JSON {
    var toStitchJSON: StitchJSON {
        .init(self)
    }
}

extension StitchJSON {
    // When displaying the JSON to the user,
    // we want to both pretty-print AND remove escaping slashes;
    // SwiftyJSON's .description normallly only pretty-prints.
    var display: String {
        self.value.descriptionWithoutEscapingSlashes
    }
}

extension JSON {
    var descriptionWithoutEscapingSlashes: String {
        self.rawString(options: [.withoutEscapingSlashes, .prettyPrinted]) ?? self.description
    }
}

func manyJSONS(_ json: JSON = validSimpleJSON, count: Int = 8000) -> [JSON] {
    Array.init(repeating: json,
               count: count)
}

func manyStitchJSONS(_ json: JSON = validSimpleJSON) -> [StitchJSON] {
    manyJSONS(json).map(StitchJSON.init)
}
