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
      guard let responseData = data else {
        let failureReason = "Array could not be serialized because input data was nil."
        let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
        return .Failure(data, error)
      }
      
      let jsonData: AnyObject?
      do {
        jsonData = try NSJSONSerialization.JSONObjectWithData(responseData, options: [])
      } catch  {
        let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: "JSON could not be converted to data")
        return .Failure(responseData, error)
      }
      
      let json = SwiftyJSON.JSON(jsonData!)
      if let newObject = T(json: json) {
        // TODO: should this be a failable init?
        return .Success(newObject)
      }
      let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: "JSON could not be converted to object")
      return .Failure(responseData, error)
    }
    
    return response(responseSerializer: responseSerializer,
      completionHandler: completionHandler)
  }
  
  public func responseArray<T: ResponseJSONObjectSerializable>(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<[T]>) -> Void) -> Self {
    let responseSerializer = GenericResponseSerializer<[T]> { request, response, data in
      guard let responseData = data else {
        let failureReason = "Array could not be serialized because input data was nil."
        let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
        return .Failure(data, error)
      }
      
      let jsonData: AnyObject?
      do {
        jsonData = try NSJSONSerialization.JSONObjectWithData(responseData, options: [])
      } catch  {
        let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: "JSON could not be converted to object")
        return .Failure(responseData, error)
      }
      
      let json = SwiftyJSON.JSON(jsonData!)
      var objects: [T] = []
      for (_, item) in json {
        if let object = T(json: item) {
          objects.append(object)
        }
      }
      return .Success(objects)
    }
    
    return response(responseSerializer: responseSerializer,
      completionHandler: completionHandler)
  }
}