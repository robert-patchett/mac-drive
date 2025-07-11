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

#if HAS_QA_FEATURES

import AppKit
import PDCore

/// Populates the status item which displays global progress information in the status bar.
@MainActor
class GlobalProgressStatusItem {
    var progressStatusItem: NSStatusItem!

    init() {
        self.makeStatusItem()
    }

    private func makeStatusItem() {
        self.progressStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.progressStatusItem.button?.font = NSFont.labelFont(ofSize: NSFont.labelFontSize)
    }

    func toggleGlobalProgressStatusItem() {
        let shouldHideStatusItem = !UserDefaults.standard.bool(forKey: QASettingsConstants.globalProgressStatusMenuEnabled)
        UserDefaults.standard.set(shouldHideStatusItem, forKey: QASettingsConstants.globalProgressStatusMenuEnabled)
        if shouldHideStatusItem {
            hide()
        } else {
            // We don't update when reshowing - we have to wait until the next progress update,
            // as we don't have access to the global progresses from here.
        }
    }

    func updateProgress(downloadProgress: Progress?, uploadProgress: Progress?) {
        Log.trace()

        var accumulated = ""
        if !UserDefaults.standard.bool(forKey: QASettingsConstants.globalProgressStatusMenuEnabled) {
            for progress in [downloadProgress, uploadProgress].compactMap({ $0 }) {
                let text: String
                let isDownload = progress == downloadProgress
                let direction = isDownload ? "⬇️" : "⬆️"
                if progress.isFinished {
                    text = "\(direction) Idle"
                } else {
                    let fileTotalCount = progress.fileTotalCount ?? 0
                    let currentFileIndex = min(fileTotalCount, 1 + (progress.fileCompletedCount ?? 0))
                    let additionalDescription = progress.localizedAdditionalDescription ?? ""
                    let percent = 100 * progress.fractionCompleted
                    if fileTotalCount == 0, additionalDescription.isEmpty {
                        text = "\(direction) Confused??"
                    } else {
                        let countInfo = fileTotalCount == 1 ? "1 file"
                        : "\(currentFileIndex) of \(fileTotalCount) files"
                        text = "\(direction) \(countInfo): \(additionalDescription) \(String(format: "(%.2f%%)", percent))"
                    }
                }

                if !accumulated.isEmpty {
                    accumulated.append(" | ")
                }
                accumulated.append(text)
            }
        }

        // If we are hidden (or end up with an empty string), we use a space as otherwise our status item ends up
        // unclickable with zero width so we can't show it again.
        progressStatusItem.button?.title = accumulated.isEmpty ? " " : accumulated
        progressStatusItem.button?.sizeToFit()
    }

    public func hide() {
        updateProgress(downloadProgress: nil, uploadProgress: nil)
    }
}

#endif
