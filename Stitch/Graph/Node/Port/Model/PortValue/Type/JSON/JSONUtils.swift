//
//  UserJSON.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/9/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

extension JSON {
    func isEqualTo(_ other: JSON) -> Bool {
        areEqualJsons(self, other)
    }
    
    static let emptyJSONArray: Self = Stitch.emptyJSONArray
    static let emptyJSONObject: Self = Stitch.emptyJSONObject
}

extension PortValue {
    init(_ json: JSON) {
        self = .json(json.toStitchJSON)
    }
}

extension StitchJSON {
    static let emptyJSONArray: Self = Stitch.emptyStitchJSONArray
    static let emptyJSONObject: Self = Stitch.emptyStitchJSONObject
}

// We need special logic for handling empty JSONs new-line characters which appear to be inserted by SwiftyJSONs pretty-printing etc.
func areEqualJsons(_ json1: JSON,
                   _ json2: JSON) -> Bool {

    // Compare JSONs slightly differently, since a pretty-printed "{ \n \n }" is technically an empty JSON but will not match to "{}" without trimming.
    let trimmedJson1 = json1.description
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let trimmedJson2 = json2.description
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedJson1 == jsonDefaultRaw,
       trimmedJson2 == jsonDefaultRaw {
        return true
    } else {
        return json1 == json2
    }
}

func isJSONFormatted(_ jsonString: String) -> Bool {

    if let data = jsonString.data(using: .utf8,
                                  allowLossyConversion: false) {
        let json = JSON(data)
        // if the created json is non-null, then it was validly formatted.
        return !isNullJSON(json)
    }
    return false
}

/*
 TODO:
 - clean this up; what is its purpose and can it be replaced with SwiftyJSON's `JSON(parseJSON:)` ?
 - return `Result<JSON, Error>`, not `JSON?` ... does `myString.data(using:)` return an informative error?
 */
func parseJSON(_ jsonString: String) -> JSON? {

    //    #if DEV_DEBUG
    //    log("parseJSON: jsonString: \(jsonString)")
    //    #endif

    // Create Data from string
    if let data = jsonString.data(using: .utf8,
                                  allowLossyConversion: false) {
        return data.toJSON
    } else {
        #if DEV_DEBUG
        log("parseJSON: failed to create json from jsonString")
        #endif
        return nil
    }
}

func getValueAtKey(_ json: JSON, _ key: String) -> JSON? {
    let x = json[key]
    return isNullJSON(x) ? nil : x
}

extension Data {
    var toJSON: JSON? {
        let json = JSON(self)

        // If created-JSON is empty, then the JSON was improperly formatted.
        if isNullJSON(json) {
            //            #if DEV_DEBUG
            //            log("Data.toJSON: data json was null")
            //            #endif
            return nil
        }

        //        #if DEV_DEBUG
        //        log("Data.toJSON: success?: \(json)")
        //        #endif
        return json
    }

    var toJSONResult: Result<JSON, Error> {
        self.toJSON.toJSONResult
    }

    func printJson() {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .prettyPrinted])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("Inavlid data")
                return
            }
            print(jsonString)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}

// Lift a `JSON?` into a Result
extension Optional where Wrapped == JSON {
    var toJSONResult: Result<JSON, Error> {
        self.map { Result.success($0)  } ?? .failure(SwiftyJSONError.invalidJSON)
    }
}

func isNullJSON(_ json: JSON) -> Bool {
    // If null is present, then the json is a null json.
    // Null jsons come from improper formatting or key path failures.
    json.null != nil
}

func getValueAtIndex(_ json: JSON, _ index: Int) -> JSON? {
    let x = json[index]
    return isNullJSON(x) ? nil : x
}

extension JSONFriendlyFormat {

    func setInJSON(_ json: JSON, index: Int) -> JSON {
        var json = json
        switch self {
        case .string(let x):
            json[index].string = x
        case .number(let x):
            json[index].double = x
        case .dictionary(let x):
            json[index].dictionaryObject = x
        case .json(let x):
            json[index] = x
        }
        return json
    }

    func setInJSON(_ json: JSON, key: String) -> JSON {
        guard !key.isEmpty else {
            return json
        }

        // Keypath lets us set a value at a nested key
        let keyPath = key.asJSONKeyPath

        var json = json

        switch self {
        case .string(let x):
            json[keyPath].string = x
        case .number(let x):
            json[keyPath].double = x
        case .dictionary(let x):
            json[keyPath].dictionaryObject = x
        case .json(let x):
            json[keyPath] = x
        }

        return json
    }
    
