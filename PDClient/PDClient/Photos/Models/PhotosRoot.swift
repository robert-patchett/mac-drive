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

public struct PhotosRoot {

    public let link: Link
    public let share: Share

    public init(link: LinkEndpoint.Response.Link, share: Share) {
        self.link = link
        self.share = share
    }

}

public struct Root {
    public let link: LinkEndpoint.Response.Link
    public let share: ShareMetadata

    public init(link: LinkEndpoint.Response.Link, share: ShareMetadata) {
        self.link = link
        self.share = share
    }
}
