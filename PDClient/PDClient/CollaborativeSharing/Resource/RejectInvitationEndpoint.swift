// Copyright (c) 2024 Proton AG
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

public struct RejectInvitationParameters {
    let invitationID: String

    public init(invitationID: String) {
        self.invitationID = invitationID
    }
}

public struct RejectInvitationResponse: Codable {
    public let code: Int
}

/// Reject invitation
/// - POST: /drive/v2/shares/invitations/{invitationID}/reject
public struct RejectInvitationEndpoint: Endpoint {
    public typealias Response = RejectInvitationResponse

    public var request: URLRequest

    public init(parameters: RejectInvitationParameters, service: APIService, credential: ClientCredential) {
        // url

        let url = service.url(of: "/v2/shares/invitations/\(parameters.invitationID)/reject")

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}