    @MainActor
    init(value: PortValue) {
        switch value {

        case .number(let x):
            self = .number(x)

        // Swift `struct`s are turned into dictionaries.
        case .size(let x):
            self = .dictionary(x.asAlgebraicCGSize.asDictionary)
        case .position(let x):
            self = .dictionary(x.asDictionary)
        case .point3D(let x):
            self = .dictionary(x.asDictionary)
        case .point4D(let x):
            self = .dictionary(x.asDictionary)

        // Don't need to clean the json anymore?
        case .json(let x):
            self = .json(x.value)
            
        // Vast majority of PortValues can be treated as strings
        default:
            self = .string(value.display)
        }
    }
}

extension JSON {
    @MainActor
    init(key: String,
         value: PortValue) {
        
        // log("JSONObjectFromKeyAndValue: key: \(key)")
        // log("JSONObjectFromKeyAndValue: value: \(value)")
        
        var j = JSON()
        switch JSONFriendlyFormat(value: value) {
        case .string(let x):
            //        log("JSONObjectFromKeyAndValue: string: x: \(x)")
            j[key].string = x
        case .number(let x):
            j[key].double = x
        case .dictionary(let x):
            //        log("JSONObjectFromKeyAndValue: dictionary: x: \(x)")
            j[key].dictionaryObject = x
        case .json(let x): // cleaned json
            //        log("JSONObjectFromKeyAndValue: json: x: \(x)")
            // Works just if the JSON was cleaned already
            j[key] = x
        }
        
        self = j
    }
}

extension JSON {
    // TODO: should fail if json is not array?
    @MainActor
    func setValueForKey(_ key: String,
                        _ value: PortValue) -> JSON {
        let json = self
        
        guard !key.isEmpty else {
            return json
        }
        
        return value.createJSONFormat().setInJSON(json, key: key)
    }
    
    // Works for existing keypaths, but fails for non-existing keypaths.
    // Need to create each nested key, and then at the end, add the value?
    
    // NOTE: `keyPath` should be passed in as a raw string,
    // which is then parsed into [JSONSubscriptType];
    // otherwise our keyPath can't contain numbers for accessing array indices etc.
    
    // Returns nil if `json` is not a json array
    @MainActor
    func appendToJSONArray(_ value: PortValue) -> JSON? {
        let json = self
        
        //    #if DEV_DEBUG
        //    log("appendToJSONArray: json: \(json)")
        //    log("appendToJSONArray: value: \(value)")
        //    log("appendToJSONArray: value.display: \(value.display)")
        //    log("appendToJSONArray: value.toJSONFormat: \(value.toJSONFormat)")
        //    #endif
        
        // https://stackoverflow.com/a/42799147
        
        // SwiftyJSON's .merged method expects a json,
        // so we create a fake json, an array whose first index is our value
        return try? json.merged(with: value
            .createJSONFormat()
            .setInJSON(JSON(["a"]), index: 0))
    }
    
    // instead of creating a new string and then re-parsing as json,
    @MainActor
    static func jsonObjectFromKeyAndValue(_ key: String,
                                          _ value: PortValue) -> JSON {
        .init(key: key,
              value: value)
    }

    // careful how 'JSON Array' actually works: it makes each separate input an item in the array,
    // and takes only the first value from a loop in its input.
    // But can output a loop of json arrays
    @MainActor
    static func jsonArrayFromValues(_ values: PortValues) -> JSON {
        
        // We must create a 'dummy' json array,
        // so that we can insert into already-existing indices.
        // SwiftyJSON's array appending etc. methods otherwise expect another json.
        var jsonArray = JSON(Array.init(
            repeating: "a",
            count: values.indices.count))
        
        //    log("JSONArrayFromValues: jsonArray START: \(jsonArray)")
        
        let vals = values.map { $0.createJSONFormat() }
        
        //    log("JSONArrayFromValues: vals: \(vals)")
        
        vals.enumerated().forEach { x in
            //        log("JSONArrayFromValues: x: \(x)")
            jsonArray = x.element.setInJSON(
                jsonArray,
                index: x.offset)
        }
        
        //    log("JSONArrayFromValues: jsonArray END: \(jsonArray)")
        
        return jsonArray
    }
}


/*
 Turns json array into loop of .json type portvalues.

 When 'Loop Over Array' receives a loop of json arrays,
 it actually only always takes the first json in the loop,
 and ignores the rest.
 */
