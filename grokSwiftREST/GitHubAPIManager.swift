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

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  
  var alamofireManager:Alamofire.Manager
  
  init () {
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
    let manager = Alamofire.Manager(configuration: configuration)
    alamofireManager = manager
    addSessionHeader(alamofireManager, key: "Accept", value: "application/vnd.github.v3+json")
  }
  
  // MARK: - Headers
  func addSessionHeader(manager: Alamofire.Manager, key: String, value: String) {
    var headers:[NSObject : AnyObject]
    if let existingHeaders = alamofireManager.session.configuration.HTTPAdditionalHeaders as? [String: String] {
      headers = existingHeaders
    } else {
      headers = [NSObject : AnyObject]()
    }
    headers[key] = value
    let config = alamofireManager.session.configuration
    config.HTTPAdditionalHeaders = headers
    print(config.HTTPAdditionalHeaders)
    alamofireManager = Alamofire.Manager(configuration: config)
  }
  
  func removeSessionHeaderIfExists(manager: Alamofire.Manager, key: String) {
    if var headers = alamofireManager.session.configuration.HTTPAdditionalHeaders as? [String: String] {
      headers.removeValueForKey(key)
      let config = alamofireManager.session.configuration
      config.HTTPAdditionalHeaders = headers
      print(config.HTTPAdditionalHeaders)
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
  
  // MARK: - Public Gists
  func printPublicGists() -> Void {
    alamofireManager.request(.GET, "https://api.github.com/gists/public")
      .responseString { _, _, result in
        if let receivedString = result.value {
          print(receivedString)
        }
    }
  }
  
  func getGists(urlString: String, completionHandler: (Result<[Gist]>, String?) -> Void) {
    alamofireManager.request(.GET, urlString)
      .validate()
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
}