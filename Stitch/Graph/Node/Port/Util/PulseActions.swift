//
//  PulseActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// How long we have the pulse's port-value coercion effect before reverting.
// NOTE: converted later to milliseconds
let PULSE_LENGTH: Int = 100

// TODO: use Set<Coordinate>, instead of Dict<Coordinate: Bool> ?
// coordinate because could be output or input
// Coordinate: Pulsed?
// typealias FlashDict = [Coordinate: Bool]

typealias FlashSet = Set<Coordinate>

struct PulseValueButtonClicked: GraphEvent {
    
    let coordinate: InputCoordinate
    
    func handle(state: GraphState) {
        state.pulseValueButtonClicked(coordinate)
    }
}

extension GraphState {
    @MainActor
    func pulseValueButtonClicked(_ coordinate: InputCoordinate) {
        //        log("PulseValueButtonClicked called: nodeId: \(nodeId)")
        //        log("PulseValueButtonClicked inputCoordinate: \(inputCoordinate)")

        // TODO: how to disable `PulseValueButtonView` if node is being dragged?
        // Problem: any touch of the node is picked up by NodeInteractiveView's long-press GestureRecognizer, which then sets `state.graphUI.graphMovement.nodeIsDragged = true`.
        // Solution?: differentiate between long-press's touch vs actually dragging the node

        //        // if pulse-value button was pressed as part of a node drag,
        //        // do nothing.
        //        if state.graphUI.graphMovement.nodeIsDragged {
        //            log("PulseValueButtonClicked: doing nothing since nodes are dragged")
        //            return .noChange
        //        }

        

        //        guard let inputCoordinate = inputCoordinate else {
        //            log("PulseValueButtonClicked: Did not have input coordinate")
        //            return .stateOnly(state)
        //        }

        let nodeId: NodeId = coordinate.nodeId
                
        guard let node = self.getNodeViewModel(nodeId),
              let inputObserver = node.getInputRowObserver(for: coordinate.portType),
                // inputPort.rowDelegate,
              // Can't manually pulses with upstream observer
              !inputObserver.upstreamOutputObserver.isDefined else {
            return
        }
        
        // Select canvas if associated here
        if let canvasItem = inputObserver.nodeRowViewModel?.canvasItemDelegate { // inputPort.canvasItemDelegate {
            self.selectSingleNode(canvasItem)
        }
        
        inputObserver.updateValues([.pulse(self.graphStepState.graphTime)])
        
        self.calculate(nodeId)
    }
}

func shouldPulse(currentTime: TimeInterval,
                 lastTimePulsed: TimeInterval,
                 pulseEvery: TimeInterval) -> Bool {

    let diff = currentTime - lastTimePulsed

    //    log("shouldPulse: currentTime: \(currentTime)")
    //    log("shouldPulse: lastTimePulsed: \(lastTimePulsed)")
    //    log("shouldPulse: diff: \(diff)")
    //    log("shouldPulse: pulseEvery: \(pulseEvery)")

    return diff >= pulseEvery
}

// TODO: recalculate the graph only once for all pulses outputs,
// rather than recalculating the graph for every pulsed output.
struct ReversePulseCoercion: StitchDocumentEvent {
    
    let pulsedOutput: OutputCoordinate
    
    func handle(state: StitchDocumentViewModel) {
        // Cannot recalculate full node in some examples (like delay node)
        // so we just update downstream nodes
        guard let node = state.getNodeViewModel(pulsedOutput.nodeId),
              let currentOutputs = node.getOutputRowObserver(for: pulsedOutput.portType)?.allLoopedValues else {
//                  fatalErrorIfDebug("ReversePulseCoercion error: data not found.")
                  return
              }
        
        // Reverse the values in the downstream inputs
        let changedDownstreamNodeIds = state
            .updateDownstreamInputs(flowValues: currentOutputs,
                                    outputCoordinate: pulsedOutput)
        
        // Run the downstream inputs' node evals
        state.calculate(changedDownstreamNodeIds)
    } // handle
}

func pulseCoercionReversedEffect(_ pulsedOutput: OutputCoordinate) -> Effect {
    //    log("pulseCoercionReversedEffect called")
    return createDelayedEffect(
        delayInNanoseconds: Double(PULSE_LENGTH * nanoSecondsInMillisecond),
        action: ReversePulseCoercion(pulsedOutput: pulsedOutput))
}

func getPostPulseEffects(_ coordinate: Coordinate) -> SideEffects {
    //    log("getPostPulseEffects called")
    var effects = SideEffects()

    if case let .output(outputCoordinate) = coordinate {
        effects.append(pulseCoercionReversedEffect(outputCoordinate))
    }

    return effects
}
