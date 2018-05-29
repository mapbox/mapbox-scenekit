import Foundation

internal class HttpRequestOperation: AsyncOperation {
    typealias HttpRequestOperationCallback = (_ success: Bool, _ responseCode: Int, _ data: Data?) -> Void
    static let HTTPOfflineStatusCode = -1

    var taskID = UUID()

    enum HTTPMethod: String {
        case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
    }

    fileprivate var session: URLSession
    fileprivate var url: URL
    fileprivate var method: HTTPMethod
    fileprivate var callback: HttpRequestOperationCallback
    fileprivate var task: URLSessionDataTask?
    fileprivate var headers: [String: String] = [String: String]()

    init(url: URL, headers: [String: String] = [String: String](), method: HTTPMethod = .GET, callback: @escaping HttpRequestOperationCallback, session: URLSession) {
        self.url = url
        self.callback = callback
        self.method = method
        self.session = session
        self.headers = headers
        super.init()
    }

    func clone() -> HttpRequestOperation {
        let newOperation = HttpRequestOperation(url: url, headers: headers, method: method, callback: callback, session: session)
        newOperation.taskID = taskID
        return newOperation
    }

    func buildRequest() -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    override func start() {
        guard !isCancelled else {
            isFinished = true
            return
        }

        isReady = false
        isExecuting = true

        guard let request = buildRequest() else {
            endTaskAndCallbackWithSuccess(false, responseCode: 0)
            return
        }

        task = session.dataTask(with: request) { (data, response, error) in
            guard !self.isCancelled else {
                self.isFinished = true
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("Server response was not HTTP, likely offline")
                self.endTaskAndCallbackWithSuccess(false, responseCode: HttpRequestOperation.HTTPOfflineStatusCode)
                return
            }

            self.handle(response: httpResponse, error: error, data: data)
        }

        task!.resume()
    }

    func handle(response: HTTPURLResponse, error: Error?, data: Data?) {
        guard case 200...304 = response.statusCode else {
            NSLog("Non-OK response from server: \(response.statusCode)")
            self.endTaskAndCallbackWithSuccess(false, responseCode: response.statusCode, data: data)
            return
        }

        if let error = error, response.statusCode > 304 {
            NSLog("Error accessing server: \(error)")
            self.endTaskAndCallbackWithSuccess(false, responseCode: response.statusCode, data: data)
            return
        }

        self.endTaskAndCallbackWithSuccess(true, responseCode: response.statusCode, data: data)
    }

    override func cancel() {
        super.cancel()
        task?.cancel()
    }

    fileprivate func endTaskAndCallbackWithSuccess(_ success: Bool, responseCode: Int, data: Data? = nil) {
        if !isCancelled {
            callback(success, responseCode, data)
        }
        if isExecuting {
            isExecuting = false
        }
        isFinished = true
    }
}