func JSONArrayToLoops(_ json: JSON) -> (PortValues, PortValues) {
    var valuesLoop: PortValues = json.map { .json($0.1.toStitchJSON) }

    // `JSON.map` treats an empty JSON as an empty list,
    // in which case we want to add a 'default, empty' JSON again.
    if valuesLoop.isEmpty {
        valuesLoop.append(.json(emptyStitchJSONArray))
    }
    return (valuesLoop.asLoopIndices,
            valuesLoop)
}

func getCleanedJSON(_ s: String) -> JSON? {

    // see this discussion: https://developer.apple.com/forums/thread/124410

    // Swit bug?!: replacingOccurrences for smart quotes only seems to work once per call; thus the need to call
    // TODO: research this more, whether this is a genuine bug
    // WORKAROUND?: count the number of smart quotes in the string, and reduce on that until you've replaced every string

    // LONGER TERM SOLUTION IS TO DISABLE SMART QUOTES ON THE TEXT EDITING INTERFACE ITSELF, if possible
    let cleanedS = s
        .replacingOccurrences(of: "“", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")

    //    log("cleanedS: \(cleanedS)")
    return parseJSON(cleanedS)
}

func arrayJoin(_ json1: JSON, _ json2: JSON) -> JSON {

    guard let a1 = json1.array,
          let a2 = json2.array else {

        //        log("arrayJoin: did not have two json arrays")

        // If we don't have to JSON arrays,
        // then return whichever input was an array;
        // else return empty JSON array.
        if json1.array.isDefined {
            return json1
        } else if json2.array.isDefined {
            return json2
        } else {
            return .emptyJSONArray
        }
    }

    if let joined = JSON(rawValue: a1 + a2) {
        //        log("arrayJoin: joined: \(joined)")
        return joined
    } else {
        //        log("arrayJoin: failed to join two json arrays")
        return .emptyJSONArray
    }
}

func arrayReverse(_ json: JSON) -> JSON {
    if var a = json.array {
        a.reverse()
        return JSON(rawValue: a) ?? .emptyJSONArray
    }
    return json
}

// Note: only sorts by numbers ?
func arraySort(_ json: JSON, ascending: Bool = true) -> JSON {
    if let a = json.array {
        let sa = a.sorted { x, y in
            ascending ? x < y : x > y
        }
        return JSON(rawValue: sa) ?? .emptyJSONArray
    }
    return json
}

// takes a json object; returns a json array of that object's keys
func jsonKeys(_ json: JSON) -> JSON {
    if let d = json.dictionary {
        let ks = d.keys
        let ksa = Array(ks)
        return JSON(rawValue: ksa) ?? .emptyJSONArray

    }
    return .emptyJSONArray
}

// returns `(index, contains)`
// (index is -1 if the item doesn't exist)
// Note: `item` should be some `PortValue.display`
func indexOf(_ json: JSON, item: String) -> (Int, Bool) {
    if let a = json.array {
        //            // TODO: why don't k and k2 work?
        // // let ji = JSON(rawValue: item)!
        //            if let k1 = a.firstIndex(of: ji) {
        //                return (Int(k1), true)
        //            } else if let k2 = a.firstIndex(where: { $0 == ji }) {
        //                return (Int(k2), true)
        //            }

        // TODO: might need better logic here; currently you're comparing the string-version of the JSON to the string-version of the PortValue
        if let k = a.firstIndex(where: { $0.description == item }) {
            return (Int(k), true)
        }
    }

    return (-1, false)
}

func jsonSubarray(_ json: JSON,
                  location: Int,
                  length: Int) -> JSON {

    guard let a = json.array else {
        return .emptyJSONArray
    }

    // Easy cases:
    //    let location = 0
    //    let length = 3 // 1 // 2 // works

    // // crashes from bad length: FIXED
    //                let location = 0
    //                let length = 9

    // // crashes from bad location: FIXED
    //        let location = 9
    //        let length = 1

    let asJson = { (sub: Array<JSON>.SubSequence) in
        JSON(rawValue: Array(sub)) ?? JSON.emptyJSONArray
    }

    // if location is greater than array count,
    // then just return last item:
    if location > a.count {
        return a.last.map { asJson([$0]) } ?? JSON.emptyJSONArray
    }

    // location + length is greater than count,
    // just take from location to the end:
    if ((location + length) > a.count)
        // Another case:
        || (location >= (location + length - 1)) {
        return asJson(a[location..<a.endIndex])
    }

    let sub = a[location...(location + length - 1)]
    return asJson(sub)
}

extension [JSON] {
    var flatten: JSON {
        self.reduce(JSON([])) { partialResult, json in
            (try? partialResult.merged(with: [json])) ?? partialResult
        }
    }

    // this is part of Shape -> JSON
    // we know the expected Shape, build it as the darta you need,
    // and THEN at the end turn into into a SwiftyJSON
    // ... test this out too.
    var mergedIntoPath: JSON {
        let mergedPaths: JSON = self.reduce(JSON.emptyJSONArray, { partialResult, json in
            (try? partialResult.merged(with: json[JSONShapeKeys.PATH])) ?? partialResult
        })
        var json = JSON()
        json[JSONShapeKeys.PATH] = mergedPaths
        return json
    }
}

func getValueAtKeyPath(_ json: JSON,
                       _ keyPathAsString: String) -> JSON {
    keyPathAsString
        .asRecursiveKeyPath
        .map { findKeyInJson(json, $0).flatten }
        ?? json[keyPathAsString.asJSONKeyPath]
}

func findKeyInJson(_ json: JSON, _ key: String) -> [JSON] {
    var result: [JSON] = .init()

    json.forEach({ (s: String, j: JSON) in
        // s is key if json is object, or index if json is array
        if s == key {
            result.append(j)
        }
        result += findKeyInJson(j, key)
    })

    return result
}

extension String {
    // A keypath like "..someKey" is a recursive search for "someKey"
    var asRecursiveKeyPath: String? {
        if self.prefix(2) == "..", self.count > 2 {
            return String(self.dropFirst(2))
        }
        return nil
    }

    var asJSONKeyPath: [JSONSubscriptType] {
        self.components(separatedBy: ".")
            .map { (s: String) -> JSONSubscriptType in
                toNumberBasic(s).map(Int.init) ?? s
            }
    }
}

// Displaying PortValues' types and values
extension JSON {
    var toStitchPosition: StitchPosition? {
        if let x = self.caseInsensitiveX,
           let y = self.caseInsensitiveY {
            return .init(width: x, height: y)
        }
        return nil
    }

    var toSize: CGSize? {
        if let width = self["width"].double,
           let height = self["height"].double {
            return .init(width: width, height: height)
        }
        return nil
    }

    var toPoint3D: Point3D? {
        if let x = self.caseInsensitiveX,
           let y = self.caseInsensitiveY,
           let z = self.caseInsensitiveZ {
            return .init(x: x, y: y, z: z)
        }
        return nil
    }

    var toPoint4D: Point4D? {
        if let x = self.caseInsensitiveX,
           let y = self.caseInsensitiveY,
           let z = self.caseInsensitiveZ,
           let w = self.caseInsensitiveW {
            return .init(x: x, y: y, z: z, w: w)
        }
        return nil
    }
}

// Needs to be decodable too
//enum JSONFriendlyFormat: Encodable, Equatable {
enum JSONFriendlyFormat: Encodable, Decodable, Equatable {
    case string(String),
         number(Double),
         dictionary([String: Double]),
         json(JSON) // already a json

    var jsonWrapper: JSON {
        self.setInJSON(JSON(["a"]), index: 0)
    }

    func encode(to encoder: Encoder) throws {
        // Very important to use a single value container
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .number(let n):
            try container.encode(n)
        case .dictionary(let d):
            try container.encode(d)
        case .json(let j):
            try container.encode(j)
        }
    }
}

