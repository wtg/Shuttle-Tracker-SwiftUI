import Foundation

class MockURLProtocol: URLProtocol {
    // URLs to mock-data or errors we want to return
    static var mockResponses: [URL: Result<Data, Error>] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url, let responseResult = MockURLProtocol.mockResponses[url] else {
            fatalError("No mock response set for URL: \(request.url?.absoluteString ?? "Unknown")")
        }

        switch responseResult {
        case .success(let data):
            // successful HTTP 200 response
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        case .failure(let error):
            // network failure
            client?.urlProtocol(self, didFailWithError: error)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
