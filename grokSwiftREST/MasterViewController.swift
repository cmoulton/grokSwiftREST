//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-09-11.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit
import Alamofire
import PINRemoteImage
import BRYXBanner

class MasterViewController: UITableViewController, LoginViewDelegate {
  var dateFormatter = NSDateFormatter()
  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var notConnectedBanner: Banner?
  
  
  @IBOutlet weak var gistSegmentedControl: UISegmentedControl!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    
    if let split = self.splitViewController {
      let controllers = split.viewControllers
      self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
  }
  
  override func viewWillAppear(animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
    
    super.viewWillAppear(animated)
    
    // add refresh control for pull to refresh
    if (self.refreshControl == nil) {
      self.refreshControl = UIRefreshControl()
      self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
      self.refreshControl?.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
      self.dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
      self.dateFormatter.timeStyle = NSDateFormatterStyle.LongStyle
    }
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    let defaults = NSUserDefaults.standardUserDefaults()
    if (!defaults.boolForKey("loadingOAuthToken")) {
      loadInitialData()
    }
  }
  
  override func viewWillDisappear(animated: Bool) {
    if let existingBanner = self.notConnectedBanner {
      existingBanner.dismiss()
    }
    super.viewWillDisappear(animated)
  }
  
  func loadInitialData() {
    isLoading = true
    GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler = { (error) -> Void in
      if let receivedError = error {
        print(receivedError)
        self.isLoading = false
        // TODO: handle error
        // Something went wrong, try again
        self.showOAuthLoginView()
      } else {
        self.loadGists(nil)
      }
    }
    
    if (!GitHubAPIManager.sharedInstance.hasOAuthToken()) {
      GitHubAPIManager.sharedInstance.startOAuth2Login()
    } else {
      loadGists(nil)
    }
  }
  
  func loadGists(urlToLoad: String?) {
    let completionHandler: (Result<[Gist]>, String?) -> Void = { (result, nextPage) in
      self.isLoading = false
      self.nextPageURLString = nextPage
      
      // tell refresh control it can stop showing up now
      if self.refreshControl != nil && self.refreshControl!.refreshing {
        self.refreshControl?.endRefreshing()
      }
      
      guard result.error == nil else {
        print(result.error)
        self.nextPageURLString = nil
        
        self.isLoading = false
        if let error = result.error as? NSError {
          if error.domain == NSURLErrorDomain {
            if error.code == NSURLErrorUserAuthenticationRequired {
              self.showOAuthLoginView()
            } else if error.code == NSURLErrorNotConnectedToInternet {
              let path:Path
              if self.gistSegmentedControl.selectedSegmentIndex == 0 {
                path = .Public
              } else if self.gistSegmentedControl.selectedSegmentIndex == 1 {
                path = .Starred
              } else {
                path = .MyGists
              }
              if let archived:[Gist] = PersistenceManager.loadArray(path) {
                self.gists = archived
              } else {
                self.gists = [] // don't have any saved gists
              }
              
              // show not connected error & tell em to try again when they do have a connection
              // check for existing banner
              if let existingBanner = self.notConnectedBanner {
                existingBanner.dismiss()
              }
              self.notConnectedBanner = Banner(title: "No Internet Connection",
                subtitle: "Could not load gists. Try again when you're connected to the internet",
                image: nil,
                backgroundColor: UIColor.redColor())
            }
            self.notConnectedBanner?.dismissesOnSwipe = true
            self.notConnectedBanner?.show(duration: nil)
          }
        }
        return
      }
      
      if let fetchedGists = result.value {
        if urlToLoad != nil {
          self.gists += fetchedGists
        } else {
          self.gists = fetchedGists
        }
        
        let path:Path
        if self.gistSegmentedControl.selectedSegmentIndex == 0 {
          path = .Public
        } else if self.gistSegmentedControl.selectedSegmentIndex == 1 {
          path = .Starred
        } else {
          path = .MyGists
        }
        PersistenceManager.saveArray(self.gists, path: path)
      }
      
      // update "last updated" title for refresh control
      let now = NSDate()
      let updateString = "Last Updated at " + self.dateFormatter.stringFromDate(now)
      self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)
      
      self.tableView.reloadData()
    }
    
