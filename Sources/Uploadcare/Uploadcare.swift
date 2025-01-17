//
//  Uploadcare.swift
//
//
//  Created by Sergey Armodin on 03.02.2020.
//  Copyright © 2020 Uploadcare, Inc. All rights reserved.
//

import Foundation


public class Uploadcare: NSObject {
	
	// TODO: log turn on or off
	// TODO: add logs
	
	/// Authentication scheme for REST API requests
	/// More information about authentication: https://uploadcare.com/docs/api_reference/rest/requests_auth/#rest-api-requests-and-authentication
	public enum AuthScheme: String {
		case simple = "Uploadcare.Simple"
		case signed = "Uploadcare"
	}
	
	/// Uploadcare authentication method
	public var authScheme: AuthScheme = .signed {
		didSet {
			requestManager.authScheme = authScheme
		}
	}
	

	// MARK: - Public properties
	public var uploadAPI: UploadAPI

	
	// MARK: - Private properties
	/// Public Key.  It is required when using Upload API.
	internal var publicKey: String

	/// Secret Key. Optional. Is used for authorization
	internal var secretKey: String?

	/// Performs network requests
	private let requestManager: RequestManager

	private var redirectValues = [String: String]()
	
	
	/// Initialization
	/// - Parameter publicKey: Public Key.  It is required when using Upload API.
	public init(withPublicKey publicKey: String, secretKey: String? = nil) {
		self.publicKey = publicKey
		self.secretKey = secretKey
		self.requestManager = RequestManager(publicKey: publicKey, secretKey: secretKey)

		self.uploadAPI = UploadAPI(withPublicKey: publicKey, secretKey: secretKey, requestManager: self.requestManager)
	}
	
	
	/// Method for integration testing
	public static func sayHi() {
		print("Uploadcare says Hi!")
	}
}


// MARK: - Private methods
internal extension Uploadcare {
	func urlWithPath(_ path: String) -> URL {
		var urlComponents = URLComponents()
		urlComponents.scheme = "https"
		urlComponents.host = RESTAPIHost
		urlComponents.path = path

		guard let url = urlComponents.url else {
			fatalError("incorrect url")
		}
		return url
	}
}


// MARK: - REST API
extension Uploadcare {
	/// Get list of files
	/// - Parameters:
	///   - query: query object
	///   - completionHandler: completion handler
	public func listOfFiles(withQuery query: PaginationQuery?, _ completionHandler: @escaping (Result<FilesList, RESTAPIError>) -> Void) {
		listOfFiles(withQueryString: query?.stringValue, completionHandler)
	}

    /// Get list of files
    /// - Parameters:
    ///   - query: query string
    ///   - completionHandler: completion handler
    internal func listOfFiles(
        withQueryString query: String?,
        _ completionHandler: @escaping (Result<FilesList, RESTAPIError>) -> Void
    ) {
        var urlString = RESTAPIBaseUrl + "/files/"
        if let queryValue = query {
            urlString += "?\(queryValue)"
        }

        guard let url = URL(string: urlString) else {
            assertionFailure("Incorrect url")
            return
        }

        var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
        requestManager.signRequest(&urlRequest)
        requestManager.performRequest(urlRequest) { (result: Result<FilesList, Error>) in
            switch result {
            case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
            case .success(let filesList): completionHandler(.success(filesList))
            }
        }
    }

