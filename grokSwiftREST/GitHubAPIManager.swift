//
//  GitHubAPIManager.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-11.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import Locksmith
import Reachability

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  var alamofireManager:Alamofire.Manager
  var reach: Reachability?
  
  static let ErrorDomain = "com.error.GitHubAPIManager"
  
  var clientID: String = "1234567890"
  var clientSecret: String = "abcdefghijkl"
  
  func clearCache() {
    let cache = NSURLCache.sharedURLCache()
    cache.removeAllCachedResponses()
  }
  
  // handlers for the OAuth process
  // stored as vars since sometimes it requires a round trip to safari which
  // makes it hard to just keep a reference to it
  var OAuthTokenCompletionHandler:(NSError? -> Void)?
  
  var OAuthToken: String? {
    set {
      if let valueToSave = newValue {
        do {
          try Locksmith.saveData(["token": valueToSave], forUserAccount: "github")
        } catch {
          let _ = try? Locksmith.deleteDataForUserAccount("github")
        }
        addSessionHeader("Authorization", value: "token \(valueToSave)")
      }
      else { // they set it to nil, so delete it
        let _ = try? Locksmith.deleteDataForUserAccount("github")
        removeSessionHeaderIfExists("Authorization")
      }
    }
    get {
      // try to load from keychain
      Locksmith.loadDataForUserAccount("github")
      let dictionary = Locksmith.loadDataForUserAccount("github")
      if let token =  dictionary?["token"] as? String {
        return token
      }
      removeSessionHeaderIfExists("Authorization")
      return nil
    }
  }
  
  init () {
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
    let manager = Alamofire.Manager(configuration: configuration)
    alamofireManager = manager
    addSessionHeader("Accept", value: "application/vnd.github.v3+json")
    if hasOAuthToken() {
      addSessionHeader("Authorization", value: "token \(OAuthToken!)")
    }
  }
  
  // MARK: - Headers
  func addSessionHeader(key: String, value: String) {
    var headers:[NSObject : AnyObject]
    if let existingHeaders = alamofireManager.session.configuration.HTTPAdditionalHeaders as? [String: String] {
      headers = existingHeaders
    } else {
      headers = Manager.defaultHTTPHeaders
    }
    headers[key] = value
    
    
    let config = alamofireManager.session.configuration
    config.HTTPAdditionalHeaders = headers
    print(config.HTTPAdditionalHeaders)
    alamofireManager = Alamofire.Manager(configuration: config)
  }
  
  func removeSessionHeaderIfExists(key: String) {
    let config = alamofireManager.session.configuration
    if var headers = config.HTTPAdditionalHeaders {
      headers.removeValueForKey(key)
      config.HTTPAdditionalHeaders = headers
      alamofireManager = Alamofire.Manager(configuration: config)
    }
  }
  
  // MARK: - Basic Auth
  func printMyStarredGistsWithBasicAuth() -> Void {
    let username = "myUsername"
    let password = "myPassword"
    
    let credentialData = "\(username):\(password)".dataUsingEncoding(NSUTF8StringEncoding)!
    let base64Credentials = credentialData.base64EncodedStringWithOptions([])
    
    let headers = ["Authorization": "Basic \(base64Credentials)"]
    
    Alamofire.request(.GET, "https://api.github.com/gists/starred", headers: headers)
      .responseString { _, _, result in
        if let receivedString = result.value {
          print(receivedString)
        }
    }
  }
  
  // MARK: - OAuth 2.0
  func hasOAuthToken() -> Bool {
    if let token = self.OAuthToken {
      return !token.isEmpty
    }
    return false
  }
  
  // MARK: - OAuth flow
  func startOAuth2Login() {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(true, forKey: "loadingOAuthToken")
    
    let authPath:String = "https://github.com/login/oauth/authorize?client_id=\(clientID)&scope=gist&state=TEST_STATE"
    guard let authURL:NSURL = NSURL(string: authPath) else {
      defaults.setBool(false, forKey: "loadingOAuthToken")
      if let completionHandler = self.OAuthTokenCompletionHandler {
        let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create an OAuth authorization URL", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
        completionHandler(error)
      }
      return
    }
    
    guard Reachability.reachabilityForInternetConnection().isReachable() == true else {
      if let completionHandler = self.OAuthTokenCompletionHandler {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "No internet connection", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
        completionHandler(error)
      }
      return
    }
    
    let success = UIApplication.sharedApplication().openURL(authURL)
    if (!success) {
      defaults.setBool(false, forKey: "loadingOAuthToken")
      if let completionHandler = self.OAuthTokenCompletionHandler {
        let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create an OAuth authorization URL", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
        completionHandler(error)
      }
    }
  }
  
  func processOAuthStep1Response(url: NSURL) {
    let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    var code:String?
    if let queryItems = components?.queryItems {
      for queryItem in queryItems {
        if (queryItem.name.lowercaseString == "code") {
          code = queryItem.value
          break
        }
      }
    }
    if let receivedCode = code {
      swapAuthCodeForToken(receivedCode)
    } else {
      // no code in URL that we launched with
      let defaults = NSUserDefaults.standardUserDefaults()
      defaults.setBool(false, forKey: "loadingOAuthToken")
      
      if let completionHandler = self.OAuthTokenCompletionHandler {
        let noCodeInResponseError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not obtain an OAuth code", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
        completionHandler(noCodeInResponseError)
      }
    }
  }
  
  func swapAuthCodeForToken(receivedCode: String) {
    let getTokenPath:String = "https://github.com/login/oauth/access_token"
    let tokenParams = ["client_id": clientID, "client_secret": clientSecret, "code": receivedCode]
    let jsonHeader = ["Accept": "application/json"]
    Alamofire.request(.POST, getTokenPath, parameters: tokenParams, headers: jsonHeader)
      .responseString { (request, response, result) in
        if let anError = result.error {
          let defaults = NSUserDefaults.standardUserDefaults()
          defaults.setBool(false, forKey: "loadingOAuthToken")
          
          if let completionHandler = self.OAuthTokenCompletionHandler {
            completionHandler(anError as NSError)
          }
          return
        }
        print(result.value)
        if let receivedResults = result.value, jsonData = receivedResults.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
          let jsonResults = JSON(data: jsonData)
          for (key, value) in jsonResults {
            switch key {
            case "access_token":
              self.OAuthToken = value.string
            case "scope":
              // TODO: verify scope
              print("SET SCOPE")
            case "token_type":
              // TODO: verify is bearer
              print("CHECK IF BEARER")
            default:
              print("got more than I expected from the OAuth token exchange")
              print(key)
            }
          }
        }
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(false, forKey: "loadingOAuthToken")
        
        if let completionHandler = self.OAuthTokenCompletionHandler {
          if (self.hasOAuthToken()) {
            completionHandler(nil)
          } else  {
            let noOAuthError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not obtain an OAuth token", NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
            completionHandler(noOAuthError)
          }
        }
    }
  }
  
  // MARK: - OAuth calls
  func printMyStarredGistsWithOAuth2() -> Void {
    let starredGistsRequest = alamofireManager.request(.GET, "https://api.github.com/gists/starred")
      .responseString { _, _, result in
        guard result.error == nil else {
          print(result.error)
          GitHubAPIManager.sharedInstance.OAuthToken = nil
          return
        }
        if let receivedString = result.value {
          print(receivedString)
        }
    }
    debugPrint(starredGistsRequest)
  }
  
  // MARK: - Public Gists
  func printPublicGists() -> Void {
    alamofireManager.request(.GET, "https://api.github.com/gists/public")
      .responseString { _, _, result in
        if let receivedString = result.value {
          print(receivedString)
        }
    }
  }
  
  private func handleUnauthorizedResponse(urlString: String) -> NSError {
    self.OAuthToken = nil
    let lostOAuthError = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: "Not Logged In", NSLocalizedRecoverySuggestionErrorKey: "Please re-enter your GitHub credentials"])
    return lostOAuthError
  }
  
  func getGists(urlString: String, completionHandler: (Result<[Gist]>, String?) -> Void) {
    alamofireManager.request(.GET, urlString)
      .validate()
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(.Failure(nil, lostOAuthError), nil)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .responseArray { (request, response, result: Result<[Gist]>) in
        guard result.error == nil,
          let gists = result.value else {
            print(result.error)
            completionHandler(result, nil)
            return
        }
        
        // need to figure out if this is the last page
        // check the link header, if present
        let next = self.getNextPageFromHeaders(response)
        completionHandler(.Success(gists), next)
    }
  }
  
  func getPublicGists(pageToLoad: String?, completionHandler: (Result<[Gist]>, String?) -> Void) {
    if let urlString = pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    } else {
      getGists("https://api.github.com/gists/public", completionHandler: completionHandler)
    }
  }
  
  func getMyStarredGists(pageToLoad: String?, completionHandler: (Result<[Gist]>, String?) -> Void) {
    if let urlString = pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    } else {
      getGists("https://api.github.com/gists/starred", completionHandler: completionHandler)
    }
  }
  
  func getMyGists(pageToLoad: String?, completionHandler: (Result<[Gist]>, String?) -> Void) {
    if let urlString = pageToLoad {
      getGists(urlString, completionHandler: completionHandler)
    } else {
      getGists("https://api.github.com/gists", completionHandler: completionHandler)
    }
  }
  
  // MARK: - Images
  func imageFromURLString(imageURLString: String, completionHandler: (UIImage?, NSError?) -> Void) {
    alamofireManager.request(.GET, imageURLString)
      .response { (request, response, data, error) in
        // use the generic response serializer that returns NSData
        if data == nil {
          completionHandler(nil, nil)
          return
        }
        let image = UIImage(data: data! as NSData)
        completionHandler(image, nil)
    }
  }
  
  // MARK: - Pagination
  private func getNextPageFromHeaders(response: NSHTTPURLResponse?) -> String? {
    if let linkHeader = response?.allHeaderFields["Link"] as? String {
      /* looks like:
      <https://api.github.com/user/20267/gists?page=2>; rel="next", <https://api.github.com/user/20267/gists?page=6>; rel="last"
      */
      // so split on "," the  on  ";"
      let components = linkHeader.characters.split {$0 == ","}.map { String($0) }
      // now we have 2 lines like '<https://api.github.com/user/20267/gists?page=2>; rel="next"'
      // So let's get the URL out of there:
      for item in components {
        // see if it's "next"
        let rangeOfNext = item.rangeOfString("rel=\"next\"", options: [])
        if rangeOfNext != nil {
          let rangeOfPaddedURL = item.rangeOfString("<(.*)>;", options: .RegularExpressionSearch)
          if let range = rangeOfPaddedURL {
            let nextURL = item.substringWithRange(range)
            // strip off the < and >;
            let startIndex = nextURL.startIndex.advancedBy(1) //advance as much as you like
            let endIndex = nextURL.endIndex.advancedBy(-2)
            let urlRange = startIndex..<endIndex
            return nextURL.substringWithRange(urlRange)
          }
        }
      }
    }
    return nil
  }
  
  // MARK: Starring / Unstarring / Star status
  func isGistStarred(gistId: String, completionHandler: (Bool?, NSError?) -> Void) {
    // GET /gists/:id/star
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.GET, urlString)
      .validate(statusCode: [204])
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(nil, lostOAuthError)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .response { (request, response, data, error) in
        // 204 if starred, 404 if not
        if let anError = error as? NSError {
          print(anError)
          if response?.statusCode == 404 {
            completionHandler(false, nil)
            return
          }
          completionHandler(nil, anError)
          return
        }
        completionHandler(true, nil)
    }
  }
  
  func starGist(gistId: String, completionHandler: (ErrorType?) -> Void) {
    //  PUT /gists/:id/star
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.PUT, urlString)
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(lostOAuthError)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .response { (request, response, data, error) in
        if let anError = error {
          print(anError)
          return
        }
        completionHandler(error)
    }
  }
  
  func unstarGist(gistId: String, completionHandler: (ErrorType?) -> Void) {
    //  PUT /gists/:id/star
    let urlString = "https://api.github.com/gists/\(gistId)/star"
    alamofireManager.request(.DELETE, urlString)
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(lostOAuthError)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .response { (request, response, data, error) in
        if let anError = error {
          print(anError)
          return
        }
        completionHandler(error)
    }
  }
  
  
  // MARK: Delete and Add
  func deleteGist(gistId: String, completionHandler: (ErrorType?) -> Void) {
    // DELETE /gists/:id
    let urlString = "https://api.github.com/gists/\(gistId)"
    alamofireManager.request(.DELETE, urlString)
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(lostOAuthError)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .response { (request, response, data, error) in
        if let anError = error {
          print(anError)
          return
        }
        completionHandler(error)
    }
  }
  
  func createNewGist(description: String, isPublic: Bool, files: [File], completionHandler: (Bool?, NSError?) -> Void) {
    let publicString: String
    if isPublic {
      publicString = "true"
    } else {
      publicString = "false"
    }
    
    var filesDictionary = [String: AnyObject]()
    for file in files {
      if let name = file.filename, contents = file.contents {
        filesDictionary[name] = ["content": contents]
      }
    }
    let parameters:[String: AnyObject] = [
      "description": description,
      "isPublic": publicString,
      "files" : filesDictionary
    ]
    
    let urlString = "https://api.github.com/gists"
    alamofireManager.request(.POST, urlString, parameters: parameters, encoding: .JSON)
      .isUnauthorized { _, _, result in
        if let unauthorized = result.value where unauthorized == true {
          let lostOAuthError = self.handleUnauthorizedResponse(urlString)
          completionHandler(nil, lostOAuthError)
          return // don't bother with .responseArray, we didn't get any data
        }
      }
      .response { (request, response, data, error) in
        if let anError = error {
          print(anError)
          completionHandler(false, nil)
          return
        }
        self.clearCache()
        completionHandler(true, nil)
    }
  }
}