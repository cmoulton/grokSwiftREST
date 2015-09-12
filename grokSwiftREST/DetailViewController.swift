//
//  DetailViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-11.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit
import WebKit

class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  @IBOutlet weak var tableView: UITableView!
  var isStarred: Bool?

  var gist: Gist? {
    didSet {
        // Update the view.
        self.configureView()
    }
  }

  func configureView() {
    // Update the user interface for the detail item.
    if let _: Gist = self.gist {
      fetchStarredStatus()
      if let detailsView = self.tableView {
        detailsView.reloadData()
      }
    }
  }
  
  func fetchStarredStatus() {
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.isGistStarred(gistId, completionHandler: {
        (status, error) in
        if error != nil {
          print(error)
        }
        if (self.isStarred == nil && status != nil) {// just got it
          self.isStarred = status
          self.tableView?.insertRowsAtIndexPaths(
            [NSIndexPath(forRow: 2, inSection: 0)],
            withRowAnimation: .Automatic)
        }
      })
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.configureView()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: Table view data source and delegate
  
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      if let _ = isStarred {
        return 3
      }
      return 2
    } else {
      return gist?.files?.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 {
      return "About"
    } else {
      return "Files"
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    if indexPath.section == 0 {
      if indexPath.row == 0 {
        cell.textLabel?.text = gist?.description
      } else if indexPath.row == 1 {
        cell.textLabel?.text = gist?.ownerLogin
      } else {
        if let starred = isStarred {
          if starred {
            cell.textLabel?.text = "Unstar"
          } else {
            cell.textLabel?.text = "Star"
          }
        }
      }
    } else {
      if let file = gist?.files?[indexPath.row] {
        cell.textLabel?.text = file.filename
        // TODO: add disclosure indicators
      }
    }
    return cell
  }
  
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    if indexPath.section == 0 {
      if indexPath.row == 2 { // star or unstar
        if let starred = isStarred {
          if starred {
            // unstar
            unstarThisGist()
          } else {
            // star
            starThisGist()
          }
        }
      }
    } else if indexPath.section == 1 {
      if let file = gist?.files?[indexPath.row], urlString = file.raw_url, url = NSURL(string: urlString) {
        let webView = WKWebView()
        
        let webViewWrapperVC = UIViewController()
        webViewWrapperVC.view = webView
        webViewWrapperVC.title = file.filename
        
        let request = NSURLRequest(URL: url)
        webView.loadRequest(request)
        
        self.navigationController?.pushViewController(webViewWrapperVC, animated: true)
      }
    }
  }
  
  func starThisGist() {
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.starGist(gistId, completionHandler: {
        (error) in
        if error != nil {
          print(error)
        }
        self.isStarred = true
        self.tableView.reloadRowsAtIndexPaths(
          [NSIndexPath(forRow: 2, inSection: 0)],
          withRowAnimation: .Automatic)
      })
    }
  }
  
  func unstarThisGist() {
    if let gistId = gist?.id {
      GitHubAPIManager.sharedInstance.unstarGist(gistId, completionHandler: {
        (error) in
        if error != nil {
          print(error)
        }
        self.isStarred = false
        self.tableView.reloadRowsAtIndexPaths(
          [NSIndexPath(forRow: 2, inSection: 0)],
          withRowAnimation: .Automatic)
      })
    }
  }
  
}
