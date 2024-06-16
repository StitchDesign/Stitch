//
//  OutputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/14/21.
//

import SwiftUI

func getBottomOutput(output: Output,
                     activePort: OutputCoordinate?,
                     activeIndex: Int,
                     flashes: FlashDict,
                     edges: Edges,
                     patch: Patch,
                     imageLibrary: ImageLibrary,
                     videoLibrary: VideoLibrary) -> OutputView {

    let color: Color = outputDotColor(
        output: output,
        activePort: activePort,
        edges: edges,
        flashes: flashes,
        activeIndex: activeIndex)

    let hasEdge = hasEdge(.output(output.coordinate), edges)
    let hasLoopEdge = hasEdge && output.values.count > 1

    return OutputView(id: output.coordinate,
                      output: output,
                      patchName: patch,
                      portDotColor: color,
                      activeIndex: activeIndex,
                      imageLibrary: imageLibrary,
                      videoLibrary: videoLibrary,
                      hasEdge: hasEdge,
                      hasLoopEdge: hasLoopEdge)
}

struct OutputView: View, Identifiable {
    let id: OutputCoordinate
    let output: Output
    let patchName: Patch
    let portDotColor: Color
    let activeIndex: Int
    let imageLibrary: ImageLibrary
    let videoLibrary: VideoLibrary

    let hasEdge: Bool
    let hasLoopEdge: Bool

    var adjustedIndex: Int {
        getAdjustedActiveIndex(activeIndex: activeIndex,
                               loopLength: output.values.count)
    }

    var valueAtIndex: PortValue {
        output.values[adjustedIndex]
    }

    var body: some View {

        HStack {
            IdView(id: output.id, nodeId: id.nodeId)

            // splitter nodes do not show their output's data
            if patchName != .splitter {
                if let (fields, _) = valueAtIndex.asMultipleFields {
                    ForEach(fields, id: \.fieldIndex) { (field: Field) in
                        ValueDisplayView(
                            display: field.fieldValue.display,
                            id: id.nodeId)
                    }
                } else {
                    if let image = valueAtIndex.getImage {
                        ValueImageView(
                            image: image.image(imageLibrary),
                            metadata: image.metadata,
                            id: id.nodeId)

                    } else if let video = valueAtIndex.getVideo {
                        ValueImageView(
                            image: videoLibrary[video.videoURL]?.thumbnail ?? defaultUIImage(),
                            metadata: ImageMetadata(video.metadata),
                            id: id.nodeId)

                    } else if let json = valueAtIndex.getJSON {
                        ValueJSONView(json: json,
                                      id: id.nodeId)
                    } else {
                        ValueDisplayView(
                            display: valueAtIndex.display,
                            id: id.nodeId)
                    }
                }
            } // patchName != .splitter

            OutputLabelView(id: id,
                            valueAtIndex: valueAtIndex,
                            patchName: patchName,
                            output: output,
                            portDotColor: portDotColor,
                            hasEdge: hasEdge,
                            hasLoopEdge: hasLoopEdge)

        }.frame(maxHeight: PORT_AND_EDGE_WIDTH)
    }
}

// struct OutputView_Previews: PreviewProvider {
//    static var previews: some View {
//        OutputView()
//    }
// }
