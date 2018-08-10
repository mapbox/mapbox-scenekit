import Foundation

/**
 Helper to track rendering progress when there are multiple fetch stages to account for.
 **/
class ProgressCompositor {
    var progressHandlers: [(Float, Int)] = [(Float, Int)]()
    private let progressUpdater: (_ progress: Float) -> Void
    private let completionNotifier: () -> Void

    init(updater: @escaping (_ progress: Float) -> Void, completer: @escaping () -> Void) {
        progressUpdater = updater
        completionNotifier = completer
    }

    func registerForProgress() -> Int {
        progressHandlers.append((0.0, 0))
        return progressHandlers.count - 1
    }

    func updateProgress(handlerID: Int, progress: Float, total: Int) {
        guard progressHandlers.count > handlerID else { return }
        progressHandlers[handlerID] = (progress, total)
        let newProgress = currentProgress()
        progressUpdater(newProgress)
        if newProgress == 1.0 {
            progressHandlers.removeAll()
            completionNotifier()
        }
    }

    func currentProgress() -> Float {
        guard progressHandlers.count > 0 else {
            return 0.0
        }

        let totalNeeded: Int = progressHandlers.reduce(0, { result, progress in
            result + progress.1
        })
        guard totalNeeded > 0 else {
            return 0.0
        }
        let progress: Float = progressHandlers.reduce(0, { result, progress in
            result + progress.0 * (Float(progress.1) / Float(totalNeeded))
        })
        return progress
    }
}
