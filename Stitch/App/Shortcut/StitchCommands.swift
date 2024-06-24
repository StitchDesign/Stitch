//
//  StitchCommands.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/22.
//

import SwiftUI

struct StitchCommands: Commands {

    @Bindable var store: StitchStore
    let activeReduxFocusedField: FocusedUserEditField?

    var body: some Commands {
        /*
         Notes:

         When we have an active project (i.e. graph open),
         CMD+R should reset the prototype instead of refreshing the projects.

         We disable "Select All via CMD+A" when we have a text field actively focused;
         thus allowing for system's CMD+A to select input text.
         */

        ProjectsHomeCommands(store: store,
                             activeReduxFocusedField: activeReduxFocusedField)

        // TODO: Why were these commands being ignored?
        //        GraphCommands()
    }
}
