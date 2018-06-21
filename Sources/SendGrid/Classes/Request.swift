//
//  Request.swift
//  SendGrid
//
//  Created by Scott Kawai on 9/8/17.
//
import Foundation

/// The `Request` class should be inherited by any class that represents an API
/// request and sent through the `send` function in `Session`.
///
/// This class contains a `ModelType` generic, which is used to map the API
/// response to a specific model that conforms to `Codable`.
open class Request<ModelType : Decodable, Parameters : Encodable>: Validatable {
    
    // MARK: - Properties
    //=========================================================================
    
    /// A `Bool` indicating if the request supports the "On-behalf-of" header.
    open var supportsImpersonation: Bool { return true }
    
    /// The HTTP verb to use in the call.
    open var method: HTTPMethod
    
    /// The Content-Type of the call.
    open var contentType: ContentType
    
    /// The Accept header value.
    open var acceptType: ContentType = .json
    
    /// The decoding strategy.
    open var decodingStrategy: DecodingStrategy
    
    /// The encoding strategy.
    open var encodingStrategy: EncodingStrategy
    
    /// The path component of the API endpoint. This should start with a `/`,
    /// for example "/v3/mail/send".
    open var path: String
    
    /// The parameters that should be sent with the API call. These parameters
    /// will either be encoded into the body of the request or the query items
    /// of the request
    open var parameters: Parameters?
    
    
    // MARK: - Initialization
    //=========================================================================
    
    /// Initializes the request.
    ///
    /// - Parameters:
    ///   - method:     The HTTP verb to use in the API call.
    ///   - parameters: Any parameters to send with the API call.
    ///   - path:       The path portion of the API endpoint, such as
    ///                 "/v3/mail/send". The path *must* start with a forward
    ///                 slash (`/`).
    ///   - parameters: Optional parameters to include in the API call.
    ///   - encoding:   The encoding strategy for the parameters.
    ///   - decoding:   The decoding strategy for the response.
    public init(method: HTTPMethod, contentType: ContentType, path: String, parameters: Parameters? = nil, encoding: EncodingStrategy = EncodingStrategy(), decoding: DecodingStrategy = DecodingStrategy()) {
        self.method = method
        self.contentType = contentType
        self.path = path
        self.parameters = parameters
        self.encodingStrategy = encoding
        self.decodingStrategy = decoding
    }
    
    
    // MARK: - Methods
    //=========================================================================
    
    /// Validates that the content and accept types are valid.
    open func validate() throws {
        try self.contentType.validate()
        try self.acceptType.validate()
        if let paramValidate = self.parameters as? Validatable {
            try paramValidate.validate()
        }
    }
    
    /// Before a `Session` instance makes an API call, it will call this method
    /// to double check that the auth method it's about to use is supported by
    /// the endpoint. In general, this will always return `true`, however some
    /// endpoints, such as the mail send endpoint, only support API keys.
    ///
    /// - Parameter auth:   The `Authentication` instance that's about to be
    ///                     used.
    /// - Returns:          A `Bool` indicating if the authentication method is
    ///                     supported.
    open func supports(auth: Authentication) -> Bool {
        return true
    }
    
}

/// CustomStringConvertible conformance
extension Request: CustomStringConvertible {
    
    /// The description of the request, represented as an [API
    /// Blueprint](https://apiblueprint.org/)
    public var description: String {
        let path = self.path
        let parameterString: String?
        paramEncoding: do {
            guard let params = self.parameters else {
                parameterString = nil
                break paramEncoding
            }
            if self.method.hasBody {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = self.encodingStrategy.dates
                encoder.dataEncodingStrategy = self.encodingStrategy.data
                guard let data = try? encoder.encode(params) else {
                    parameterString = nil
                    break paramEncoding
                }
                parameterString = String(data: data, encoding: .utf8)
            } else {
                let encoder = FormURLEncoder()
                encoder.dateEncodingStrategy = self.encodingStrategy.dates
                parameterString = try? encoder.stringEncode(params, percentEncoded: true)
            }
        }
        var query: String {
            guard !self.method.hasBody, let q = parameterString else { return "" }
            return "?\(q)"
        }
        var blueprint = """
        # \(self.method) \(path + query)
        
        + Request (\(self.contentType))
        
            + Headers
        
                    Accept: \(self.acceptType)
        
        """
        if self.method.hasBody, let bodyString = parameterString {
            let indented = bodyString.split(separator: "\n").map { "            \($0)" }
            blueprint += """
            
                + Body
            
            \(indented.joined(separator: "\n"))
            """
        }
        return blueprint
    }
    
}

