import XCTest
@testable import FluentCore

final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testURLSessionHTTPClientReturnsHTTPResponse() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session)
        let expectation = expectation(description: "http")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, Data("payload".utf8))
        }

        client.send(URLRequest(url: URL(string: "https://example.com")!)) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.0, Data("payload".utf8))
                XCTAssertEqual(response.1.statusCode, 201)
            case .failure:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testURLSessionHTTPClientDefaultInitializer() {
        let client = URLSessionHTTPClient()
        XCTAssertNotNil(client)
    }

    func testURLSessionHTTPClientReturnsInvalidResponseForNonHTTP() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session)
        let expectation = expectation(description: "invalid")

        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        client.send(URLRequest(url: URL(string: "https://example.com")!)) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual(error as? AIProviderError, .invalidResponse)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testURLSessionHTTPClientReturnsUnderlyingNetworkError() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session)
        let expectation = expectation(description: "network")

        MockURLProtocol.requestHandler = { _ in
            throw TestError.failed
        }

        client.send(URLRequest(url: URL(string: "https://example.com")!)) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("TestError"))
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testURLSessionHTTPClientUsesEmptyDataWhenResponseBodyIsNil() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = URLSessionHTTPClient(session: session)
        let expectation = expectation(description: "nil-data")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        client.send(URLRequest(url: URL(string: "https://example.com")!)) { result in
            switch result {
            case .success(let payload):
                XCTAssertEqual(payload.0, Data())
                XCTAssertEqual(payload.1.statusCode, 204)
            case .failure:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
