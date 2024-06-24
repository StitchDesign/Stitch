//
//  ComponentActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/31/23.
//

import Foundation
import StitchSchemaKit

// TODO: implement this
struct CustomComponentSelected: AppEvent {
    let id: UUID

    func handle(state: AppState) -> AppResponse {
        .noChange
    }
}

struct DefaultComponentSelected: GraphEvent {
    let defaultComponent: DefaultComponents

    func handle(state: GraphState) {
        // TODO: will come back here

        //        log("DefaultComponentSelected: defaultComponent: \(defaultComponent.rawValue)")
        //
        //        guard let destinationProject = state.currentProject else {
        //            log("DefaultComponentSelected called without current project")
        //            return .noChange
        //        }
        //
        //        let component = state.defaultComponents
        //            .first { (_: ComponentId, value: Component) in
        //                value.componentName == defaultComponent.rawValue }
        //
        //        guard let component = component?.value,
        //              let currentGraph = destinationProject.schema else {
        //            log("DefaultComponentSelected: could not find defaultComponent: \(defaultComponent)")
        //            return .noChange
        //        }
        //
        //        return nodesPasted(copiedState: .fromComponent(component),
        //                           destinationGraph: currentGraph,
        //                           environment: environment)?
        //            .toAppResponse(existingAppState: state) ?? .noChange
    }
}

// TODO: introduce a different file extension for components, e.g. .stitchComponent instead of .stitch ?

// A default component is stored as a .stitch file in `Default Components/` dir,
// just as a sample project is a .stitch file stored in `SampleProjects/`.
// func importDefaultComponents(_ fileManager: StitchFileManager) async -> ComponentsDict {
//
//    var components = ComponentsDict()
//
//    // TODO: `buildProject` returns a `BuildLibrary` side-effect for loading imported media; this logic needs to be revisited when we fix 'copy-pasting of media into a separate project'
//    //    var effects = SideEffects()
//
//    for defaultComponent in DefaultComponents.allCases {
//
//        switch await getProjectFromBundle(from: defaultComponent.rawValue,
//                                          fileManager: fileManager,
//                                          isComponent: true) {
//
//        // TODO: what to do when we fail to import the project? Show message to user? Silently fail?
//        case .failure(let error):
//            log("importDefaultComponents: error: \(error.description)")
//
//        case .success(let projectSchema):
//            if let graphSchema = projectSchema.schema {
//                if let component = Component(from: graphSchema) {
//                    log("importDefaultComponents: success: \(component.componentName)")
//                    log("importDefaultComponents: success: \(component.id)")
//                    components.updateValue(component,
//                                           forKey: component.componentId)
//                    //                    effects += result.effects
//                } // if let component = ...
//                else {
//                    log("importDefaultComponents: could not build component")
//                }
//            } else {
//                log("importDefaultComponents: could not get graphSchema from projectSchema")
//            }
//        }
//    } // for defaultComponent in ...
//
//    return components
// }

// func getProjectFromBundle(from resource: String,
//                          fileManager: StitchFileManager,
//                          isComponent: Bool = false) async -> ProjectSchemaResult {
//
//    switch getProjectURLFromBundle(resource: resource,
//                                   isComponent: isComponent) {
//    case .success(let projectURL):
//        return await fileManager.readProjectSchemaFromZippedFile(
//            projectURL.url,
//            documentsURL: StitchFileManager.documentsURL)
//
//    case .failure(let error):
//        return .failure(error)
//    }
// }
