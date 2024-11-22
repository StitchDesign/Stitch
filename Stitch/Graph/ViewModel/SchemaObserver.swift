//
//  SchemaObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/22/24.
//

import Foundation
import StitchSchemaKit

protocol SchemaObserver: AnyObject, Identifiable {
    associatedtype CodableSchema: StitchVersionedCodable

    /// Update view model.
    @MainActor
    func update(from schema: CodableSchema)

    /// Encode view model.
    @MainActor
    func createSchema() -> CodableSchema
    
    @MainActor
    func onPrototypeRestart()
}

protocol SchemaObserverIdentifiable: SchemaObserver where CodableSchema: CodableIdentifiable {
    /// Static function initializer.
    @MainActor
    static func createObject(from entity: CodableSchema) -> Self
}

extension NodePortInputEntity: Identifiable { }

typealias CodableIdentifiable = StitchVersionedCodable & Identifiable

extension Array where Element: SchemaObserverIdentifiable {
    @MainActor
    mutating func sync(with newEntities: [Element.CodableSchema]) where Element.ID == Element.CodableSchema.ID {
        let incomingIds: Set<Element.ID> = newEntities.map { $0.id }.toSet
        let currentIds: Set<Element.ID> = self.map { $0.id }.toSet
        let entitiesToRemove = currentIds.subtracting(incomingIds)

        let currentEntitiesMap = self.reduce(into: [:]) { result, currentEntity in
            result.updateValue(currentEntity, forKey: currentEntity.id)
        }

        // Remove element if no longer tracked by incoming list
        entitiesToRemove.forEach { idToRemove in
            self.removeAll { $0.id == idToRemove }
        }

        // Create or update entities from new list
        self = newEntities.map { newEntity in
            if let entity = currentEntitiesMap.get(newEntity.id) {
                entity.update(from: newEntity)
                return entity
            } else {
                return Element.createObject(from: newEntity)
            }
        }
    }
}

extension Array where Element: SchemaObserver {
    @MainActor
    func onPrototypeRestart() {
        self.forEach { $0.onPrototypeRestart() }
    }
}
