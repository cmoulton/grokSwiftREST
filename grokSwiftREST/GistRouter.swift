//
//  GistRouter.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-10-20.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire

enum GistRouter: URLRequestConvertible {
  static let baseURLString:String = "https://api.github.com/"

  case GetPublic() // GET "https://api.github.com/gists/public"
  case GetMyStarred() // GET "https://api.github.com/gists/starred"
  case GetMine() // GET "https://api.github.com/gists"
  case GetAtPath(String) // GET at given path
  case IsStarred(String) // GET https://api.github.com/gists/\(gistId)/star
  case Star(String) // PUT https://api.github.com/gists/\(gistId)/star
  case Unstar(String) // DELETE https://api.github.com/gists/\(gistId)/star
  case Create([String: AnyObject]) // POST "https://api.github.com/gists"
  case Delete(String) // DELETE https://api.github.com/gists/\(gistId)
  
  var URLRequest: NSMutableURLRequest {
    var method: Alamofire.Method {
      switch self {
      case .GetPublic:
        return .GET
      case .GetMyStarred:
        return .GET
      case .GetMine:
        return .GET
      case .GetAtPath:
        return .GET
      case .IsStarred:
        return .GET
      case .Star:
        return .PUT
      case .Unstar:
        return .DELETE
      case .Create:
        return .POST
      case .Delete:
        return .DELETE
      }
    }
    
    let result: (path: String, parameters: [String: AnyObject]?) = {
      switch self {
      case .GetPublic:
        return ("gists/public", nil)
      case .GetMyStarred:
        return ("gists/starred", nil)
      case .GetMine:
        return ("gists", nil)
      case .GetAtPath(let path):
        return (path, nil) // TODO!
      case .IsStarred(let id):
        return ("gists/\(id)/star", nil)
      case .Star(let id):
        return ("gists/\(id)/star", nil)
      case .Unstar(let id):
        return ("gists/\(id)/star", nil)
      case .Create(let params):
        return ("gists", params)
      case .Delete(let id):
        return ("gists/\(id)", nil)
      }
    }()
    
    let URL = NSURL(string: GistRouter.baseURLString)!
    // TODO: test with .GetAtPath
    let URLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(result.path))
    
    // Set Accept header
    URLRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
    
    // Set OAuth token
    if let token = GitHubAPIManager.sharedInstance.OAuthToken {
      URLRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")
    }

    let encoding = Alamofire.ParameterEncoding.JSON
    let (encoded, _) = encoding.encode(URLRequest, parameters: result.parameters)
    
    encoded.HTTPMethod = method.rawValue
    
    return encoded
  }
}