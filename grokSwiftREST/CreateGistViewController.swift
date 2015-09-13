//
//  CreateGistViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-12.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import XLForm

class CreateGistViewController: XLFormViewController {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.initializeForm()
  }
  
  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.initializeForm()
  }
  
  private func initializeForm() {
    let form = XLFormDescriptor(title: "Gist")
    
    // Section 1
    let section1 = XLFormSectionDescriptor.formSection() as XLFormSectionDescriptor
    form.addFormSection(section1)
    
    let descriptionRow = XLFormRowDescriptor(tag: "description", rowType: XLFormRowDescriptorTypeText, title: "Description")
    descriptionRow.required = true
    section1.addFormRow(descriptionRow)
    
    let isPublicRow = XLFormRowDescriptor(tag: "isPublic", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: "Public?")
    isPublicRow.required = false
    section1.addFormRow(isPublicRow)
    
    let section2 = XLFormSectionDescriptor.formSectionWithTitle("File 1") as XLFormSectionDescriptor
    form.addFormSection(section2)
    
    let filenameRow = XLFormRowDescriptor(tag: "filename", rowType: XLFormRowDescriptorTypeText, title: "Filename")
    filenameRow.required = true
    section2.addFormRow(filenameRow)
    
    let fileContents = XLFormRowDescriptor(tag: "fileContents", rowType: XLFormRowDescriptorTypeTextView, title: "File Contents")
    fileContents.required = true
    section2.addFormRow(fileContents)
    
    self.form = form
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self, action: "cancelPressed:")
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Save, target: self, action: "savePressed:")
  }
  
  func cancelPressed(button: UIBarButtonItem) {
    self.navigationController?.popViewControllerAnimated(true)
  }
  
  func savePressed(button: UIBarButtonItem) {
    let validationErrors : Array<NSError> = self.formValidationErrors() as! Array<NSError>
    guard (validationErrors.count == 0) else {
      self.showFormValidationError(validationErrors.first)
      return
    }
    self.tableView.endEditing(true)
    let isPublic: Bool
    if let isPublicValue = form.formRowWithTag("isPublic")?.value as? Bool {
      isPublic = isPublicValue
    } else {
      isPublic = false
    }
    if let description = form.formRowWithTag("description")?.value as? String,
      filename = form.formRowWithTag("filename")?.value as? String,
      fileContents = form.formRowWithTag("fileContents")?.value as? String {
        var files = [File]()
        if let file = File(aName: filename, aContents: fileContents) {
          files.append(file)
        }
        GitHubAPIManager.sharedInstance.createNewGist(description, isPublic: isPublic, files: files, completionHandler: {
          (success, error) in
          guard error == nil, let successValue = success where successValue == true else {
            if let anError = error {
              print(anError)
            }
            let alertController = UIAlertController(title: "Could not create gist", message: "Sorry, your gist couldn't be deleted. Maybe GitHub is down or you don't have an internet connection.", preferredStyle: .Alert)
            // add ok button
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated:true, completion: nil)
            return
          }
          self.navigationController?.popViewControllerAnimated(true)
        })
    }
  }
  
}