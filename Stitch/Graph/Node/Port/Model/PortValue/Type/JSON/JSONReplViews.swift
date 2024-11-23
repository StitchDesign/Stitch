//
//  JSONReplViews.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import SwiftyJSON

struct JsonReplView: View {

    var jsonArrayJoin: JSON {
        //                arrayJoin(validArrayJSON, validArrayJSON) // works
        //                arrayJoin(validArrayJSON, validSimpleArrayJSON)
        //        arrayJoin(validArrayJSON, validComplexJSON) // works; returns first array, as expected
        arrayJoin(validComplexJSON, validArrayJSON) // works; returns second array, as expected
        //        arrayJoin(validComplexJSON, validComplexJSON) // empty array, as expected
    }

    var jsonArrayReverse: JSON {
        arrayReverse(validArrayJSON) // works
        //        arrayReverse(validSimpleArrayJSON) // works
    }

    var jsonArraySort: JSON {
        //        arraySort(validArrayJSON) // works
        //        arraySort(validSimpleArrayJSON) // works

        arraySort(validArrayJSON, ascending: false) // works
        //        arraySort(validSimpleArrayJSON, ascending: false) // works
    }
    var _jsonKeys: JSON {
        // should be "[love, pain]"
        //        jsonKeys(validSimpleJSON) // works; "[love, pain,]"

        //        jsonKeys(validArrayJSON) // works; empty array

        jsonKeys(validComplexJSON) // works; "[user]"
    }

    var _jsonIndexOf: (Int, Bool) {
        //        indexOf(validSimpleArrayJSON, item: 1.description) // (0, true)
        //        indexOf(validSimpleArrayJSON, item: 2.description) // (1, true)
        //        indexOf(validSimpleArrayJSON, item: 3.description) // (2, true)
        //        indexOf(validSimpleArrayJSON, item: "a") // (1, true) // (3, true)

        indexOf(validSimpleArrayJSON, item: 9.description) // (-1, false) // as expected
    }

    var _jsonSubarray: JSON {
        jsonSubarray(validVerySimpleArrayJSON, location: 0, length: 99)
    }

    var _jsonValueAtKeyPath: JSON {
        //        let json = validVeryComplexJSON
        //        let keyPathAsString = "user.name" // "Chris" // works
        //        let keyPathAsString = "user.pets" // [90, 91, 92] // works
        //        let keyPathAsString = "user.pets.0" // 90
        //        let keyPathAsString = "user.pets.1" // 91

        //        let json = validArrayOfObjectsJSON
        //        let keyPathAsString = "0.alpha" // Billy
        //        let keyPathAsString = "1.beta" // Jane
        //        let v = json[keyPathAsString.asJSONKeypath]
        //        return v

        let json = unionToShapesLoopJSON
        //        let keyPathAsString = "..type"
        let keyPathAsString = "..point"

        return getValueAtKeyPath(json, keyPathAsString)
    }

    var _jsonCreateObject: JSON? {
        let jsonArrayString = """
[
    {
      "point" : "(0, 0)",
      "type" : "moveTo"
    },
    {
      "point" : "(0, 0)",
      "type" : "lineTo"
    }
]
"""
        let value: PortValue = .json(JSON(parseJSON: jsonArrayString).toStitchJSON)
        return _JSONObjectFromKeyAndValue("path", value)
    }

    func _JSONObjectFromKeyAndValue(_ key: String,
                                    _ value: PortValue) -> JSON? {

        log("_JSONObjectFromKeyAndValue: key: \(key)")
        log("_JSONObjectFromKeyAndValue: value: \(value)")

        var newJson = JSON()
        //        newJson[key] = value.getJSON!
        newJson[key] = 5
        //        newJson[key] = "\(Color.blue.description)"

        log("_JSONObjectFromKeyAndValue: newJson: \(newJson)")
        return newJson
        //
        //        // not good when e.g. PV is a json
        //        let jsonValue: String = wrapPortValueDisplayInQuotes(value)
        //        log("_JSONObjectFromKeyAndValue: jsonValue: \(jsonValue)")
        //
        //        // doesn't work well when
        //        let jsonString = "{\"\(key)\": \(jsonValue)}"
        //        log("_JSONObjectFromKeyAndValue: jsonString: \(jsonString)")
        //
        //
        //
        //        let json = JSON(parseJSON: jsonString)
        //        log("_JSONObjectFromKeyAndValue: json: \(json)")
        //
        //        // can this operation really fail?
        //        if isNullJSON(json) {
        ////            fatalError()
        //            return nil
        //        }

        //        return json

    }

