//
//  File.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-12.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import SwiftyJSON

class File: NSObject, NSCoding, ResponseJSONObjectSerializable {
  var filename: String?
  var raw_url: String?
  var contents: String?
  
  required init?(json: JSON) {
    self.filename = json["filename"].string
    self.raw_url = json["raw_url"].string
  }
  
  init?(aName: String?, aContents: String?) {
    self.filename = aName
    self.contents = aContents
  }
  
  // MARK: NSCoding
  @objc func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(self.filename, forKey: "filename")
    aCoder.encodeObject(self.raw_url, forKey: "raw_url")
    aCoder.encodeObject(self.contents, forKey: "contents")
  }
  
  @objc required convenience init?(coder aDecoder: NSCoder) {
    let filename = aDecoder.decodeObjectForKey("filename") as? String
    let contents = aDecoder.decodeObjectForKey("contents") as? String
    
    // use the existing init function
    self.init(aName: filename, aContents: contents)
    self.raw_url = aDecoder.decodeObjectForKey("raw_url") as? String
  }
}