	/// Store a single file by UUID.
	/// - Parameters:
	///   - uuid: file UUID
	///   - completionHandler: completion handler
	public func storeFile(
		withUUID uuid: String,
		_ completionHandler: @escaping (Result<File, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/storage/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .put)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<File, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let file): completionHandler(.success(file))
			}
		}
	}

	/// Batch file storing. Used to store multiple files in one go. Up to 100 files are supported per request.
	/// - Parameters:
	///   - uuids: List of files UUIDs to store.
	///   - completionHandler: completion handler
	public func storeFiles(
		withUUIDs uuids: [String],
		_ completionHandler: @escaping (Result<BatchFilesOperationResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/storage/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .put)

		if let body = try? JSONEncoder().encode(uuids) {
			urlRequest.httpBody = body
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<BatchFilesOperationResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// File Info. Once you obtain a list of files, you might want to acquire some file-specific info.
	/// - Parameters:
	///   - uuid: File UUID.
	///   - query: Query parameters string.
	///   - completionHandler: Completion handler.
	public func fileInfo(
		withUUID uuid: String,
		withQueryString query: String? = nil,
		_ completionHandler: @escaping (Result<File, RESTAPIError>) -> Void
	) {

		var urlString = RESTAPIBaseUrl + "/files/\(uuid)/"
		if let queryValue = query {
			urlString += "?\(queryValue)"
		}

		guard let url = URL(string: urlString) else {
			assertionFailure("Incorrect url")
			completionHandler(.failure(RESTAPIError.init(detail: "Incorrect url")))
			return
		}

		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<File, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let file): completionHandler(.success(file))
			}
		}
	}

	/// File Info. Once you obtain a list of files, you might want to acquire some file-specific info.
	/// - Parameters:
	///   - uuid: File UUID.
	///   - query: Query parameters
	///   - completionHandler: Completion handler.
	public func fileInfo(
		withUUID uuid: String,
		withQuery query: FileInfoQuery,
		_ completionHandler: @escaping (Result<File, RESTAPIError>) -> Void
	) {
		fileInfo(withUUID: uuid, withQueryString: query.stringValue, completionHandler)
	}

	/// Delete file. Beside deleting in a multi-file mode, you can remove individual files.
	/// - Parameters:
	///   - uuid: file UUID
	///   - completionHandler: completion handler
	public func deleteFile(
		withUUID uuid: String,
		_ completionHandler: @escaping (Result<File, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/storage/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .delete)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<File, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let file): completionHandler(.success(file))
			}
		}
	}

	/// Batch file delete. Used to delete multiple files in one go. Up to 100 files are supported per request.
	/// - Parameters:
	///   - uuids: List of files UUIDs to store.
	///   - completionHandler: completion handler
	public func deleteFiles(
		withUUIDs uuids: [String],
		_ completionHandler: @escaping (Result<BatchFilesOperationResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/storage/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .delete)

		if let body = try? JSONEncoder().encode(uuids) {
			urlRequest.httpBody = body
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<BatchFilesOperationResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Copy file to local storage. Used to copy original files or their modified versions to default storage. Source files MAY either be stored or just uploaded and MUST NOT be deleted.
	/// - Parameters:
	///   - source: A CDN URL or just UUID of a file subjected to copy.
	///   - store: The parameter only applies to the Uploadcare storage. Default: "false"
	///   - makePublic: Applicable to custom storage only. True to make copied files available via public links, false to reverse the behavior. Default: "true"
	///   - completionHandler: completion handler
	public func copyFileToLocalStorage(
		source: String,
		store: Bool? = nil,
		makePublic: Bool? = nil,
		_ completionHandler: @escaping (Result<CopyFileToLocalStorageResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/local_copy/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let bodyDictionary = [
			"source": source,
			"store": "\(store ?? false)",
			"make_public": "\(makePublic ?? true)"
		]
		if let body = try? JSONEncoder().encode(bodyDictionary) {
			urlRequest.httpBody = body
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<CopyFileToLocalStorageResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// POST requests are used to copy original files or their modified versions to a custom storage. Source files MAY either be stored or just uploaded and MUST NOT be deleted.
	/// - Parameters:
	///   - source: A CDN URL or just UUID of a file subjected to copy.
	///   - target: Identifies a custom storage name related to your project. Implies you are copying a file to a specified custom storage. Keep in mind you can have multiple storages associated with a single S3 bucket.
	///   - makePublic: MUST be either true or false. true to make copied files available via public links, false to reverse the behavior.
	///   - pattern: The parameter is used to specify file names Uploadcare passes to a custom storage. In case the parameter is omitted, we use pattern of your custom storage. Use any combination of allowed values.
	///   - completionHandler: completion handler
	public func copyFileToRemoteStorage(
		source: String,
		target: String,
		makePublic: Bool? = nil,
		pattern: NamesPattern?,
		_ completionHandler: @escaping (Result<CopyFileToRemoteStorageResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/remote_copy/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		var bodyDictionary = [
			"source": source,
			"target": target
		]

		if let makePublicVal = makePublic {
			bodyDictionary["make_public"] = "\(makePublicVal)"
		}
		if let patternVal = pattern {
			bodyDictionary["pattern"] = patternVal.rawValue
		}

		if let body = try? JSONEncoder().encode(bodyDictionary) {
			urlRequest.httpBody = body
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<CopyFileToRemoteStorageResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Get file's metadata.
	/// - Parameters:
	///   - uuid: File UUID.
	///   - completionHandler: Completion handler.
	public func fileMetadata(
		withUUID uuid: String,
		_ completionHandler: @escaping (Result<[String: String], RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/metadata/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<[String: String], Error>) in
			switch result {
			case .failure(let error):
				if case .emptyResponse = error as? RequestManagerError {
					completionHandler(.success([:]))
					return
				}
				completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let data):
				completionHandler(.success(data))
			}
		}
	}

	/// Get metadata key's value.
	///
	/// List of allowed characters for the key:
	/// - Latin letters in lower or upper case (a-z,A-Z)
	/// - digits (0-9)
	/// - underscore _
	/// - a hyphen `-`
	/// - dot `.`
	/// - colon `:`
	///
	/// - Parameters:
	///   - key: Key of file metadata.
	///   - uuid: File UUID.
	///   - completionHandler: Completion handler.
	public func fileMetadataValue(
		forKey key: String,
		withUUID uuid: String,
		_ completionHandler: @escaping (Result<String, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/metadata/\(key)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<String, Error>) in
			switch result {
			case .failure(let error):
				completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let val):
				let trimmedVal = val.trimmingCharacters(in: CharacterSet(arrayLiteral: "\""))
				completionHandler(.success(trimmedVal))
			}
		}
	}

	/// Update metadata key's value. If the key does not exist, it will be created.
	///
	/// List of allowed characters for the key:
	/// - Latin letters in lower or upper case (a-z,A-Z)
	/// - digits (0-9)
	/// - underscore _
	/// - a hyphen `-`
	/// - dot `.`
	/// - colon `:`
	///
	/// - Parameters:
	///   - uuid: File UUID.
	///   - key: Key of file metadata.
	///   - value: New value.
	///   - completionHandler: Completion handler.
	public func updateFileMetadata(
		withUUID uuid: String,
		key: String,
		value: String,
		_ completionHandler: @escaping (Result<String, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/metadata/\(key)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .put)
		urlRequest.httpBody = "\"\(value)\"".data(using: .utf8)!
		urlRequest.allHTTPHeaderFields?.removeValue(forKey: "Content-Type")
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<String, Error>) in
			switch result {
			case .failure(let error):
				completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let val):
				let trimmedVal = val.trimmingCharacters(in: CharacterSet(arrayLiteral: "\""))
				completionHandler(.success(trimmedVal))
			}
		}
	}

	/// Delete metadata key.
	///
	/// List of allowed characters for the key:
	/// - Latin letters in lower or upper case (a-z,A-Z)
	/// - digits (0-9)
	/// - underscore _
	/// - a hyphen `-`
	/// - dot `.`
	/// - colon `:`
	/// 
	/// - Parameters:
	///   - key: Key of file metadata.
	///   - uuid: File UUID.
	///   - completionHandler: Completion handler.
	public func deleteFileMetadata(
		forKey key: String,
		withUUID uuid: String,
		_ completionHandler: @escaping (RESTAPIError?) -> Void
	) {
		let url = urlWithPath("/files/\(uuid)/metadata/\(key)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .delete)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<String, Error>) in
			switch result {
			case .failure(let error):
				if case .emptyResponse = error as? RequestManagerError {
					completionHandler(nil)
					return
				}
				completionHandler(RESTAPIError.fromError(error))
			case .success:
				completionHandler(nil)
			}
		}
	}

	/// Get list of groups
	/// - Parameters:
	///   - query: Request query object.
	///   - completionHandler: Completion handler.
	public func listOfGroups(
		withQuery query: GroupsListQuery?,
		_ completionHandler: @escaping (Result<GroupsList, RESTAPIError>) -> Void
	) {
		var queryString: String?
		if let queryValue = query {
			queryString = "\(queryValue.stringValue)"
		}
		listOfGroups(withQueryString: queryString, completionHandler)
	}
	
	/// Get list of groups
	/// - Parameters:
	///   - query: query string
	///   - completionHandler: completion handler
	internal func listOfGroups(
		withQueryString query: String?,
		_ completionHandler: @escaping (Result<GroupsList, RESTAPIError>) -> Void
	) {
		var urlString = RESTAPIBaseUrl + "/groups/"
		if let queryValue = query {
			urlString += "?\(queryValue)"
		}
		
		guard let url = URL(string: urlString) else {
			assertionFailure("Incorrect url")
			return
		}
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<GroupsList, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let groupsList): completionHandler(.success(groupsList))
			}
		}
	}

	/// Get a file group by UUID.
	/// - Parameters:
	///   - uuid: Group UUID.
	///   - completionHandler: completion handler
	public func groupInfo(
		withUUID uuid: String,
		_ completionHandler: @escaping (Result<Group, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/groups/\(uuid)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Group, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let group): completionHandler(.success(group))
			}
		}
	}
	
	/// Mark all files in a group as stored.
	/// - Parameters:
	///   - uuid: Group UUID.
	///   - completionHandler: completion handler
	@available(*, unavailable, message: "This method is removed on API side. To store or remove files from a group, query the list of files in it, split the list into chunks of 100 files per chunk and then perform batch file storing or batch file removal for all the chunks.")
	public func storeGroup(
		withUUID uuid: String,
		_ completionHandler: @escaping (RESTAPIError?) -> Void
	) {
		let url = urlWithPath("/groups/\(uuid)/storage/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .put)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Group, Error>) in
			switch result {
			case .failure(let error): completionHandler(RESTAPIError.fromError(error))
			case .success(_): completionHandler(nil)
			}
		}
	}

	/// Delete a file group by its ID.
	///
	/// **Note**: The operation only removes the group object itself. **All the files that were part of the group are left as is.**
	///
	/// - Parameters:
	///   - uuid: Group UUID.
	///   - completionHandler: Completion handler.
	public func deleteGroup(
		withUUID uuid: String,
		_ completionHandler: @escaping (RESTAPIError?) -> Void
	) {
		let url = urlWithPath("/groups/\(uuid)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .delete)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Group, Error>) in
			switch result {
			case .failure(let error):
				if case .emptyResponse = error as? RequestManagerError {
					completionHandler(nil)
					return
				}
				completionHandler(RESTAPIError.fromError(error))
			case .success(_): completionHandler(nil)
			}
		}
	}

	/// Getting info about account project.
	/// - Parameter completionHandler: completion handler
	public func getProjectInfo(_ completionHandler: @escaping (Result<Project, RESTAPIError>) -> Void) {
		let url = urlWithPath("/project/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Project, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let project): completionHandler(.success(project))
			}
		}
	}

	/// This method allows you to get authonticated url from your backend using redirect.
	/// By request to that url your backend should generate authenticated url to your file and perform REDIRECT to generated url.
	/// Redirect url will be caught and returned in completion handler of that method
	///
	/// Example of URL: https://yourdomain.com/{UUID}/
	/// Redirect to: https://cdn.yourdomain.com/{uuid}/?token={token}&expire={timestamp}
	///
	/// URL for redirect will be returned in completion handler
	///
	/// More details in documentation: https://uploadcare.com/docs/delivery/file_api/#authenticated-urls
	///
	/// - Parameters:
	///   - url: url for request to your backend
	///   - completionHandler: completion handler
	public func getAuthenticatedUrlFromUrl(_ url: URL, _ completionHandler: @escaping (Result<String, RESTAPIError>) -> Void) {
		let urlString = url.absoluteString

		redirectValues[urlString] = ""

		let config = URLSessionConfiguration.default
		let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

		let task = urlSession.dataTask(with: url) { [weak self] (data, response, error) in
			guard let self = self else { return }

			defer { self.redirectValues.removeValue(forKey: urlString) }

			if let error = error {
				completionHandler(.failure(RESTAPIError(detail: error.localizedDescription)))
				return
			}

			guard let redirectUrl = self.redirectValues[urlString], redirectUrl.isEmpty == false else {
				completionHandler(.failure(RESTAPIError(detail: "No redirect happened")))
				return
			}

			completionHandler(.success(redirectUrl))
		}
		task.resume()
	}

	/// List of project webhooks.
	/// - Parameter completionHandler: completion handler
	public func getListOfWebhooks(_ completionHandler: @escaping (Result<[Webhook], RESTAPIError>) -> Void) {
		let url = urlWithPath("/webhooks/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<[Webhook], Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let webhooks): completionHandler(.success(webhooks))
			}
		}
	}

	/// Create webhook
	/// - Parameters:
	///   - targetUrl: A URL that is triggered by an event, for example, a file upload. A target URL MUST be unique for each project — event type combination.
	///   - isActive: Marks a subscription as either active or not, defaults to true, otherwise false.
	///   - signingSecret: Optional secret that, if set, will be used to calculate signatures for the webhook payloads
	///   - completionHandler: completion handler
	public func createWebhook(targetUrl: URL, isActive: Bool, signingSecret: String? = nil, _ completionHandler: @escaping (Result<Webhook, RESTAPIError>) -> Void) {
		let url = urlWithPath("/webhooks/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)
		var bodyDictionary = [
			"target_url": targetUrl.absoluteString,
			"event": "file.uploaded", // Presently, we only support the file.uploaded event.
			"is_active": "\(isActive)"
		]

		if let signingSecret = signingSecret {
			bodyDictionary["signing_secret"] = signingSecret
		}

		do {
			urlRequest.httpBody = try JSONEncoder().encode(bodyDictionary)
		} catch let error {
			DLog(error.localizedDescription)
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Webhook, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let webhook): completionHandler(.success(webhook))
			}
		}
	}

	/// Update webhook attributes
	/// - Parameters:
	///   - id: Webhook ID
	///   - targetUrl: Where webhook data will be posted.
	///   - isActive: Marks a subscription as either active or not
	///   - signingSecret: Optional secret that, if set, will be used to calculate signatures for the webhook payloads
	///   - completionHandler: completion handler
	public func updateWebhook(id: Int, targetUrl: URL, isActive: Bool, signingSecret: String? = nil, _ completionHandler: @escaping (Result<Webhook, RESTAPIError>) -> Void) {
		let url = urlWithPath("/webhooks/\(id)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .put)
		var bodyDictionary = [
			"target_url": targetUrl.absoluteString,
			"event": "file.uploaded", // Presently, we only support the file.uploaded event.
			"is_active": "\(isActive)"
		]

		if let signingSecret = signingSecret {
			bodyDictionary["signing_secret"] = signingSecret
		}

		do {
			urlRequest.httpBody = try JSONEncoder().encode(bodyDictionary)
		} catch let error {
			DLog(error.localizedDescription)
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Webhook, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let webhook): completionHandler(.success(webhook))
			}
		}
	}

	/// Delete webhook
	/// - Parameters:
	///   - targetUrl: url of webhook target
	///   - completionHandler: completion handler
	public func deleteWebhook(forTargetUrl targetUrl: URL, _ completionHandler: @escaping (RESTAPIError?) -> Void) {
		let url = urlWithPath("/webhooks/unsubscribe/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .delete)
		let bodyDictionary = [
			"target_url": targetUrl.absoluteString
		]
		do {
			urlRequest.httpBody = try JSONEncoder().encode(bodyDictionary)
		} catch let error {
			DLog(error.localizedDescription)
		}
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<Bool, Error>) in
			switch result {
			case .failure(let error): completionHandler(RESTAPIError.fromError(error))
			case .success(_): completionHandler(nil)
			}
		}
	}

	/// Uploadcare allows converting documents to the following target formats: DOC, DOCX, XLS, XLSX, ODT, ODS, RTF, TXT, PDF, JPG, PNG.
	/// - Parameters:
	///   - paths: An array of UUIDs of your source documents to convert together with the specified target format.
	///   See documentation: https://uploadcare.com/docs/transformations/document_conversion/#convert-url-formatting
	///   - store: A flag indicating if we should store your outputs.
	///   - completionHandler: completion handler
	public func convertDocuments(
		_ paths: [String],
		store: StoringBehavior? = nil,
		_ completionHandler: @escaping (Result<ConvertDocumentsResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/convert/document/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let storeValue = store == StoringBehavior.auto ? .store : store
		let requestData = ConvertRequestData(
			paths: paths,
			store: storeValue?.rawValue ?? StoringBehavior.store.rawValue
		)

		urlRequest.httpBody = try? JSONEncoder().encode(requestData)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ConvertDocumentsResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Convert documents
	/// - Parameters:
	///   - files: files array
	///   - format: target format (DOC, DOCX, XLS, XLSX, ODT, ODS, RTF, TXT, PDF, JPG, PNG)
	///   - store: A flag indicating if we should store your outputs.
	///   - completionHandler: completion handler
	public func convertDocumentsWithSettings(
		_ tasks: [DocumentConversionJobSettings],
		store: StoringBehavior? = nil,
		_ completionHandler: @escaping (Result<ConvertDocumentsResponse, RESTAPIError>) -> Void
	) {
		var paths = [String]()
		tasks.forEach({ paths.append($0.stringValue) })
		convertDocuments(paths, store: store, completionHandler)
	}

	/// Document conversion job status
	/// - Parameters:
	///   - token: Job token
	///   - completionHandler: completion handler
	public func documentConversionJobStatus(token: Int, _ completionHandler: @escaping (Result<ConvertDocumentJobStatus, RESTAPIError>) -> Void) {
		let url = urlWithPath("/convert/document/status/\(token)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ConvertDocumentJobStatus, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let status): completionHandler(.success(status))
			}
		}
	}

	/// Convert videos with settings
	/// - Parameters:
	///   - tasks: array of VideoConversionJobSettings objects which settings for conversion for every file
	///   - store: A flag indicating if we should store your outputs.
	///   - completionHandler: completion handler
	public func convertVideosWithSettings(
		_ tasks: [VideoConversionJobSettings],
		store: StoringBehavior? = nil,
		_ completionHandler: @escaping (Result<ConvertDocumentsResponse, RESTAPIError>) -> Void
	) {
		var paths = [String]()
		tasks.forEach({ paths.append($0.stringValue) })
		convertVideos(paths, completionHandler)
	}

	/// Convert videos
	/// - Parameters:
	///   - paths: An array of UUIDs of your video files to process together with a set of needed operations.
	///   See documentation: https://uploadcare.com/docs/transformations/video_encoding/#process-operations
	///   - store: A flag indicating if we should store your outputs.
	///   - completionHandler: completion handler
	public func convertVideos(
		_ paths: [String],
		store: StoringBehavior? = nil,
		_ completionHandler: @escaping (Result<ConvertDocumentsResponse, RESTAPIError>) -> Void
	) {
		let url = urlWithPath("/convert/video/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let storeValue = store == StoringBehavior.auto ? .store : store
		let requestData = ConvertRequestData(
			paths: paths,
			store: storeValue?.rawValue ?? StoringBehavior.store.rawValue
		)

		urlRequest.httpBody = try? JSONEncoder().encode(requestData)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ConvertDocumentsResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Video conversion job status
	/// - Parameters:
	///   - token: Job token
	///   - completionHandler: completion handler
	public func videoConversionJobStatus(token: Int, _ completionHandler: @escaping (Result<ConvertVideoJobStatus, RESTAPIError>) -> Void) {
		let url = urlWithPath("/convert/video/status/\(token)/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ConvertVideoJobStatus, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let status): completionHandler(.success(status))
			}
		}
	}
}

// MARK: - Add-Ons
extension Uploadcare {
	/// Execute AWS Rekognition
	/// - Parameters:
	///   - fileUUID: Unique ID of the file to process.
	///   - completionHandler: Completion handler.
	public func executeAWSRecognition(fileUUID: String, _ completionHandler: @escaping (Result<ExecuteAddonResponse, RESTAPIError>) -> Void) {
		let url = urlWithPath("/addons/aws_rekognition_detect_labels/execute/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let bodyDictionary = [
			"target": fileUUID
		]

		urlRequest.httpBody = try? JSONEncoder().encode(bodyDictionary)

		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ExecuteAddonResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Check AWS Rekognition execution status.
	/// - Parameters:
	///   - requestID: Request ID returned by the Add-On execution request.
	///   - completionHandler: Completion handler.
	public func checkAWSRecognitionStatus(requestID: String, _ completionHandler: @escaping (Result<AddonExecutionStatus, RESTAPIError>) -> Void) {
		let urlString = RESTAPIBaseUrl + "/addons/aws_rekognition_detect_labels/execute/status/?request_id=\(requestID)"

		guard let url = URL(string: urlString) else {
			assertionFailure("Incorrect url")
			completionHandler(.failure(RESTAPIError.init(detail: "Incorrect url")))
			return
		}

		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ExecuteAddonStatusResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response.status))
			}
		}
	}

	/// Execute ClamAV virus checking Add-On for a given target.
	/// - Parameters:
	///   - fileUUID: Unique ID of the file to process.
	///   - parameters: Optional object with Add-On specific parameters.
	///   - completionHandler: Completion handler.
	public func executeClamav(fileUUID: String, parameters: ClamAVAddonExecutionParams? = nil, _ completionHandler: @escaping (Result<ExecuteAddonResponse, RESTAPIError>) -> Void) {
		let url = urlWithPath("/addons/uc_clamav_virus_scan/execute/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let requestBody = ClamAVAddonExecutionRequestBody(target: fileUUID, params: parameters)
		urlRequest.httpBody = try? JSONEncoder().encode(requestBody)

		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ExecuteAddonResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Check the status of an Add-On execution request that had been started using ``executeClamav(fileUUID:parameters:_:)`` method.
	/// - Parameters:
	///   - requestID: Request ID returned by the Add-On execution request described above.
	///   - completionHandler: Completion handler.
	public func checkClamAVStatus(requestID: String, _ completionHandler: @escaping (Result<AddonExecutionStatus, RESTAPIError>) -> Void) {
		let urlString = RESTAPIBaseUrl + "/addons/uc_clamav_virus_scan/execute/status/?request_id=\(requestID)"

		guard let url = URL(string: urlString) else {
			assertionFailure("Incorrect url")
			completionHandler(.failure(RESTAPIError.init(detail: "Incorrect url")))
			return
		}

		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ExecuteAddonStatusResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response.status))
			}
		}
	}

	/// Execute remove.bg background image removal Add-On for a given target.
	/// - Parameters:
	///   - fileUUID: Unique ID of the file to process.
	///   - parameters: Optional object with Add-On specific parameters.
	///   - completionHandler: Completion handler
	public func executeRemoveBG(fileUUID: String, parameters: RemoveBGAddonExecutionParams? = nil, _ completionHandler: @escaping (Result<ExecuteAddonResponse, RESTAPIError>) -> Void) {
		let url = urlWithPath("/addons/remove_bg/execute/")
		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .post)

		let requestBody = RemoveBGAddonExecutionRequestBody(target: fileUUID, params: parameters)
		urlRequest.httpBody = try? JSONEncoder().encode(requestBody)

		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<ExecuteAddonResponse, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}

	/// Check Remove.bg execution status
	/// - Parameters:
	///   - requestID: Request ID returned by the Add-On execution request described above.
	///   - completionHandler: Completion handler.
	public func checkRemoveBGStatus(requestID: String, _ completionHandler: @escaping (Result<RemoveBGAddonAddonExecutionStatus, RESTAPIError>) -> Void) {
		let urlString = RESTAPIBaseUrl + "/addons/remove_bg/execute/status/?request_id=\(requestID)"

		guard let url = URL(string: urlString) else {
			assertionFailure("Incorrect url")
			completionHandler(.failure(RESTAPIError.init(detail: "Incorrect url")))
			return
		}

		var urlRequest = requestManager.makeUrlRequest(fromURL: url, method: .get)
		requestManager.signRequest(&urlRequest)

		requestManager.performRequest(urlRequest) { (result: Result<RemoveBGAddonAddonExecutionStatus, Error>) in
			switch result {
			case .failure(let error): completionHandler(.failure(RESTAPIError.fromError(error)))
			case .success(let response): completionHandler(.success(response))
			}
		}
	}
}