extension ShapeCommand {

    var asJSON: JSON? {
        if let encoded = try? JSONEncoder().encode(self),
           let json = try? JSON(data: encoded) {
            return json
        }
        return nil
    }

    // TODO: need a better way to turn these into strings?
    // TODO: what are perf costs here?
    var display: String {
        self.asJSON?.description ?? self.asDictionaryString
    }

    // A string, since otherwise
    // ends up as a heterogenous-value dictionary;
    // TODO: handle this better?
    var asDictionaryString: String {
        switch self {
        case .closePath:
            return JSONShapeKeys.CLOSE_PATH
        case .lineTo(let x):
            return [
                "type": JSONShapeKeys.LINE_TO,
                "point": x.asCGPoint.toCGSize.asDictionary.description
            ].description
        case .moveTo(let x):
            return [
                "type": JSONShapeKeys.MOVE_TO,
                "point": x.asCGPoint.toCGSize.asDictionary.description
            ].description
        case .curveTo(curveFrom: let curveFrom,
                      point: let point,
                      curveTo: let curveTo):
            return [
                "type": JSONShapeKeys.CURVE_TO,
                "point": point.asCGPoint.toCGSize.asDictionary.description,
                "curveTo": curveTo.asCGPoint.toCGSize.asDictionary.description,
                "curveFrom": curveFrom.asCGPoint.toCGSize.asDictionary.description
            ].description
        }
    }
}
