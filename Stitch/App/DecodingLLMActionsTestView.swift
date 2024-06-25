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
    
    let json = Self.json1
    
    var body: some View {
        Text(json.description)
            .onAppear {
                
            }
    }
    
    
    // Creating Add node, editing its first input’s first field
    static let json1 = JSON.init(parseJSON: """
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
    static let json2 = JSON.init(parseJSON: """
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

    static let json3 = JSON.init(parseJSON: """
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
      },
      {
        "field" : {
          "port" : "Position",
          "node" : "Oval (FEB7AA)",
          "field" : 0
        },
        "nodeType" : "Position",
        "value" : {
          "y" : 0,
          "x" : 12
        },
        "action" : "Set Field"
      }
    ]
    """)

}
