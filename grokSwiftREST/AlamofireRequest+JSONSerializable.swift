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
      
      let json = SwiftyJSON.JSON(data: responseData)
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
      
      let json = SwiftyJSON.JSON(data: responseData)
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
  
  public func isUnauthorized(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<Bool>) -> Void) -> Self {
    let responseSerializer = GenericResponseSerializer<Bool> { request, response, data in
      if let code = response?.statusCode {
        return Result.Success(code == 401)
      }
      let error = Error.errorWithCode(.StatusCodeValidationFailed, failureReason: "No status code received")
      return .Failure(nil, error)
    }
    
    return response(responseSerializer: responseSerializer,
      completionHandler: completionHandler)
  }
}