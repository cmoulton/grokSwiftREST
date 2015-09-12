//
//  File.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-12.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import SwiftyJSON

class File: ResponseJSONObjectSerializable {
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
}