    var body: some View {
        VStack {
            Text("hello")
            //            Text("json: \(jsonArrayJoin.debugDescription)")
            //                        Text("json: \(jsonArrayReverse.debugDescription)")
            //            Text("json: \(jsonArraySort.debugDescription)")
            //            Text("json: \(_jsonKeys.debugDescription)")

            //            Text("json: \(_jsonIndexOf.0.description), \(_jsonIndexOf.1.description)")

            //            Text("json: \(_jsonSubarray.debugDescription)")
            Text("json: \(_jsonValueAtKeyPath.debugDescription)")
            //            Text("json: \(_jsonCreateObject?.description ?? "FAIL")")

        }
    }
}

//struct JSON_REPL_View_2: View {
//
//    let nick_json: JSON = parseJSON(
//        """
//{
//  "apiKey" : "cb713bfe-8c1f-4b7d-a180-50662340b025",
//  "modelInputs" : {
//    "height" : 512,
//    "guidance_scale" : 9,
//    "width" : 512,
//    "prompt" : "",
//    "seed" : 3242,
//    "num_inference_steps" : 50
//  },
//  "modelKey" : "4fa78e19-351f-4b2f-804a-974a545ded4a"
//}
//"""
//    )!
//
//    let testJSON: JSON = parseJSON(
//        """
//{
//  "grandpa" : {
//    "pa" : {
//      "son" : 9
//    }
//  }
//}
//"""
//    )!
//
//    // A bit tricky to recursively set a value at all key paths...
//    func setKeyInJson(json: JSON,
//                      key: String,
//                      value: PortValue) -> [JSON] {
//        var result: [JSON] = .init()
//
//        json.forEach({ (s: String, j: JSON) in
//            // s is key if json is object, or index if json is array
//            if s == key {
//
//                var j = j
//                var set = value.toJSONFormat.setInJSON(j, key: key)
//
//                // instead of just appending; we need to actually set the
//
//                //                result.append(j)
//                result.append(set)
//            }
//            //            result += findKeyInJson(j, key)
//            result += setKeyInJson(json: j, key: key, value: value)
//        })
//
//        return result
//    }
//
//    func setValueAtKeyPath(json: JSON,
//                           path: String,
//                           value: PortValue) -> JSON {
//
//        // recursive key
//        if let recursive = path.asRecursiveKeyPath {
//            return setKeyInJson(json: json,
//                                key: recursive,
//                                value: value).flatten
//        }
//
//        // simple key
//        else {
//            return setValueForKey(json, path, value)
//        }
//
//    }
//
//    var body: some View {
//        //        let result: JSON = testJSON
//
//        //        let result: JSON = setValueAtKeyPath(
//        //        let result: JSON = setValueForKey(
//        ////            json: testJSON,
//        //            json: nick_json,
//        ////            path: "pa",
//        //            path: "modelInputs.prompt",
//        ////            path: "grandpa.pa",
//        //            value: .string("Nick Driving A Car"))
//
//        let result: JSON = setValueForKey(
//            nick_json,
//            "modelInputs.prompt",
//            .string("cinnamon_roll"))
//
//        VStack {
//            Text("\(nick_json.description)")
//                .border(.blue)
//            Divider()
//            Text("\(result.description)")
//                .border(.red)
//        }
//
//    }
//}

//struct JSON_REPL_View_3: View {
//
//    var s: String {
//        //        """
//        //        { "api": "love" }
//        //        """
//        """
//                { "api": "/" }
//                """
//    }
//
//    var json: JSON? {
//        parseJSON(s)
//    }
//
//    //    var k: Result<Int, Error> {
//    var k: Result<Int, StitchNetworkRequestError> {
//        //        let r: Result<Int, Error>
//
//        let p = 9.99
//        //        return .init(error: "Bad Result \(p)")
//        return .failure(.init(error: "bad result \(p)..."))
//    }
//
//    var body: some View {
//        HStack(spacing: 30) {
//
//            Text(
//                //                k.error?.localizedDescription ?? "No Error..."
//                k.error?.error ?? "No error"
//                //                Error("Badness \(77.77)").localizedDescription
//            )
//
//            //
//            //            let k = json!.rawString(options: [.withoutEscapingSlashes, .prettyPrinted])!
//            //            Text(k)
//            //
//            //            //            let k2 = try! json!.rawData(options: .withoutEscapingSlashes)
//            //            //            Text(JSON(k2).description)
//            //
//            //            Text(json?.description ?? "Parsing Failure")
//            //            Divider()
//            //            Text("love 2")
//        }
//        .padding(90)
//        .background(.green.opacity(0.5))
//
//    }
//}
//
//struct JsonReplView_Previews: PreviewProvider {
//    static var previews: some View {
//        //        JsonReplView()
//        //        JSON_REPL_View_2()
//        JSON_REPL_View_3()
//    }
//}
