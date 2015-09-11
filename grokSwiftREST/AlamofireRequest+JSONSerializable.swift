//
//  AlamofireRequest+JSONSerializable.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-11.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

extension Alamofire.Request {
  public func responseObject<T: ResponseJSONObjectSerializable>(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<T>) -> Void) -> Self {
    let responseSerializer = GenericResponseSerializer<T> { request, response, data in
      if let responseData = data {
        let jsonData:AnyObject?
        do {
          jsonData = try NSJSONSerialization.JSONObjectWithData(responseData, options: [])
        } catch  {
          return .Failure(responseData, error)
        }
        
        let json = SwiftyJSON.JSON(jsonData!)
        if let newObject = T(json: json) {
          // TODO: should this be a failable init?
          return .Success(newObject)
        }
      }
      // TODO: handle & return appropriate error(s)
      let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: "JSON could not be converted to object")
      return .Failure(nil, error)
    }
    
    return response(responseSerializer: responseSerializer,
      completionHandler: completionHandler)
  }
  
  public func responseArray<T: ResponseJSONObjectSerializable>(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<[T]>) -> Void) -> Self {
    let responseSerializer = GenericResponseSerializer<[T]> { request, response, data in
      if let responseData = data {
        let jsonData:AnyObject?
        do {
          jsonData = try NSJSONSerialization.JSONObjectWithData(responseData, options: [])
        } catch  {
          return .Failure(responseData, error)
        }
        var objects: [T] = []
        let json = SwiftyJSON.JSON(jsonData!)
        for (_, item) in json {
          if let object = T(json: item) {
            objects.append(object)
          }
        }
        return .Success(objects)
      }
      // TODO: handle & return appropriate error(s)
      let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: "JSON could not be converted to object")
      return .Failure(nil, error)
    }
    
    return response(responseSerializer: responseSerializer,
      completionHandler: completionHandler)
  }
}