    self.isLoading = true
    switch gistSegmentedControl.selectedSegmentIndex {
    case 0:
      GitHubAPIManager.sharedInstance.getPublicGists(urlToLoad, completionHandler: completionHandler)
    case 1:
      // TODO: verify scope
      GitHubAPIManager.sharedInstance.getMyStarredGists(urlToLoad, completionHandler: completionHandler)
    case 2:
      // TODO: verify is bearer
      GitHubAPIManager.sharedInstance.getMyGists(urlToLoad, completionHandler: completionHandler)
    default:
      print("got an index that I didn't expect for gistSegmentedControl.selectedSegmentIndex")
    }
  }
  
  func showOAuthLoginView() {
    let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
    if let loginVC = storyboard.instantiateViewControllerWithIdentifier("LoginViewController") as? LoginViewController {
      loginVC.delegate = self
      self.presentViewController(loginVC, animated: true, completion: nil)
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - Creation
  func insertNewObject(sender: AnyObject) {
    let createVC = CreateGistViewController(nibName: nil, bundle: nil)
    self.navigationController?.pushViewController(createVC, animated: true)
  }
  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let object = gists[indexPath.row] as Gist
        let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
        controller.gist = object
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }
  
  // MARK: - Table View
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return gists.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    let gist = gists[indexPath.row]
    cell.textLabel!.text = gist.gistDescription
    cell.detailTextLabel!.text = gist.ownerLogin
    cell.imageView?.image = nil
    
    // set cell.imageView to display image at gist.ownerAvatarURL
    if let urlString = gist.ownerAvatarURL, url = NSURL(string: urlString) {
      cell.imageView?.pin_setImageFromURL(url, placeholderImage: UIImage(named: "placeholder.png"))
    } else {
      cell.imageView?.image = UIImage(named: "placeholder.png")
    }
    
    // See if we need to load more gists
    let rowsToLoadFromBottom = 5;
    let rowsLoaded = gists.count
    if let nextPage = nextPageURLString {
      if (!isLoading && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom))) {
        self.loadGists(nextPage)
      }
    }
    
    return cell
  }
  
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // only allow editing my gists
    return gistSegmentedControl.selectedSegmentIndex == 2
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      let gistToDelete = gists.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
      // delete from API
      if let id = gists[indexPath.row].id {
        GitHubAPIManager.sharedInstance.deleteGist(id, completionHandler: {
          (error) in
          print(error)
          if let _ = error {
            // Put it back
            self.gists.insert(gistToDelete, atIndex: indexPath.row)
            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            // tell them it didn't work
            let alertController = UIAlertController(title: "Could not delete gist", message: "Sorry, your gist couldn't be deleted. Maybe GitHub is down or you don't have an internet connection.", preferredStyle: .Alert)
            // add ok button
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okAction)
            // show the alert
            self.presentViewController(alertController, animated:true, completion: nil)
          }
        })
      }
    }
  }
  
  // MARK: - Pull to Refresh
  func refresh(sender:AnyObject) {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(false, forKey: "loadingOAuthToken")
    
    nextPageURLString = nil // so it doesn't try to append the results
    loadInitialData()
  }
  
  // MARK: - Login View Delegate
  func didTapLoginButton() {
    let defaults = NSUserDefaults.standardUserDefaults()
    defaults.setBool(true, forKey: "loadingOAuthToken")
    
    self.dismissViewControllerAnimated(false, completion: nil)
    GitHubAPIManager.sharedInstance.startOAuth2Login()
  }
  
  // MARK: - Segmented Control
  @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
    // only show add/edit buttons for my gists
    if (gistSegmentedControl.selectedSegmentIndex == 2) {
      self.navigationItem.leftBarButtonItem = self.editButtonItem()
      let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
      self.navigationItem.rightBarButtonItem = addButton
    } else {
      self.navigationItem.leftBarButtonItem = nil
      self.navigationItem.rightBarButtonItem = nil
    }
    
    // clear gists so they can't get shown for the wrong list
    self.gists = [Gist]()
    self.tableView.reloadData()
    
    loadGists(nil)
  }
}
