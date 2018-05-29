import Foundation

internal class AsyncOperation: Operation {
    private let stateLock = NSLock()

    private var _ready: Bool = true
    override var isReady: Bool {
        get {
            return stateLock.withCriticalScope { _ready }
        }
        set {
            willChangeValue(forKey: "isReady")

            stateLock.withCriticalScope {
                if _ready != newValue {
                    _ready = newValue
                }
            }

            didChangeValue(forKey: "isReady")
        }
    }

    private var _executing: Bool = false
    override var isExecuting: Bool {
        get {
            return stateLock.withCriticalScope { _executing }
        }
        set {
            willChangeValue(forKey: "isExecuting")

            stateLock.withCriticalScope {
                if _executing != newValue {
                    _executing = newValue
                }
            }

            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _finished: Bool = false
    override var isFinished: Bool {
        get {
            return stateLock.withCriticalScope { _finished }
        }
        set {
            willChangeValue(forKey: "isFinished")

            stateLock.withCriticalScope {
                if _finished != newValue {
                    _finished = newValue
                }
            }

            didChangeValue(forKey: "isFinished")
        }
    }

    override func cancel() {
        super.cancel()

        if isExecuting {
            isExecuting = false
        }
    }

    override var isAsynchronous: Bool {
        return true
    }
}

fileprivate extension NSLock {
    func withCriticalScope<T>(block: () -> T) -> T {
        lock()
        let value = block()
        unlock()
        return value
    }
}
