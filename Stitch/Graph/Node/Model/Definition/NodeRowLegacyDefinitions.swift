//
//  NodeRowLegacyDefinitions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/24.
//

import Foundation
import StitchSchemaKit

extension NodeKind {

    var legacyRowDefinitions: NodeRowDefinitions {

        switch self {
        case .patch(let patch):
            switch patch {

            case .add:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .convertPosition:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [interactionIdDefault],
                            label: "From Parent"
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: "From Anchor"
                        ),
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: "Point"
                        ),
                        .init(
                            defaultValues: [interactionIdDefault],
                            label: "To Parent"
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: "To Anchor"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .position
                        )
                    ]
                )

            case .multiply:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .optionPicker:
                return .init(
                    inputs: [
                        .init(
                            label: "Option",
                            staticType: .number
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .loop:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(3)],
                            label: "Count"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Index",
                            type: .number
                        )
                    ]
                )

            case .time:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Time",
                            type: .number
                        ),
                        .init(
                            label: "Frame",
                            type: .number
                        )
                    ]
                )

            case .deviceTime:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Seconds",
                            type: .number
                        ),
                        .init(
                            label: "Milliseconds",
                            type: .number
                        )
                    ]
                )

            case .greaterOrEqual:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.comparable(.number(200))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .lessThanOrEqual:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.comparable(.number(200))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .equals:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Threshold"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .restartPrototype:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.pulse(0)],
                            label: "Restart"
                        )
                    ],
                    outputs: []
                )

            case .divide:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .hslColor:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0.5)],
                            label: "Hue"
                        ),
                        .init(
                            defaultValues: [.number(0.8)],
                            label: "Saturation"
                        ),
                        .init(
                            defaultValues: [.number(0.8)],
                            label: "Lightness"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "Alpha"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .color
                        )
                    ]
                )

            case .or:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.bool(false)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.bool(false)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .and:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.bool(false)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.bool(false)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .not:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.bool(false)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .bouncyConverter:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(5)],
                            label: "Bounciness"
                        ),
                        .init(
                            defaultValues: [.number(10)],
                            label: "Speed"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Friction",
                            type: .number
                        ),
                        .init(
                            label: "Tension",
                            type: .number
                        )
                    ]
                )

            case .curve:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Progress"
                        ),
                        .init(
                            defaultValues: [.animationCurve(.linear)],
                            label: "Curve"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Progress",
                            type: .number
                        )
                    ]
                )

            case .cubicBezierCurve:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Progress"
                        ),
                        .init(
                            defaultValues: [.number(0.17)],
                            label: "1st Control Point X"
                        ),
                        .init(
                            defaultValues: [.number(0.17)],
                            label: "1st Control Point Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "2nd Control Point X"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "2nd Control Point Y"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Progress",
                            type: .number
                        ),
                        .init(
                            label: "2D Progress",
                            type: .number
                        )
                    ]
                )

            case .loopBuilder:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Index",
                            type: .number
                        ),
                        .init(
                            label: "Values",
                            type: .media
                        )
                    ]
                )

            case .transition:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0.5)],
                            label: "Progress",
                            isTypeStatic: true
                        ),
                        .init(
                            defaultValues: [.number(50)],
                            label: "Start"
                        ),
                        .init(
                            defaultValues: [.number(100)],
                            label: "End"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .loopSelect:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Input"
                        ),
                        .init(
                            label: "Index Loop",
                            staticType: .number
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loop",
                            type: .string
                        ),
                        .init(
                            label: "Index",
                            type: .number
                        )
                    ]
                )

            case .speaker:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.asyncMedia(nil)],
                            label: "Sound"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "Volume"
                        )
                    ],
                    outputs: []
                )

            case .networkRequest:
                return .init(
                    inputs: [
                        .init(
                            label: "URL",
                            staticType: .string
                        ),
                        .init(
                            label: "URL Parameters",
                            staticType: .json
                        ),
                        .init(
                            label: "Body",
                            staticType: .json
                        ),
                        .init(
                            label: "Headers",
                            staticType: .json
                        ),
                        .init(
                            defaultValues: [.networkRequestType(.get)],
                            label: "Method",
                            isTypeStatic: true
                        ),
                        .init(
                            label: "Request",
                            staticType: .pulse
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loading",
                            type: .bool
                        ),
                        .init(
                            label: "Result",
                            type: .json
                        ),
                        .init(
                            label: "Errored",
                            type: .bool
                        ),
                        .init(
                            label: "Error",
                            type: .json
                        ),
                        .init(
                            label: "Headers",
                            type: .json
                        )
                    ]
                )

            case .loopOverArray:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: "Array"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Index",
                            type: .number
                        ),
                        .init(
                            label: "Items",
                            type: .json
                        )
                    ]
                )

            case .setValueForKey:
                return .init(
                    inputs: [
                        .init(
                            label: "Object",
                            staticType: .json
                        ),
                        .init(
                            label: "Key",
                            staticType: .string
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Value"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Object",
                            type: .number
                        )
                    ]
                )

            case .arrayCount:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: "Array"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .arrayJoin:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: ""
                        ),
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .json
                        )
                    ]
                )

            case .arrayReverse:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .json
                        )
                    ]
                )

            case .arraySort:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.bool(true)],
                            label: "Ascending"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .json
                        )
                    ]
                )

            case .getKeys:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: "Object"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .json
                        )
                    ]
                )

            case .indexOf:
                return .init(
                    inputs: [
                        .init(
                            label: "Array",
                            staticType: .json
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Item"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Index",
                            value: .number(-1)
                        ),
                        .init(
                            label: "Contains",
                            type: .bool
                        )
                    ]
                )

            case .subarray:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.json(emptyStitchJSONArray)],
                            label: "Array"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Location"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Length"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Subarray",
                            type: .json
                        )
                    ]
                )

            case .deviceMotion:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Has Acceleration",
                            type: .bool
                        ),
                        .init(
                            label: "Acceleration",
                            type: .point3D
                        ),
                        .init(
                            label: "Has Rotation",
                            type: .bool
                        ),
                        .init(
                            label: "Rotation",
                            type: .point3D
                        )
                    ]
                )

            case .deviceInfo:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Screen Size",
                            type: .size
                        ),
                        .init(
                            label: "Screen Scale",
                            type: .number
                        ),
                        .init(
                            label: "Orientation",
                            value: .deviceOrientation(.defaultDeviceOrientation)
                        ),
                        .init(
                            label: "Device Type",
                            value: .string(.init("iPad"))
                        ),
                        .init(
                            label: "Appearance",
                            value: .string(.init(defaultColorScheme.description))
                        ),
                        .init(
                            label: "Safe Area Top",
                            type: .number
                        ),
                        .init(
                            label: "Safe Area Bottom",
                            type: .number
                        )
                    ]
                )

            case .clip:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Value"
                        ),
                        .init(
                            defaultValues: [.number(-5)],
                            label: "Min"
                        ),
                        .init(
                            defaultValues: [.number(5)],
                            label: "Max"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .max:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            value: .number(1)
                        )
                    ]
                )

            case .mod:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .absoluteValue:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            value: .number(1)
                        )
                    ]
                )

            case .round:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Places"
                        ),
                        .init(
                            label: "Rounded Up",
                            staticType: .bool
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .progress:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(50)],
                            label: "Value"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Start"
                        ),
                        .init(
                            defaultValues: [.number(100)],
                            label: "End"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .reverseProgress:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(50)],
                            label: "Value"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Start"
                        ),
                        .init(
                            defaultValues: [.number(100)],
                            label: "End"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .wirelessBroadcaster:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .wirelessReceiver:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .rgba:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Red"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Green"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Blue"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "Alpha"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .color
                        )
                    ]
                )

            case .arcTan2:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "X"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .sine:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Angle"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .cosine:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Angle"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .soulver:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            type: .string
                        )
                    ]
                )

            case .optionEquals:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init("a"))],
                            label: "Option",
                            isTypeStatic: true
                        ),
                        .init(
                            defaultValues: [.string(.init("a"))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.string(.init("b"))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            value: .string(.init("a"))
                        ),
                        .init(
                            label: "Equals",
                            value: .bool(true)
                        )
                    ]
                )

            case .subtract:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .squareRoot:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .length:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            value: .number(1)
                        )
                    ]
                )

            case .min:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .power:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(1)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .equalsExactly:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .greaterThan:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .lessThan:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.comparable(.number(0))],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.comparable(.number(200))],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .colorToHSL:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.color(falseColor)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Hue",
                            type: .number
                        ),
                        .init(
                            label: "Saturation",
                            type: .number
                        ),
                        .init(
                            label: "Lightness",
                            type: .number
                        ),
                        .init(
                            label: "Alpha",
                            type: .number
                        )
                    ]
                )

            case .colorToHex:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.color(falseColor)],
                            label: "Color"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Hex",
                            type: .string
                        )
                    ]
                )

            case .colorToRGB:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.color(falseColor)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Red",
                            type: .number
                        ),
                        .init(
                            label: "Green",
                            type: .number
                        ),
                        .init(
                            label: "Blue",
                            type: .number
                        ),
                        .init(
                            label: "Alpha",
                            type: .number
                        )
                    ]
                )

            case .hexColor:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Hex"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Color",
                            type: .color
                        )
                    ]
                )

            case .splitText:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Token"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .textEndsWith:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Suffix"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .textLength:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .textReplace:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Find"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Replace"
                        ),
                        .init(
                            defaultValues: [.bool(false)],
                            label: "Case Sensitive"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .textStartsWith:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Prefix"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .textTransform:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.textTransform(.uppercase)],
                            label: "Transform"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .trimText:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Length"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .dateAndTimeFormatter:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Time"
                        ),
                        .init(
                            defaultValues: [.dateAndTimeFormat(.medium)],
                            label: "Format"
                        ),
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Custom Format"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .string
                        )
                    ]
                )

            case .optionSender:
                return .init(
                    inputs: [
                        .init(
                            label: "Option",
                            staticType: .number
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Value"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Default"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        ),
                        .init(
                            label: "",
                            type: .number
                        ),
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .any:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.bool(false)],
                            label: "Loop"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Grouping"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .bool
                        )
                    ]
                )

            case .loopCount:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .loopDedupe:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loop",
                            type: .number
                        ),
                        .init(
                            label: "Index",
                            type: .number
                        )
                    ]
                )

            case .loopFilter:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init(""))],
                            label: "Input"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "Include",
                            isTypeStatic: true
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loop",
                            type: .string
                        ),
                        .init(
                            label: "Index",
                            type: .number
                        )
                    ]
                )

            case .loopOptionSwitch:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.pulse(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Option",
                            type: .number
                        )
                    ]
                )

            case .loopRemove:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Index"
                        ),
                        .init(
                            defaultValues: [.pulse(0)],
                            label: "Remove"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loop",
                            type: .number
                        ),
                        .init(
                            label: "Index",
                            type: .number
                        )
                    ]
                )

            case .loopReverse:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .loopShuffle:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        ),
                        .init(
                            defaultValues: [.pulse(0)],
                            label: "Shuffle"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Loop",
                            type: .number
                        )
                    ]
                )

            case .loopSum:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )

            case .loopToArray:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .json
                        )
                    ]
                )

            case .runningTotal:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: "Loop"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .number
                        )
                    ]
                )
            case .triangleShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.position(TriangleData.defaultTriangleP1.toCGSize)],
                            label: "First Point"
                        ),
                        .init(
                            defaultValues: [.position(TriangleData.defaultTriangleP2.toCGSize)],
                            label: "Second Point"
                        ),
                        .init(
                            defaultValues: [.position(TriangleData.defaultTriangleP3.toCGSize)],
                            label: "Third Point"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        )
                    ]
                )

            case .circleShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.number(10)],
                            label: "Radius"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        )
                    ]
                )

            case .ovalShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.position(CGRect.defaultOval.origin.toCGSize)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.size(CGRect.defaultOval.size.toLayerSize)],
                            label: LayerInputType.size.label()
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        )
                    ]
                )

            case .roundedRectangleShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.position(CGRect.defaultRoundedRectangle.rect.origin.toCGSize)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.size(CGRect.defaultRoundedRectangle.rect.size.toLayerSize)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [.number(CGRect.defaultRoundedRectangle.cornerRadius)],
                            label: "Radius"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        )
                    ]
                )

            case .union:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.shape(nil)],
                            label: ""
                        ),
                        .init(
                            defaultValues: [.shape(nil)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "",
                            type: .shape
                        )
                    ]
                )

            case .keyboard:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init("a"))],
                            label: "Key"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Down",
                            type: .bool
                        )
                    ]
                )

            case .jsonToShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [defaultFalseJSON],
                            label: "JSON"
                        ),
                        .init(
                            defaultValues: [.position(defaultJsonToShapeCoordinateSpace.toCGSize)],
                            label: "Coordinate Space"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        ),
                        .init(
                            label: "Error",
                            type: .string
                        ),
                        .init(
                            label: LayerInputType.size.label(),
                            type: .size
                        )
                    ]
                )

            case .shapeToCommands:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.shape(getDemoShape())],
                            label: "Shape"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Commands",
                            type: .shapeCommand
                        )
                    ]
                )

            case .commandsToShape:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: getDemoShape().shapes.fromShapeToShapeCommandLoop!.map(PortValue.shapeCommand),
                            label: "Commands"
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Shape",
                            type: .shape
                        )
                    ]
                )

            case .mouse:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.number(0)],
                            label: ""
                        )
                    ],
                    outputs: [
                        .init(
                            label: "Down",
                            type: .bool
                        ),
                        .init(
                            label: LayerInputType.position.label(),
                            type: .position
                        ),
                        .init(
                            label: "Velocity",
                            type: .position
                        )
                    ]
                )

            default:
                #if DEBUG
                fatalError("Make sure node is defined using GraphNode")
                #endif
                return .init(inputs: [],
                             outputs: [])
            }

        case .layer(let layer):
            switch layer {
            case .text:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init("Text"))],
                            label: "Text"
                        ),
                        .init(
                            defaultValues: [.color(initialLayerColor())],
                            label: "Color"
                        ),
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation X"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Z"
                        ),
                        .init(
                            defaultValues: [.size(defaultTextSize)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [defaultOpacity],
                            label: "Opacity"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: LayerInputType.scale.label()
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: LayerInputType.anchoring.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.zIndex.label()
                        ),
                        .init(
                            defaultValues: [.number(36)],
                            label: "Font Size"
                        ),
                        .init(
                            defaultValues: [.textAlignment(DEFAULT_TEXT_ALIGNMENT)],
                            label: "Alignment"
                        ),
                        .init(
                            defaultValues: [.textVerticalAlignment(DEFAULT_TEXT_VERTICAL_ALIGNMENT)],
                            label: "Vertical Alignment"
                        ),
                        .init(
                            defaultValues: [.textDecoration(.defaultLayerTextDecoration)],
                            label: "Text Decoration"
                        ),
                        .init(
                            defaultValues: [.textFont(.defaultStitchFont)],
                            label: "Text Font"
                        ),
                        .init(
                            defaultValues: [.number(.zero)],
                            label: "Blur"
                        ),
                        .init(
                            defaultValues: [.blendMode(.defaultBlendMode)],
                            label: "Blend Mode"
                        )
                        
                    ],
                    outputs: []
                )

            case .textField:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.string(.init("Text"))],
                            label: "Placeholder"
                        ),
                        .init(
                            defaultValues: [.color(initialLayerColor())],
                            label: "Color"
                        ),
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation X"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Z"
                        ),
                        .init(
                            defaultValues: [.size(defaultTextSize)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [defaultOpacity],
                            label: "Opacity"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: LayerInputType.scale.label()
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: LayerInputType.anchoring.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.zIndex.label()
                        ),
                        .init(
                            defaultValues: [.number(36)],
                            label: "Font Size"
                        ),
                        .init(
                            defaultValues: [.textAlignment(DEFAULT_TEXT_ALIGNMENT)],
                            label: "Alignment"
                        ),
                        .init(
                            defaultValues: [.textVerticalAlignment(DEFAULT_TEXT_VERTICAL_ALIGNMENT)],
                            label: "Vertical Alignment"
                        ),
                        .init(
                            defaultValues: [.textDecoration(.defaultLayerTextDecoration)],
                            label: "Text Decoration"
                        ),
                        .init(
                            defaultValues: [.textFont(.defaultStitchFont)],
                            label: "Text Font"
                        ),
                        .init(
                            defaultValues: [.number(.zero)],
                            label: "Blur"
                        ),
                        .init(
                            defaultValues: [.blendMode(.defaultBlendMode)],
                            label: "Blend Mode"
                        )
                    ],
                    outputs: [
                        .init(label: "Field",
                              type: .string)
                    ]
                )

            case .oval:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.color(falseColor)],
                            label: "Color"
                        ),
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation X"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Z"
                        ),
                        .init(
                            defaultValues: [.size(.LAYER_DEFAULT_SIZE)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [defaultOpacity],
                            label: "Opacity"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: LayerInputType.scale.label()
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: LayerInputType.anchoring.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.zIndex.label()
                        ),
                        .init(
                            defaultValues: [.layerStroke(.defaultStroke)],
                            label: "Stroke Position"
                        ),
                        .init(
                            defaultValues: [.number(4)],
                            label: "Stroke Width"
                        ),
                        .init(
                            defaultValues: [.color(falseColor)],
                            label: "Stroke Color"
                        ),
                        .init(
                            defaultValues: [.number(.zero)],
                            label: "Blur"
                        ),
                        .init(
                            defaultValues: [.blendMode(.defaultBlendMode)],
                            label: "Blend Mode"
                        )
                    ],
                    outputs: []
                )

            case .group:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.size(DEFAULT_GROUP_SIZE)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.zIndex.label()
                        ),
                        .init(
                            defaultValues: [.bool(true)],
                            label: "Clipped"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: LayerInputType.scale.label()
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: LayerInputType.anchoring.label()
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation X"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Y"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Rotation Z"
                        ),
                        .init(
                            defaultValues: [.number(1)],
                            label: "Opacity"
                        ),
                        .init(
                            defaultValues: [.anchoring(.centerCenter)],
                            label: "Pivot"
                        ),
                        .init(
                            defaultValues: [.orientation(.none)],
                            label: "Orientation"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Padding"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: "Blur"
                        ),
                        .init(
                            defaultValues: [.blendMode(.defaultBlendMode)],
                            label: "Blend Mode"
                        ),
                        .init(
                            defaultValues: [.color(.trueColor)],
                            label: "Background Color"
                        ),
                        .init(
                            defaultValues: [.number(.defaultBrightnessForLayerEffect)],
                            label: "Brightness"
                        ),
                        .init(
                            defaultValues: [.bool(.defaultColorInvertForLayerEffect)],
                            label: "Color Invert"
                        ),
                        .init(
                            defaultValues: [.number(.defaultContrastForLayerEffect)],
                            label: "Contrast"
                        ),
                        .init(
                            defaultValues: [.number(.defaultHueRotationForLayerEffect)],
                            label: "Hue Rotation"
                        ),
                        .init(
                            defaultValues: [.number(.defaultSaturationForLayerEffect)],
                            label: "Saturation"
                        )
                    ],
                    outputs: []
                )

            case .hitArea:
                return .init(
                    inputs: [
                        .init(
                            defaultValues: [.bool(true)],
                            label: "Enable"
                        ),
                        .init(
                            defaultValues: [.position(StitchPosition.zero)],
                            label: LayerInputType.position.label()
                        ),
                        .init(
                            defaultValues: [.size(defaultHitAreaSize)],
                            label: LayerInputType.size.label()
                        ),
                        .init(
                            defaultValues: [.anchoring(.defaultAnchoring)],
                            label: "Anchor"
                        ),
                        .init(
                            defaultValues: [.number(0)],
                            label: LayerInputType.zIndex.label()
                        ),
                        .init(
                            defaultValues: [.bool(true)],
                            label: "Setup Mode"
                        )
                    ],
                    outputs: []
                )

            default:
                #if DEBUG
                fatalError("Make sure node is defined using GraphNode")
                #endif
                return .init(inputs: [], outputs: [])
            }
        case .group:
            // Shouldn't be called for groups
            return .init(inputs: [], outputs: [])
        }
    }
}
