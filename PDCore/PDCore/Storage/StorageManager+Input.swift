// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation
import CoreData

public protocol ManagedStorage {
    func unique<Entity: NSManagedObject>(with ids: Set<String>, uniqueBy keyPath: String, allowSubclasses: Bool, in moc: NSManagedObjectContext) -> [Entity]
    func new<Entity: NSManagedObject>(with id: String, by keyPath: String, in moc: NSManagedObjectContext) -> Entity
    func existing<Entity: NSManagedObject>(with ids: Set<String>, by keyPath: String, allowSubclasses: Bool, in moc: NSManagedObjectContext) -> [Entity]
    func exists(with id: String, by keyPath: String, entityName: String, in moc: NSManagedObjectContext) -> Bool
}

extension StorageManager {
    func removeOldBlocks(of revisionObj: PDCore.Revision) {
        let oldBlocks = revisionObj.blocks
        let moc = revisionObj.managedObjectContext!
        moc.performAndWait {
            revisionObj.blocks = Set([])
            oldBlocks.forEach(moc.delete)
        }
    }
}

// MARK: - Generic NSManagedObject methods

extension ManagedStorage {
    /// Returns list of objects with named ids, finds present ones and creates new ones for missing ids
    public func unique<Entity: NSManagedObject>(with ids: Set<String>,
                                                uniqueBy keyPath: String = "id",
                                                allowSubclasses: Bool = false,
                                                in moc: NSManagedObjectContext) -> [Entity]
    {
        let existing: [Entity] = self.existing(with: ids, by: keyPath, allowSubclasses: allowSubclasses, in: moc)
        var presentObjects: [Entity] = existing

        let presentIds = Set(presentObjects.compactMap { $0.value(forKey: keyPath) as? String })
        let newIds = Set(ids).subtracting(presentIds)

        let newObjects: [Entity] = newIds.map { self.new(with: $0, by: keyPath, in: moc) }
        presentObjects.append(contentsOf: newObjects)

        return presentObjects
    }

    /// Creates new object with named id
    public func new<Entity: NSManagedObject>(with id: String, by keyPath: String, in moc: NSManagedObjectContext) -> Entity {
        let new = NSEntityDescription.insertNewObject(forEntityName: Entity.entity().managedObjectClassName, into: moc)
        new.setValue(id, forKey: keyPath)
        return new as! Entity
    }

    public func existing<Entity: NSManagedObject>(with ids: Set<String>, by keyPath: String = "id", allowSubclasses: Bool = false, in moc: NSManagedObjectContext) -> [Entity] {
        let fetchRequest = NSFetchRequest<Entity>()
        fetchRequest.entity = Entity.entity()
        if allowSubclasses {
            // This allows also child entities
            fetchRequest.predicate = NSPredicate(format: "(%K IN %@)", keyPath, ids)
        } else {
            // This allows only specific entity types
            fetchRequest.predicate = NSPredicate(format: "(%K IN %@ AND self.entity == %@)", keyPath, ids, Entity.entity())
        }
        return (try? moc.fetch(fetchRequest) ) ?? []
    }

    public func existing<Entity: NSManagedObject>(id: String, allowSubclasses: Bool = false, in moc: NSManagedObjectContext) throws -> Entity? {
        let fetchRequest = NSFetchRequest<Entity>()
        fetchRequest.entity = Entity.entity()

        if allowSubclasses {
            fetchRequest.predicate = NSPredicate(format: "(%K == %@)", "id", id)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(%K == %@ AND self.entity == %@)", "id", id, Entity.entity())
        }
        fetchRequest.fetchLimit = 1 // Limit the fetch to only one object
        return try moc.fetch(fetchRequest).first
    }

    public func exists(with id: String,
                       by keyPath: String = "id",
                       entityName: String = "Node",
                       in moc: NSManagedObjectContext) -> Bool
    {
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "(%K IN %@)", keyPath, [id])
        fetchRequest.includesSubentities = true
        fetchRequest.resultType = .countResultType

        return moc.performAndWait {
            do {
                let count = try moc.fetch(fetchRequest)
                return count.first?.intValue != 0
            } catch let error {
                assert(false, error.localizedDescription)
                return false
            }
        }
    }
}

// MARK: - API for single objects
extension ManagedStorage {
    public func unique<Entity: NSManagedObject, Value>(forId id: String, keyPath: KeyPath<Entity, Value>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Entity {
        if let existing: Entity = existing(forId: id, keyPath: keyPath, allowSubclasses: allowSubclasses, in: context) {
            return existing
        }
        let keyPath = NSExpression(forKeyPath: keyPath).keyPath
        return new(with: id, by: keyPath, in: context)
    }

    public func existing<Entity: NSManagedObject, Value>(forId id: String, keyPath: KeyPath<Entity, Value>, allowSubclasses: Bool = false, in context: NSManagedObjectContext) -> Entity? {
        let keyPath = NSExpression(forKeyPath: keyPath).keyPath
        let fetchRequest = NSFetchRequest<Entity>()
        fetchRequest.entity = Entity.entity()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = allowSubclasses
            ? NSPredicate(format: "%K == %@", keyPath, id)
            : NSPredicate(format: "%K == %@ AND self.entity == %@", keyPath, id, Entity.entity())

        return try? context.fetch(fetchRequest).first
    }
}
