// Copyright (c) 2025 Proton AG
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

public final class CoreDataPhotoTagSerializer {
    private static let separator = ","
    private static let padding = "-"

    public init() {}

    public func serialize(tag: Int) -> String {
        return "\(CoreDataPhotoTagSerializer.padding)\(tag)\(CoreDataPhotoTagSerializer.padding)"
    }

    public func deserialize(rawTag: String) -> Int? {
        let numberString = rawTag.replacing(CoreDataPhotoTagSerializer.padding, with: "")
        return Int(numberString)
    }

    public func serialize(tags: [Int]) -> String {
        return tags.map(serialize(tag:)).joined(separator: ",")
    }

    public func deserialize(rawTags: String) -> [Int] {
        return rawTags.split(separator: ",")
            .compactMap { deserialize(rawTag: String($0)) }
    }
}
