//
//  JSONSampleData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/26/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
@preconcurrency import SwiftyJSON

extension JSON {
    static let emptyObject = emptyJSONObject
    static let emptyArray = emptyJSONArray

    static let validSimple = validSimpleJSON
    static let validNested = validComplexJSON
    static let validNested2 = validVeryComplexRawJSON

    static let validArray = validVerySimpleArrayJSON
    static let validArray2 = validSimpleArrayJSON
    static let validArrayOfObjects = validArrayOfObjectsJSON

    static let unionToShapes = unionToShapesLoopJSON
    static let moveTo = parseJSON(sampleMoveToJSON)!
    static let curveTo = parseJSON(sampleCurveToJSON)!
    static let negativeCurveTo = parseJSON(sampleNegativeCurveToJSON)!
    static let pacman = parseJSON(samplePacManJSON)
}

let validSimpleRawJSON = "{\"love\": 1, \"pain\": \"coconut\"}"
let validSimpleJSON: JSON = parseJSON(validSimpleRawJSON)!

let invalidSimpleRawJSON = "{love: 1, \"pain\": \"coconut\"}"

let validComplexRawJSON = "{\"user\": {\"name\": \"Chris\"}}"
let validComplexJSON: JSON = parseJSON(validComplexRawJSON)!

let validVeryComplexRawJSON = "{\"user\": {\"name\": \"Chris\", \"pets\": [90, 91, 92]}}"
let validVeryComplexJSON: JSON = parseJSON(validVeryComplexRawJSON)!

let validArrayOfObjectsRawJSON = "[{\"alpha\": \"Billy\"}, {\"beta\": \"Jane\"}]"
let validArrayOfObjectsJSON: JSON = parseJSON(validArrayOfObjectsRawJSON)!

let validArrayRawJSON = "[1, 2, 3, \"four\", {\"five\": \"six\"}]"
let validArrayJSON: JSON = parseJSON(validArrayRawJSON)!

let validSimpleArrayRawJSON = "[1, 2, 3, \"a\"]"
let validSimpleArrayJSON: JSON = parseJSON(validSimpleArrayRawJSON)!

let validVerySimpleArrayRawJSON = "[1, 2, 3]"
let validVerySimpleArrayJSON: JSON = parseJSON(validVerySimpleArrayRawJSON)!

let unionToShapesLoopRawJSON = """
{
  "path" : [
    {
      "point" : {
        "X" : 153,
        "Y" : 175
      },
      "type" : "moveTo"
    },
    {
      "point" : {
        "X" : 50,
        "Y" : 227
      },
      "type" : "lineTo"
    },
    {
      "point" : {
        "X" : -53,
        "Y" : 175
      },
      "type" : "lineTo"
    }
  ]
}
"""

let unionToShapesLoopJSON: JSON = parseJSON(unionToShapesLoopRawJSON)!

let sampleMoveToJSON = """
{
  "path": [
    {
      "type": "moveTo",
      "point": {
        "x": 0,
        "y": 0
      }
    },

    {
      "type": "lineTo",
      "point": {
        "x": 100,
        "y": 100
      }
    },

    {
      "type": "lineTo",
      "point": {
        "x": 200,
        "y": 200
      }
    },

  ]
}
"""

let sampleCurveToJSON = """
{
  "path": [
    {
      "type": "moveTo",
      "point": {
        "x": 0,
        "y": 0
      }
    },
    {
      "type": "lineTo",
      "point": {
        "x": 100,
        "y": 100
      }
    },
    {
      "type": "curveTo",
      "curveFrom": {
        "x": 150,
        "y": 100
      },
      "point": {
        "x": 200,
        "y": 200
      },
      "curveTo": {
        "x": 150,
        "y": 200
      }
    }
  ]
}
"""

// INTENTIONALLY MALFORMED
let sampleCurveToJSON2 = """
{
  "path": [
    {
      "type": "moveTo",
      "point": {
        "x": 0,
        "y": 0
      }
    },
    {
      "type": "lineTo",
      "point": {
        "x": 100,
        "y": 100
      }
    },
    {
      "type": "curveTo",

      "point": {
        "x": 200,
        "y": 200
      },
      "curveTo": {
        "x": 150,
        "y": 200
      }
    }
  ]
}
"""

let sampleNegativeCurveToJSON = """
{
  "path": [
    {
      "type": "moveTo",
      "point": {
        "x": 0,
        "y": 0
      }
    },
    {
      "type": "lineTo",
      "point": {
        "x": -100,
        "y": 100
      }
    },
    {
      "type": "curveTo",
      "curveFrom": {
        "x": 150,
        "y": 100
      },
      "point": {
        "x": -200,
        "y": 200
      },
      "curveTo": {
        "x": 150,
        "y": -200
      }
    }
  ]
}
"""

let samplePacManJSON = """
{
  "path": [
    {
      "type": "moveTo",
      "point": {
        "x": 0,
        "y": 0
      }
    },
    {
      "type": "curveTo",
      "curveFrom": {
        "x": 150,
        "y": 100
      },
      "point": {
        "x": -200,
        "y": -200
      },
      "curveTo": {
        "x": 150,
        "y": -200
      }
    }
  ]
}
"""

/*
 let samplePacManJSON = """
 {
 "path": [
 {
 "type": "moveTo",
 "point": {
 "x": 0,
 "y": 0
 }
 },
 {
 "type": "lineTo",
 "point": {
 "x": -100,
 "y": 100
 }
 },
 {
 "type": "curveTo",
 "curveFrom": {
 "x": 150,
 "y": 100
 },
 "point": {
 "x": -200,
 "y": -200
 },
 "curveTo": {
 "x": 150,
 "y": -200
 }
 }
 ]
 }
 """
 """
 */
