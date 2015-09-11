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
  
  // MARK: - Basic Auth
  func printPublicGists() -> Void {
    Alamofire.request(.GET, "https://api.github.com/gists/public")
      .responseString { _, _, result in
        if let receivedString = result.value {
          print(receivedString)
        }
    }
  }
  
  func getPublicGists(completionHandler: (Result<[Gist]>) -> Void) {
    Alamofire.request(.GET, "https://api.github.com/gists/public")
      .validate()
      .responseArray { (request, response, result: Result<[Gist]>) in
        completionHandler(result)
    }
  }
  
}