// MARK: - Upload
extension Uploadcare {
	/// Upload file. This method will decide internally which upload will be used (direct or multipart)
	/// - Parameters:
	///   - data: File data
	///   - name: File name
	///   - store: Sets the file storing behavior
	///   - uploadSignature: Sets the signature for the upload request
	///   - onProgress: A callback that will be used to report upload progress
	///   - completionHandler: Completion handler
	/// - Returns: Upload task. Confirms to UploadTaskable protocol in anycase. Might confirm to UploadTaskResumable protocol (which inherits UploadTaskable)  if multipart upload was used so you can pause and resume upload
	@discardableResult
	public func uploadFile(
		_ data: Data,
		withName name: String,
		store: StoringBehavior? = nil,
		metadata: [String: String]? = nil,
		uploadSignature: UploadSignature? = nil,
		_ onProgress: ((Double) -> Void)? = nil,
		_ completionHandler: @escaping (Result<UploadedFile, UploadError>) -> Void
	) -> UploadTaskable {
		let filename = name.isEmpty ? "noname.ext" : name

		// using direct upload if file is small
		if data.count < UploadAPI.multipartMinFileSize {
			let files = [filename: data]
			return uploadAPI.directUpload(files: files, store: store, metadata: metadata, uploadSignature: uploadSignature, onProgress) { [weak self] result in
				switch result {
				case .failure(let error):
					completionHandler(.failure(error))
				case .success(let response):
					guard let fileUUID = response[filename] else {
						completionHandler(.failure(UploadError.defaultError()))
						return
					}

					if uploadSignature == nil && self?.secretKey == nil {
						let uploadedFile = UploadedFile(
							size: data.count,
							total: data.count,
							done: data.count,
							uuid: fileUUID,
							fileId: fileUUID,
							originalFilename: filename,
							filename: filename,
							mimeType: "application/octet-stream",
							isImage: false,
							isStored: store == .store,
							isReady: true,
							imageInfo: nil,
							videoInfo: nil,
							contentInfo: nil,
							metadata: metadata,
							s3Bucket: nil
						)
						completionHandler(.success(uploadedFile))
						return
					}

					self?.fileInfo(withUUID: fileUUID, { result in
						switch result {
						case .failure(let error):
							completionHandler(.failure(UploadError(status: 0, detail: error.detail)))
						case .success(let file):
							let uploadedFile = UploadedFile(
								size: file.size,
								total: file.size,
								done: file.size,
								uuid: file.uuid,
								fileId: file.uuid,
								originalFilename: file.originalFilename,
								filename: file.originalFilename,
								mimeType: file.mimeType,
								isImage: file.isImage,
								isStored: file.datetimeStored != nil,
								isReady: file.isReady,
								imageInfo: nil,
								videoInfo: nil,
								contentInfo: nil,
								metadata: nil,
								s3Bucket: nil
							)

							completionHandler(.success(uploadedFile))
						}
					})
				}
			}
		}

		// using multipart upload otherwise
		return uploadAPI.multipartUpload(data, withName: filename, store: store, metadata: metadata, uploadSignature: uploadSignature, onProgress, completionHandler)
	}
}

