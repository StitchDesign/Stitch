//
//  RotationModifierCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/1/25.
//

import Foundation

struct RotationModifierCodeExamples {
    static let rotationEffectBasic = MappingCodeExample(
        title: "rotationEffect basic",
        code:
    """
    Rectangle()
        .rotationEffect(.degrees(45))
    """
    )

    static let rotationEffectAnchor = MappingCodeExample(
        title: "rotationEffect with anchor",
        code:
    """
    Rectangle()
        .rotationEffect(.degrees(45), anchor: .topLeading)
    """
    )

    static let rotationEffectRadians = MappingCodeExample(
        title: "rotationEffect using radians",
        code:
    """
    Text("Rotated")
        .rotationEffect(.radians(.pi / 2))
    """
    )

    static let rotation3DEffectBasic = MappingCodeExample(
        title: "rotation3DEffect basic",
        code:
    """
    Rectangle()
        .rotation3DEffect(.degrees(60), axis: (x: 0, y: 1, z: 0))
    """
    )

    static let rotation3DEffectPerspective = MappingCodeExample(
        title: "rotation3DEffect with perspective",
        code:
    """
    Image(systemName: "star.fill")
        .rotation3DEffect(
            .degrees(30),
            axis: (x: 1, y: 0.5, z: 0),
            anchor: .center,
            anchorZ: 20,
            perspective: 0.3
        )
    """
    )

    // MARK: - PortValueDescription Examples
    
    static let rotationEffectPortValueDescription = MappingCodeExample(
        title: "rotationEffect with PortValueDescription",
        code:
    """
    Rectangle()
        .rotationEffect([PortValueDescription(value: 45, value_type: "number")])
    """
    )

    static let rotation3DEffectPortValueDescription = MappingCodeExample(
        title: "rotation3DEffect with PortValueDescription",
        code:
    """
    Rectangle()
        .rotation3DEffect(
            [PortValueDescription(value: 60, value_type: "number")],
            axis: [
                PortValueDescription(
                    value: ["x": 0, "y": 1, "z": 0],
                    value_type: "3dPoint"
                )
            ]
        )
    """
    )

    static let rotationEffectPortValueDescriptionVariable = MappingCodeExample(
        title: "rotationEffect with PortValueDescription variable",
        code:
    """
    Rectangle()
        .rotationEffect([PortValueDescription(value: rotationAngle, value_type: "number")])
    """
    )

    static let rotation3DEffectPortValueDescriptionMultiAxis = MappingCodeExample(
        title: "rotation3DEffect with PortValueDescription multi-axis",
        code:
    """
    Text("3D Rotated")
        .rotation3DEffect(
            [PortValueDescription(value: 45, value_type: "number")],
            axis: [
                PortValueDescription(
                    value: ["x": 1, "y": 1, "z": 0],
                    value_type: "3dPoint"
                )
            ]
        )
    """
    )

}
