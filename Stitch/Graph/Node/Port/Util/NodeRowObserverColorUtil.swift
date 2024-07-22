//
//  NodeRowObserverColorUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

extension PortColor {
    /*
     `isSelected: Bool`: Is the port "selected"? Depending on context, could mean that node is selected, OR edge is selected, OR edge is actively drawn but has eligible-input etc.
     
     `hasLoop: Bool`: Does the port have a loop?
     
     `hasEdge: Bool`: Does the port have an edge?
     */
    init(isSelected: Bool, hasEdge: Bool, hasLoop: Bool) {
        if hasLoop && hasEdge && isSelected {
            self = .highlightedLoopEdge
        } else if hasEdge && isSelected {
            self = .highlightedEdge
        } else if hasLoop && hasEdge {
            self = .loopEdge
        } else if hasEdge {
            self = .edge
        } else {
            self = .noEdge
        }
    }
}

extension NodeRowViewModel {
    // TODO: don't we have an abstract helper here for ANY property?
    // e.g. `self.portColor.setOnChange(newPortColor)`
    func setPortColorIfChanged(_ newPortColor: PortColor) {
        if newPortColor != self.portColor {
            self.portColor = newPortColor
        }
    }
}

extension NodeDelegate {
    /*
     When a node is selected or deselected, for each of its inputs/outptus we must re-derive the color for:
     
     1. the input/output itself
     2. if input: the upstream output, if there is one
     3. if output: the downstream inputs, if there are any
     
     ASSUMES NODE VIEW MODEL'S `isSelected` HAS BEEN UPDATED.
     */
    @MainActor
    func updatePortColorDataUponNodeSelection() {
        Stitch.updatePortColorDataUponNodeSelection(
            inputs: self.allInputRowViewModels,
            outputs: self.allOutputRowViewModels)
    }
}

@MainActor
func updatePortColorDataUponNodeSelection(inputs: [InputNodeRowViewModel],
                                          outputs: [OutputNodeRowViewModel]) {
    inputs.forEach { input in
        input.updateColorOfInputAndUpstreamOutput()
    }
    
    outputs.forEach { output in
        output.updateColorOfOutputAndDownstreamInputs()
    }
}

extension InputNodeRowViewModel {
    @MainActor
    func updateColorOfInputAndUpstreamOutput() {
        
        self.updatePortColor()
        
        // Update upstream-output
        if let output = self.rowDelegate?.upstreamOutputObserver {
            output.allRowViewModels.forEach {
                $0.updatePortColor()
            }
        }
    }
}

extension OutputNodeRowViewModel {
    @MainActor
    func updateColorOfOutputAndDownstreamInputs() {
        self.updatePortColor()
        
        // Update downstream-inputs
        if let rowDelegate = self.rowDelegate,
           let graphDelegate = rowDelegate.nodeDelegate?.graphDelegate {
            graphDelegate.connections
                .get(rowDelegate.id)?
                .compactMap { graphDelegate.getInputObserver(coordinate: $0) }
                .flatMap { $0.allRowViewModels }
                .forEach { downstreamInput in
                    downstreamInput.updatePortColor()
                }
        }
    }
}
