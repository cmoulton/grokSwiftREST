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
  func printPublicGists() -> Void {
    alamofireManager.request(.GET, "https://api.github.com/gists/public")
      .responseString { _, _, result in
        if let receivedString = result.value {
          print(receivedString)
        }
    }
  }
  
  func getPublicGists(completionHandler: (Result<[Gist]>) -> Void) {
    alamofireManager.request(.GET, "https://api.github.com/gists/public")
      .validate()
      .responseArray { (request, response, result: Result<[Gist]>) in
        completionHandler(result)
    }
  }
  
}