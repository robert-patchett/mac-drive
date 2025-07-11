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

import Combine
import ProtonCoreNetworking

/// Adds retry mechanism with exponential backoff
public final class NetworkErrorHandlingCommand: Command {
    private let interactor: any ThrowingAsynchronousWithoutDataInteractor
    private var task: Task<Void, Never>?

    public init(interactor: any ThrowingAsynchronousWithoutDataInteractor) {
        self.interactor = interactor
    }

    deinit {
        task?.cancel()
    }

    public func execute() {
        task = Task.detached(priority: .background) { [weak self] in
            await self?.executeWithPotentialRetry()
        }
    }

    private func executeWithPotentialRetry(attempt: Int = 0) async {
        guard !Task.isCancelled else {
            return
        }

        guard attempt < 10 else {
            Log.error("Reached maximal number of network issues. Cancelling command now.", error: nil, domain: .networking)
            return
        }

        do {
            try await interactor.execute()
        } catch let error as ResponseError {
            if error.isRetryableIncludingInternetIssues {
                Log.info("Received networking issue, will retry after exponential backoff", domain: .networking)
                try? await Task.sleep(for: .seconds(ExponentialBackoffWithJitter.getDelay(attempt: attempt)))
                await executeWithPotentialRetry(attempt: attempt + 1)
            } else {
                Log.error(nil, error: error, domain: .networking)
            }
        } catch {
            Log.error(nil, error: error, domain: .networking)
        }
    }
}
