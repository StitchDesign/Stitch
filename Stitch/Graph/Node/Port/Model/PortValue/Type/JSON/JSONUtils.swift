//
//  UserJSON.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/9/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
@preconcurrency import SwiftyJSON

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

    func createPrintableJsonString() throws -> String {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .prettyPrinted])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("createPrintableJsonString: invalid data.")
                throw SwiftyJSONError.invalidJSON
            }
            return jsonString
        } catch {
            log("createPrintableJsonString: rror: \(error.localizedDescription)")
            throw error
        }
    }
//    
//    func printJson() {
//        do {
//            let json = try self.createPrintableJsonString()
//            print(json)
//        } catch {
//            log("printJson: unable to print with error: \(error.localizedDescription)")
//        }
//    }
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
        case .layerSizeDictionary(let x):
            json[index].dictionaryObject = x
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
        case .layerSizeDictionary(let x):
            json[keyPath].dictionaryObject = x
        case .dictionary(let x):
            json[keyPath].dictionaryObject = x
        case .json(let x):
            json[keyPath] = x
        }

        return json
    }
}

extension JSON {
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
            
        case .layerSizeDictionary(let x):
            //        log("JSONObjectFromKeyAndValue: dictionary: x: \(x)")
            j[key].dictionaryObject = x
            
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
            return .init(x: x, y: y)
        }
        return nil
    }

    var getWidth: LayerDimension? {
        self[WIDTH].string?.asLayerDimension ?? self[WIDTH].double.map { LayerDimension.number($0) }
    }
    
    var getHeight: LayerDimension? {
        self[HEIGHT].string?.asLayerDimension ?? self[HEIGHT].double.map { LayerDimension.number($0) }
    }
    
    var toSize: LayerSize? {
        if let width = self.getWidth,
           let height = self.getHeight {
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
    
    var toStitchPadding: StitchPadding? {
        if let top = self[TOP].double,
           let right = self[RIGHT].double,
           let bottom = self[BOTTOM].double,
           let left = self[LEFT].double {
            return .init(top: top, right: right, bottom: bottom, left: left)
        }
        return nil
    }
}

extension [String: Double] {
    
    var toStitchPosition: StitchPosition? {
        if let x = self.caseInsensitiveX,
           let y = self.caseInsensitiveY {
            return .init(x: x, y: y)
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
    
    var toStitchPadding: StitchPadding? {
        if let top = self[TOP],
           let right = self[RIGHT],
           let bottom = self[BOTTOM],
           let left = self[LEFT] {
            return .init(top: top, right: right, bottom: bottom, left: left)
        }
        return nil
    }
}

//enum JSONFriendlyFormat: Encodable, Equatable {

// Represents a PortValue in a way that displays "naturally" in a JSON.
// e.g. avoids the `_0` etc. of `Codable` enums
enum JSONFriendlyFormat: Encodable, Decodable, Equatable, Hashable {
    case string(String),
         number(Double),
         dictionary([String: Double]),
         
         // TODO: a LayerSize field may be .auto, .parentPercent(50%) etc.; so
         layerSizeDictionary([String: String]),
         
         json(JSON) // already a json

    var jsonWrapper: JSON {
        self.setInJSON(JSON(["a"]), index: 0)
    }
            
    /*
     How would you really decode this?
     You have no keys etc. -- you just get a string or number or dictionary etc. back.
    
     (For LLM case, probably don't need JSON per se?)
     
     You don't know the type of the value that gets returned.
     And Stitch nodes never really turn this format back into some PortValue etc.
     
     You could create a new struct or enum, and specify both 
     */
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let s = try? container.decode(String.self) {
            self = .string(s)
        }
        
        else if let n = try? container.decode(Double.self) {
            self = .number(n)
        }
        
        else if let d = try? container.decode([String: Double].self) {
            self = .dictionary(d)
        }
        
        else if let ld = try? container.decode([String: String].self) {
            self = .layerSizeDictionary(ld)
        }
        
        else if let j = try? container.decode(JSON.self) {
            self = .json(j)
        }
        
        else {
            fatalErrorIfDebug()
            self = .string("Decoding Failed")
        }
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
        case .layerSizeDictionary(let ld):
            try container.encode(ld)
        case .json(let j):
            try container.encode(j)
        }
    }
}

extension JSONFriendlyFormat {
    
    // TODO: JAN 29: replace this initializer with `llmFriendlyDisplay`? Main difference is .display vs .rawValue
    // PortValue -> JSONFriendlyFormat
    init(value: PortValue) {
        switch value {

        case .number(let x):
            self = .number(x)

            // Swift `struct`s are turned into dictionaries.
            // Most can be represented as `[String: Double]` except for LayerSize, which needs `[String: String]` since its width could be e.g. "50%" or "auto"
        case .size(let x):
            self = .layerSizeDictionary(x.asLayerDictionary)
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
    
    func asPortValueForLLMSetField(_ nodeType: NodeType) -> PortValue? {
        
        log("asPortValueForLLMSetField: self: \(self)")
        log("asPortValueForLLMSetField: nodeType: \(nodeType)")
        
        // Try to match on the specific JFF-case,
        // if the LLM Model sent something
        
        switch self {
            
        case .number(let x):
            return .number(x)
        
        case .json(let x):
            return .json(.init(x))
        
        case .layerSizeDictionary:
            
            switch nodeType {
                
            case .size:
                if let size = self
                    // Turn into JSON Array, then retrieve JSON Object
                    .jsonWrapper.first?.1
                    // Parse JSON Object as having "width", "height" keys etc.
                    .toSize {
                    return .size(size)
                }
                return nil
                
            default:
                fatalErrorIfDebug()
                return nil
            }
            
            
        // .dictionary can only be .size, .position, .point3D, .point4D
        // TODO: JAN 29: update for the other possible dictionary cases, e.g. StitchPadding etc.
        // Note: See `PortValue.llmFriendlyDisplay` for list of PortValues that can be turned into JSONFriendlyFormat.dictionary cases
        case .dictionary(let x):
            switch nodeType {
            
            case .position:
                return x.toStitchPosition.map(PortValue.position)
                                
            case .point3D:
                return x.toPoint3D.map(PortValue.point3D)
                
            case .point4D:
                return x.toPoint4D.map(PortValue.point4D)
                
            case .size:
                return self.jsonWrapper.first?.1.toSize.map(PortValue.size)
                
            case .anchoring:
                return x.toStitchPosition.map {
                    .anchoring(.init(x: $0.x, y: $0.y))
                }
                
            case .padding:
                return x.toStitchPadding.map(PortValue.padding)
                
            default:
                // TODO: last
                if let dictAsJSON = self.jsonWrapper.first?.1 {
                    log("asPortValueForLLMSetField: dictAsJSON: \(dictAsJSON)")
                    return dictAsJSON.description.parseAsPortValue(nodeType)
                } else {
                    return nil
                }
            }
            
            // .string is used for PortValue.string but also any other non-multifield value
        case .string(let x):
            log("asPortValueForLLMSetField: JFF string: x \(x)")
            
            // can actually just return a string,
            // and the logic of `handleInputEdited` handles the rest
            switch nodeType {
                
            case .interactionId:
                // TODO: JAN 29: can we just return the string directly? Since the LLM now uses proper LLM
                log("asPortValueForLLMSetField: JFF string, with interaction id node type: x: \(x)")
                if let id = UUID(uuidString: x) {
                    log("asPortValueForLLMSetField: JFF string, with interaction id node type: returning id directly")
                    return .assignedLayer(.init(id))
                }
//                    
//                else if let layerNodeId = mapping.get(x) {
//                    return .assignedLayer(.init(layerNodeId))
//                }
                return .assignedLayer(nil)
            
            case .string:
                log("asPortValueForLLMSetField: JFF string: had genuine stirng")
                return .string(.init(x))
            
            default:
                // Should try to parse this
                // If model gave us a string JFF value with a non-string node-type,
                // try to parse the JFF
                log("asPortValueForLLMSetField: JFF string: x: \(x)")
                return x.parseAsPortValue(nodeType)
            }
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
