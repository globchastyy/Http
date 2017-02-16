//
//  HttpExtensions.swift
//  Http
//
//  Created by Alexey Globchastyy on 23/01/2017.
//
//

import Foundation
import KituraNet
import SwiftyJSON

fileprivate extension ClientResponse {
    func readJSON() -> JSON? {
        var data = Data()

        _ = try? self.read(into: &data)

        let json = JSON(data: data)
        if json == .null { return nil }

        return json
    }

    func readData() -> Data? {
        var data = Data()

        if let _ = try? self.read(into: &data) {
            return data
        } else {
            return nil
        }
    }
}


public final class http {
    public class func escape(url: String) -> String {
        return HTTP.escape(url: url)
    }

    public class func post(_ url: String, body: [String: Any]? = nil, headers: [String: String]? = nil, completion: @escaping (JSON?) -> Void) {
        HTTP.post(url, body: body ?? [:], headers: headers ?? [:]) {
            completion($0?.readJSON())
        }
    }

    public class func post(_ url: String, body: [String: Any]? = nil) {
        post(url, body: body) { result in }
    }

    public class func get(_ url: String, params: [String: Any]? = nil, completion: @escaping (JSON?) -> Void) {
        _ = HTTP.get(url) {
            completion($0?.readJSON())
        }
    }

    public class func getString(_ url: String, headers: [String: String], completion: @escaping (String?) -> Void) {
        _ = HTTP.get(url, headers: headers) {
            guard let result = try? $0?.readString() else { return completion(nil) }
            completion(result)
        }
    }

    public class func get(_ url: String, headers: [String: String], completion: @escaping (JSON?) -> Void) {
        _ = HTTP.get(url, headers: headers) {
            completion($0?.readJSON())
        }
    }


    public class func get(_ url: String, params: [String: Any]? = nil) {
        get(url, params: params) { result in }
    }
}

fileprivate extension HTTP {
    class func post(_ url: String,  body: [String: Any], headers: [String: String], callback: @escaping ClientRequest.Callback) {
        var options: [ClientRequest.Options] = []
        options.append(.schema("")) // so that ClientRequest doesn't apend http
        options.append(.method("POST")) // set method of request
        guard var urlRequest = URL(string: url).flatMap({ URLRequest(url: $0) }) else { return }
        urlRequest.httpMethod = "POST"


        try! URLEncoding.default.encode(&urlRequest, parameters: body)

        options.append(.hostname(urlRequest.url!.absoluteString))

        options.append(.headers(headers))

        if let headers = urlRequest.allHTTPHeaderFields {
            print(headers)
            options.append(.headers(headers))
        }



        guard let body = urlRequest.httpBody else { return }
        let request = HTTP.request(options, callback: callback)
        request.write(from: body)

        request.end()

    }

    class func get(_ url: String, headers: [String: String], callback: @escaping ClientRequest.Callback) {
        var options: [ClientRequest.Options] = []
        options.append(.schema("")) // so that ClientRequest doesn't apend http
        options.append(.method("GET")) // set method of request
        guard var urlRequest = URL(string: url).flatMap({ URLRequest(url: $0) }) else { return }
        urlRequest.httpMethod = "GET"


        options.append(.hostname(urlRequest.url!.absoluteString))

        // headers
        options.append(.headers(headers))

        if let headers = urlRequest.allHTTPHeaderFields {
            options.append(.headers(headers))
        }

        let request = HTTP.request(options, callback: callback)

        request.end()

    }

}


/// URL data encoder.
fileprivate  struct URLEncoding: Encoding {

    /// URL encoding mode.
    enum Mode {

        /// Default url encoding mode.
        case `default`

        /// Encoding parameters to url query.
        case urlQuery

        /// Encoding parameters to http body.
        case httpBody
    }

    /// Default `URLEncoding` instance
    static let `default` = URLEncoding(mode: .default)

    /// URL encoding mode.
    private(set) var mode: Mode

    /// Initializes new `URLEncoding` class.
    ///
    /// - Parameter mode: URL encoding mode.
    init(mode: Mode) {
        self.mode = mode
    }

    /// Encode parameters as query or application/x-www-form-urlencoded
    ///
    /// - Parameter request: URL request used in encoding.
    /// - Parameter parameters: parameters of the request.
    func encode(_ request: inout URLRequest, parameters: [String: Any]?) throws {
        guard let parameters = parameters,
            !parameters.isEmpty else {
                return
        }

        let method = request.httpMethod ?? "GET"

        if self.shouldEncodeInQuery(using: method) {
            guard let url = request.url,
                let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    return
            }

            components.query = URLEncoding.getQuery(from: parameters)

            guard let newURL = components.url else {
                return
            }

            request.url = newURL
        } else {
            let query = URLEncoding.getQuery(from: parameters)

            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

            request.httpBody = query.data(using: .utf8, allowLossyConversion: false)
        }
    }

    /// Determines if parameters should be encoded in query or request body
    ///
    /// - Parameter method: request method.
    ///
    /// - Returns: a valude describing if parameters should be encoded in query or not.
    private func shouldEncodeInQuery(using method: String) -> Bool {
        switch (self.mode, method) {
        case (.urlQuery, _):
            return true
        case (.httpBody, _):
            return false
        case (_, "GET"), (_, "HEAD"):
            return true
        default:
            return false
        }
    }

    /// Get query string from parameters.
    ///
    /// - Parameter parameters: request parameters.
    ///
    /// - Returns: a query string.
    private static func getQuery(from parameters: [String: Any]) -> String {
        let query = self.getComponents(from: parameters)
        return query.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}


/// Common encoding protocol.
fileprivate protocol Encoding {

    /// Method used for `Request` parameters encoding.
    func encode(_ request: inout URLRequest, parameters: [String: Any]?) throws
}

fileprivate extension Encoding {

    /// Encoding components.
    typealias Components = [(String, String)]

    /// Parse components from key and value.
    ///
    /// - Parameter key: string value of parameter key.
    /// - Parameter value: value of parameter.
    ///
    /// - Returns: a components array
    private static func getComponents(_ key: String, _ value: Any) -> Components {
        var result = Components()

        switch value {
        case let dictionary as [String: Any]:
            result = dictionary.reduce(result) { value, element in
                let components = self.getComponents("\(key)[\(element.0)]", element.1)
                return value + components
            }
        case let array as [Any]:
            result = array.reduce(result) { value, element in
                let components = self.getComponents("\(key)[]", element)
                return value + components
            }
        default:
            result.append((key, "\(value)"))
        }

        return result
    }

    /// Parse `Request` parameters to components for encoder
    ///
    /// - Parameter parameters: parameters to parse
    ///
    /// - Returns: a components array
    static func getComponents(from parameters: [String: Any]) -> Components {
        let components = parameters.reduce(Components()) { value, element in
            let key = element.0
            let components = self.getComponents(key, element.1)
            return value + components
        }

        return components
    }
}
