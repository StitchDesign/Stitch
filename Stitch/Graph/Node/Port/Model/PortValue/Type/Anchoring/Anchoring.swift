//
//  Anchoring.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/21.
//

import SwiftUI
import StitchSchemaKit

/* ---------------------------------------
 DATA
 ------------------------------------------ */

// TODO: if you have e.g. (0.25, 0.75), what (0 vs 0.5 vs 1) anchor point does that become?
// Round up? Round down?

extension CurrentStitchAIPortValue.PortValueVersion.Anchoring { // : PortValueEnum {
    
    // The traditional
    static let topLeft: Self = .init(x: Self.left, y: Self.top)
    static let topCenter: Self = .init(x: Self.center, y: Self.top)
    static let topRight: Self = .init(x: Self.right, y: Self.top)
    static let centerLeft: Self = .init(x: Self.left, y: Self.center)
    // fka `center`
    static let centerCenter: Self = .init(x: Self.center, y: Self.center)
    static let centerRight: Self = .init(x: Self.right, y: Self.center)
    static let bottomLeft: Self = .init(x: Self.left, y: Self.bottom)
    static let bottomCenter: Self = .init(x: Self.center, y: Self.bottom)
    static let bottomRight: Self = .init(x: Self.right, y: Self.bottom)
}


// "how a view anchors itself within the parent"
extension Anchoring { // : PortValueEnum {
    
    // The traditional
    static let topLeft: Self = .init(x: Self.left, y: Self.top)
    static let topCenter: Self = .init(x: Self.center, y: Self.top)
    static let topRight: Self = .init(x: Self.right, y: Self.top)
    static let centerLeft: Self = .init(x: Self.left, y: Self.center)
    // fka `center`
    static let centerCenter: Self = .init(x: Self.center, y: Self.center)
    static let centerRight: Self = .init(x: Self.right, y: Self.center)
    static let bottomLeft: Self = .init(x: Self.left, y: Self.bottom)
    static let bottomCenter: Self = .init(x: Self.center, y: Self.bottom)
    static let bottomRight: Self = .init(x: Self.right, y: Self.bottom)

    static let choices: PortValues = [
        .anchoring(Self.topLeft),
        .anchoring(Self.topCenter),
        .anchoring(Self.topRight),
        .anchoring(Self.centerLeft),
        .anchoring(Self.centerCenter),
        .anchoring(Self.centerRight),
        .anchoring(Self.bottomLeft),
        .anchoring(Self.bottomCenter),
        .anchoring(Self.bottomRight)
    ]
    
    // Traditional Stitch default anchoring
    static let defaultAnchoring: Anchoring = .topLeft
    
    // New anchoring that reflects how SwiftUI .offset is from the center of the parent
    static let DEFAULT_ANCHORING_FOR_SWIFTUI_AI: Anchoring = .centerCenter
    
    static let defaultPivot: Anchoring = .centerCenter

    var toPivot: UnitPoint {
        switch self {
        case .topLeft:
            return .topLeading
        case .centerLeft:
            return .leading
        case .bottomLeft:
            return .bottomLeading
        case .topRight:
            return .topTrailing
        case .centerRight:
            return .trailing
        case .bottomRight:
            return .bottomTrailing
        case .topCenter:
            return .top
        case .centerCenter:
            return .center
        case .bottomCenter:
            return .bottom
        default:
            // SwiftUI's UnitPoint is implemented the same as our Anchoring
            return .init(x: self.x, y: self.y)
        }
    }
    
    var toAlignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .centerLeft:
            return .leading
        case .bottomLeft:
            return .bottomLeading
        case .topRight:
            return .topTrailing
        case .centerRight:
            return .trailing
        case .bottomRight:
            return .bottomTrailing
        case .topCenter:
            return .top
        case .centerCenter:
            return .center
        case .bottomCenter:
            return .bottom
        default:
            return .topLeading
        }
    }
        
    // TODO: how is this used? Do you want "Top Left" or is "(0, 0)" fine?
    var display: String {
        "\(self.y), \(self.x)"
    }
    
    // TODO: should not have to care about versions
    static func fromAlignmentString(_ alignment: String) -> Self? {
        switch alignment {
        case "topLeading":
            return .topLeft
        case "leading":
            return .centerLeft
        case "bottomLeading":
            return .bottomLeft
        case "topTrailing":
            return .topRight
        case "trailing":
            return .centerRight
        case "bottomTrailing":
            return .bottomRight
        case "top":
            return .topCenter
        case "center":
            return .centerCenter
        case "bottom":
            return .bottomCenter
        default:
            return nil
        }
    }

}


// Does this need to change for pinning?
func adjustPosition(size: CGSize, // child's size
                    position: CGPoint, // child's position; UNSCALED
                    anchor: Anchoring, // child's anchor
                    parentSize: CGSize,
                    ignoreOffsetTransform: Bool = false) -> CGPoint {

    let x = position.x
        + (parentSize.width * anchor.x)
    
    // works for left, i.e. when we need to move half of child's length away from left edge;
    // + (size.width/2) * (1.0 - anchor.x)
    
    // when in center, we don't need to adjust at all, so should be +0
    // + (size.width/2) * (0.5 - anchor.x)
    
    // Good; but left needs to be more + and right needs to be more -
    // - (size.width/2) * (anchor.x - 0.5)
    
        // Perfect
        - (size.width * (anchor.x - 0.5))
         
    let y = position.y
        + (parentSize.height * anchor.y)
        - (size.height * (anchor.y - 0.5))
    
    var pos = CGPoint(x: x, y: y)
    
    if !ignoreOffsetTransform {
        pos.x -= parentSize.width/2
        pos.y -= parentSize.height/2
    }
            
    return pos
    
}

struct Anchoring_REPL_View: View {
    
    let childLength = 100.0
    let parentLength = 400.0
    
//     let childPosition: CGSize = .init(x: 50, y: 50)
    let childPosition: CGPoint = .zero
        
    func getPos(_ anchor: Anchoring) -> CGPoint {
        adjustPosition(size: .init(width: childLength, height: childLength),
                       position: childPosition,
                       anchor: anchor,
                       parentSize: .init(width: parentLength, height: parentLength))
    }
    
    
    var body: some View {
        ZStack {
            Rectangle().fill(.indigo).frame(width: childLength, height: childLength)
                .position(getPos(.topLeft))
            Rectangle().fill(.green).frame(width: childLength, height: childLength)
                .position(getPos(.topCenter))
            Rectangle().fill(.yellow).frame(width: childLength, height: childLength)
                .position(getPos(.topRight))
            
            
            Rectangle().fill(.red).frame(width: childLength, height: childLength)
                .position(getPos(.centerLeft))
            
            Rectangle().fill(.blue).frame(width: childLength, height: childLength)
                .position(getPos(.centerCenter))
                .scaleEffect(1.2,
                             anchor: Anchoring.defaultPivot.toPivot)
            
            Rectangle().fill(.black).frame(width: childLength, height: childLength)
                .position(getPos(.centerRight))
            
            Rectangle().fill(.brown).frame(width: childLength, height: childLength)
                .position(getPos(.bottomLeft))
            Rectangle().fill(.orange).frame(width: childLength, height: childLength)
                .position(getPos(.bottomCenter))
            Rectangle().fill(.cyan).frame(width: childLength, height: childLength)
                .position(getPos(.bottomRight))
            
        }
        .frame(width: parentLength, height: parentLength)
        .border(.red, width: 4)
        
        
    }
}

#Preview {
    Anchoring_REPL_View()
}
