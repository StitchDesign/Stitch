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
    func onPrototypeRestart(document: StitchDocumentViewModel)
}

protocol SchemaObserverIdentifiable: SchemaObserver where CodableSchema: CodableIdentifiable,
                                                          Self.ID == Self.CodableSchema.ID {
    /// Static function initializer.
    @MainActor
    static func createObject(from entity: CodableSchema) -> Self
}

typealias CodableIdentifiable = StitchVersionedCodable & Identifiable

extension Dictionary where Value: SchemaObserverIdentifiable, Key == Value.ID {
    @MainActor
    mutating func sync(with newEntities: [Value.CodableSchema]) {
        var values = Array(self.values)
        values.sync(with: newEntities)
        
        self = values.reduce(into: Self.init()) { result, observer in
            result.updateValue(observer, forKey: observer.id)
        }
    }
}

extension Array where Element: SchemaObserverIdentifiable {
    @MainActor
    mutating func sync(with newEntities: [Element.CodableSchema]) {
        self.sync(with: newEntities,
                   updateCallback: { viewModel, data in
            viewModel.update(from: data)
        }) { data in
            Element.createObject(from: data)
        }
    }
}

extension Dictionary where Value: Identifiable & AnyObject, Key == Value.ID {
    @MainActor
    func sync<DataElement>(with newEntities: [DataElement],
                           updateCallback: @escaping (Value, DataElement) -> (),
                           createCallback: @escaping (DataElement) -> Value) -> Self where DataElement: Identifiable, DataElement.ID == Value.ID {
        var values = Array(self.values)
        values.sync(with: newEntities,
                    updateCallback: updateCallback,
                    createCallback: createCallback)
        
        return values.reduce(into: Self.init()) { result, observer in
            result.updateValue(observer, forKey: observer.id)
        }
    }
}

extension Array where Element: Identifiable & AnyObject {
    mutating func sync<DataElement>(with newEntities: [DataElement],
                                    updateCallback: @escaping (Element, DataElement) -> (),
                                    createCallback: @escaping (DataElement) -> Element) where DataElement: Identifiable, DataElement.ID == Element.ID {
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
                updateCallback(entity, newEntity)
                return entity
            } else {
                return createCallback(newEntity)
            }
        }
    }
    
    @MainActor
    func sync<DataElement>(with newEntities: [DataElement],
                           updateCallback: @MainActor @escaping (Element, DataElement) async -> (),
                           createCallback: @MainActor @escaping (DataElement) async -> Element) async -> [Element] where DataElement: Identifiable, Element: Sendable, DataElement.ID == Element.ID {
        
//        let incomingIds: Set<Element.ID> = newEntities.map { $0.id }.toSet
//        let currentIds: Set<Element.ID> = self.map { $0.id }.toSet
//        let entitiesToRemove = currentIds.subtracting(incomingIds)

        let currentEntitiesMap = self.reduce(into: [:]) { result, currentEntity in
            result.updateValue(currentEntity, forKey: currentEntity.id)
        }

        // Remove element if no longer tracked by incoming list
//        entitiesToRemove.forEach { idToRemove in
//            self.removeAll { $0.id == idToRemove }
//        }

        // Create or update entities from new list
        var newValues = [Element]()
        for newEntity in newEntities {
            if let entity = currentEntitiesMap.get(newEntity.id) {
                await updateCallback(entity, newEntity)
                newValues.append(entity)
            } else {
                newValues.append(await createCallback(newEntity))
            }
        }
        
        return newValues
    }
}

extension Array where Element: SchemaObserver {
    @MainActor
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.forEach { $0.onPrototypeRestart(document: document) }
    }
}