// MARK: - Factory
extension Uploadcare {
	/// Create group of uploaded files from array
	/// - Parameter files: files array
	public func group(ofFiles files: [UploadedFile]) -> UploadedFilesGroup {
		return UploadedFilesGroup(withFiles: files, uploadAPI: uploadAPI)
	}

	/// Create file model for uploading from Data
	/// - Parameters:
	///   - data: data
	///   - fileName: file name
	public func file(fromData data: Data) -> UploadedFile {
		return UploadedFile(withData: data, restAPI: self)
	}

	/// Create file model for uploading from URL
	/// - Parameters:
	///   - url: file url
	public func file(withContentsOf url: URL) -> UploadedFile? {
		var dataFromURL: Data?

		let semaphore = DispatchSemaphore(value: 0)
		DispatchQueue.global(qos: .utility).async {
			dataFromURL = try? Data(contentsOf: url, options: .mappedIfSafe)
			semaphore.signal()
		}
		semaphore.wait()

		guard let data = dataFromURL else { return nil }
		let file = UploadedFile(withData: data, restAPI: self)
		file.filename = url.lastPathComponent
		file.originalFilename = url.lastPathComponent
		return file
	}
}

// MARK: - URLSessionTaskDelegate
extension Uploadcare: URLSessionTaskDelegate {
	public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		if let key = task.originalRequest?.url?.absoluteString, let value = request.url?.absoluteString {
			redirectValues[key] = value
		}
		completionHandler(request)
	}
}

// MARK: - Factory
extension Uploadcare {
	public func listOfFiles(_ files: [File]? = nil) -> FilesList {
		return FilesList(withFiles: files ?? [], api: self)
	}
	
	public func listOfGroups(_ groups: [Group]? = nil) -> GroupsList {
		return GroupsList(withGroups: groups ?? [], api: self)
	}
}
