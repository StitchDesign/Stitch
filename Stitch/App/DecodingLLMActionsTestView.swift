//
//  DecodingLLMActionsTestView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/24.
//

import SwiftUI
import StitchSchemaKit
import SwiftyJSON


struct DecodingLLMActionsView: View {
    
//    let json: JSON = _addNode // good
//    let json = _addNodeAndMove // good
//    let json = _addLayerInputAndMove // good
    let json = _setField // bad
    
//    let json = jff
    
     typealias DebugDecodeType = [LLMAction] // still fails?
//     typealias DebugDecodeType = JSONFriendlyFormat // also works
//    typealias DebugDecodeType = [JSONFriendlyFormat] // works
    
    var decodedActions: DebugDecodeType {
        log("json.description: \(json.description)")
        
        let data = try! json.rawData()
        
        let actions = try! JSONDecoder().decode(
            DebugDecodeType.self,
            from: data)
        
        return actions
    }
    
    var body: some View {
        HStack(spacing: 100) {
            Text("json.description: \(json.description)")
            Text("decodedActions : \(decodedActions)")
        }
    }
}

//let jff = JSONFriendlyFormat(value: .number(77)).jsonWrapper

let jff = JSONFriendlyFormat(value: .size(.init(width: 22, height: 33))).jsonWrapper

let _setField = JSON.init(parseJSON: """
[
  {
    "value" : 90,
    "field" : {
      "field" : 0,
      "port" : "0",
      "node" : "Add (7AEC3B)"
    },
    "nodeType" : "Number",
    "action" : "Set Field"
  }
]
""")

// Creating Add node, editing its first input’s first field
let _addNode = JSON.init(parseJSON: """
[
  {
    "action" : "Add Node",
    "node" : "Add (7AEC3B)"
  }
]
""")

let _addNodeAndSetField = JSON.init(parseJSON: """
[
  {
    "action" : "Add Node",
    "node" : "Add (7AEC3B)"
  },
  {
    "value" : 90,
    "field" : {
      "field" : 0,
      "port" : "0",
      "node" : "Add (7AEC3B)"
    },
    "nodeType" : "Number",
    "action" : "Set Field"
  }
]
""")


// Creating Subtract node, moving it
let _addNodeAndMove = JSON.init(parseJSON: """
[
  {
    "action" : "Add Node",
    "node" : "Subtract (CE9AE8)"
  },
  {
    "translation" : {
      "y" : 100,
      "x" : -196
    },
    "node" : "Subtract (CE9AE8)",
    "port" : "",
    "action" : "Move Node"
  }
]
""")

let _addLayerInputAndMove = JSON.init(parseJSON: """
[
  {
    "node" : "Oval (FEB7AA)",
    "action" : "Add Node"
  },
  {
    "port" : "Position",
    "node" : "Oval (FEB7AA)",
    "action" : "Add Layer Input"
  },
  {
    "port" : "Position",
    "translation" : {
      "y" : -212,
      "x" : -372
    },
    "action" : "Move Node",
    "node" : "Oval (FEB7AA)"
  }
]
""")

let _addTwoNodesAndMoveAndCreateEdge = JSON.init(parseJSON: """
[
  {
    "node" : "Add (87FE4D)",
    "action" : "Add Node"
  },
  {
    "node" : "Add (87FE4D)",
    "port" : "",
    "translation" : {
      "x" : -378,
      "y" : -200
    },
    "action" : "Move Node"
  },
  {
    "node" : "Subtract (CD0CB5)",
    "action" : "Add Node"
  },
  {
    "node" : "Subtract (CD0CB5)",
    "translation" : {
      "x" : 81,
      "y" : 150
    },
    "port" : "",
    "action" : "Move Node"
  },
  {
    "to" : {
      "port" : "0",
      "node" : "Subtract (CD0CB5)"
    },
    "from" : {
      "node" : "Add (87FE4D)",
      "port" : "0"
    },
    "action" : "Add Edge"
  }
]
""")
