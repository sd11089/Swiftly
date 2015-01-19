
import UIKit
import CoreData

class Model:NSManagedObject {
    
    /**
        Contains all model properties.  These properties arent stored directly on the object, and should
        only be accessed through the provided get/set/unset methods
    */
    var properties        = Object()
    
    /**
        Contains a record of all properties that were last saved to the server.
    */
    var priorProperties   = Object()
    
    /**
        All properties that have changed since the last save to the server.
    */
    var changedProperties:Object {
        return $.diff(self.properties, comparison: self.priorProperties)
    }
    
    private var propertyToModelMap = [String:String]()
    
    /**
        Helper method to get a clean model name from the object's dynamic type.
    */
    var modelName:String {
        let splitOne = NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
        let splitTwo = splitOne.componentsSeparatedByString("_").first!
        return splitTwo
    }
    
    /**
        Last error thrown during validation.
    */
    var validationError:NSError?
    
    /**
        Flag indicating if the model is valid based on validation rules.
    */
    var isValid:Bool {
        return self.validate(&self.validationError)
    }
    
    /**
        Flag indicating if the model hasn't yet been saved to the server
    */
    var isNew:Bool {
        var id = self.get("id") as? String
        return id == nil || id?.length == 0
    }
    
    /**
        Flag indicating that the model has changed since it was last saved to the server
    */
    var hasChanged:Bool {
        return self.changedProperties.length > 0
    }
    
    /**
        Internal list of properties that cannot be deleted from the model.  
        If a user tries to delete the property, it is set to a blank string.
    */
    private let preservedProperties = ["id", "name", "url"]
    
    
    // MARK: Subscript
    
    subscript (property:String) -> AnyObject? {
        get { return self.properties[property] }
        set { self.set(property, value: newValue) }
    }
    
    subscript (property:String, options:[ShiftModelUpdateOptions]?) -> AnyObject? {
        get { return self.properties[property] }
        set { self.set(property, value: newValue, options:options) }
    }
    
    
    // MARK: Initialization
    
    final override func awakeFromInsert() {
        self.initalize()
    }
    
    /**
        Method called when a model is created in the Managed Object context.  This method can be overriden,
        but should always call its super implementation.
    */
    func initalize() {
        self.defaults()
        self.extend()
        self.map(&self.propertyToModelMap)
    }
    
    
    // MARK: Property Observation
    
    /**
        Triggers a Shift Event that objects can listen and react to.
    */
    func trigger(event:ShiftEventType, info:[String:AnyObject]? = nil) {
        var userInfo:Object = ["model":self]
        if info != nil {
            userInfo = $.extend(userInfo, info!)
        }
        NSNotificationCenter.defaultCenter().postNotificationName(event.toString, object: self, userInfo: userInfo)
    }
    
    
    // MARK: Property Access
    
    /**
        Should be overridden, allows overriding and setting model properties on initialization.
    */
    internal func extend() {}
    
    /**
        Should be overwridden, provides a way to map model propertys to core data properties.
        Map is in the form (model property):(core data property)
    */
    internal func map(inout map:[String:String]) {}
    
    /**
        Should be overridden, provides a set of default values for model properties.
    */
    internal func defaults() {
        self["name"]     = self.modelName
        self["id"]       = ""
        self["url"]      = ""
        self["clientId"] = self.objectID.description
    }
    
    /**
        Get the current value of a property from the model.
        
        :param: property property name to get a value for
        
        :returns: property value or nil if property is undefined
    */
    func get(property:String) -> AnyObject? {
        return self.properties[property]
    }
    
    /**
        Sets the current value of a property in the model.  Options can be passed in to make the update silent.
        
        :param: property property name to set
        :param: value value to set the property to
        :param: options allows manipulating how property updates are handled
    */
    func set(property:String, value:AnyObject?, options:[ShiftModelUpdateOptions]? = nil) {
        if value == nil {
            if self.preservedProperties.contains(property) {
                self.properties[property] = ""
            }
            else {
                self.properties.removeValueForKey(property)
            }
        }
        else {
            self.properties[property] = value
        }
  
        var silent = false
        if options != nil {
            silent = options!.contains(ShiftModelUpdateOptions.Silent)
        }
        
        if !silent {
            self.trigger(.Change)
        }
    }
    
    /**
        Provides a means to bulk update model properties.
        
        :param: properties array of properties to update (key:value pair)
        :param: options allows manipulating how property updates are handled
    */
    func set(properties:[String:AnyObject], options:[ShiftModelUpdateOptions]? = nil) {
        var adjOptions = options ?? [ShiftModelUpdateOptions]()
        properties.forEach {(key, value, index, dictionary, exit) -> () in
            self.set(key, value: value, options: $.extend(adjOptions, [.Silent]))
        }
        
        var silent = false
        if options != nil {
            silent = options!.contains(ShiftModelUpdateOptions.Silent)
        }
        
        if !silent {
            self.trigger(.Change)
        }
    }
    
    /**
        Returns an HTML escaped property value
        
        :param: property property name
        
        :returns: String? escaped property value as string
    */
    func escape(property:String) -> String? {
        if self.properties[property] != nil {
            var propertyVal = self.properties[property]!.description as NSString
            var escapedVal  = propertyVal.stringByAddingPercentEscapesUsingEncoding(NSASCIIStringEncoding)
            return escapedVal
        }
        
        return nil
    }
    
    /**
        Flag indicating if the model has a specified property
    */
    func has(property:String) -> Bool {
        return self.properties[property] != nil
    }
    
    /**
        Method to remove a property from the model
    */
    func unset(property:String, options:[ShiftModelUpdateOptions]? = nil) {
        self.set(property, value: nil, options: options)
    }
    
    /**
        Removes all properties from the model and sets it back to its default state
    */
    func clear() {
        self.properties.removeAll(keepCapacity: false)
        self.defaults() // Sets back to default state
        self.trigger(.Change)
    }
    
    /**
        Returns a JSON representation of the entire model, or the passed in properties
    */
    func toJSON(properties:[String]? = nil) -> String {
        var error:NSError? = nil
        var props = self.properties
        if properties != nil {
            props = Object()
            properties!.forEach({ (elem, index, array, exit) -> () in
                props[elem] = self.get(elem)
            })
        }
        
        if let data = NSJSONSerialization.dataWithJSONObject(props, options: .PrettyPrinted, error: &error) {
            return NSString(data: data, encoding: NSUTF8StringEncoding)!
        }
        return ""
    }
    
    func prior(property:String) -> AnyObject? {
        return self.priorProperties[property]
    }
    
    
    // MARK: REST Web Services
    
    final func save(completion:ShiftNetworkEvent?) { self.save(nil, nil, completion) }
    final func save(options:[ShiftModelSaveOptions]? = nil, completion:ShiftNetworkEvent?) { self.save(nil, options, completion) }
    final func save(_ properties:[String]? = nil, var _ options:[ShiftModelSaveOptions]? = nil, _ completion:ShiftNetworkEvent? = nil) {
        //  POST/PUT
        self.validationError = nil
        if !self.validate(&self.validationError) {
            return
        }
        
        options = options ?? [ShiftModelSaveOptions]()
        
        if var url = self.get("url") as? String {
            if var name = self.get("name") as? String {
                url = url.stringByAppendingPathComponent(name)
                
                if var id = self.get("id") as? String {
                    // Compile URL
                    url = url.stringByAppendingPathComponent(id)
                    
                    // Compile parameters to pass to web service
                    var params = self.properties
                    if properties != nil {
                        params = Object()
                        properties!.forEach({ (elem, index, array, exit) -> () in
                            params[elem] = self.get(elem)
                        })
                    }
                    
                    // Check if saving model difference only
                    if options!.contains(ShiftModelSaveOptions.Difference) {
                        params = $.diff(params, comparison: self.priorProperties)
                    }
                    
                    // Compile Web Service request
                    var id            = self.get("id") as? String
                    var method:Method = (id == nil || id?.length == 0) ? .POST : .PUT
                    var req           = request(method, url, parameters: params, encoding: ParameterEncoding.JSON)
                    self.authenticate(req)
                    self.parse(method, req)
                    req.response({(request, response, _, error) -> Void in
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                            // Save context
                            if error == nil {
                                self.priorProperties = self.properties
                                
                                // Map properties to core data model
                                self.propertyToModelMap.forEach({ (key, value, index, dictionary, exit) -> () in
                                    Debug.log(.Debug, message: "Setting %s to %s", value, self.get(key))
                                    self.setValue(self.get(key), forKey: value)
                                })
                                self.managedObjectContext?.save(nil)
                            }
                            
                            var userInfo = Object()
                            userInfo["request"]  = req
                            userInfo["response"] = response ?? nil
                            userInfo["error"]    = error ?? nil
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.trigger(.Save, info: userInfo)
                                
                                if completion != nil {
                                    completion!(request: req)
                                }
                            })
                        })
                    }).resume()
                }
            }
            
            return
        }
        
        NSException(name: "Invalid URL", reason: "Model is configured without a URL", userInfo: nil).raise()
    }
    
    final func fetch(_ completion:ShiftNetworkEvent? = nil) {
        // GET
        if var url = self.get("url") as? String {
            if var name = self.get("name") as? String {
                url = url.stringByAppendingPathComponent(name)

                if var id = self.get("id") as? String {
                    if id.length == 0 {
                        Debug.log(.Notify, message: "Model.fetch(): attempted to fetch an object that doesn't have an ID")
                        return
                    }
                    
                    // Compile URL
                    url = url.stringByAppendingPathComponent(id)
                    
                    var req = request(.GET, url)
                    self.authenticate(req)
                    req.response({ (request, response, data, error) -> Void in
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                            var userInfo = Object()
                            userInfo["request"]  = req
                            userInfo["response"] = response ?? nil
                            userInfo["error"]    = error ?? nil
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.parse(.GET, req)
                                self.trigger(.Fetch, info: userInfo)
                                
                                // Execute completion closure
                                if completion != nil {
                                    completion!(request: req)
                                }
                                
                                // Save context
                                if error == nil {
                                    self.priorProperties = self.properties
                                    
                                    // Map properties to core data model
                                    self.propertyToModelMap.forEach({ (key, value, index, dictionary, exit) -> () in
                                        Debug.log(.Debug, message: "Setting %s to %s", value, self.get(key))
                                        self.setValue(self.get(key), forKey: value)
                                    })
                                    self.managedObjectContext?.save(nil)
                                }
                            })
                            
                        
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                                
                            })
                        })
                    }).resume()
                }
            }
            
            return
        }
        
        NSException(name: "Invalid URL", reason: "Model is configured without a URL", userInfo: nil).raise()
    }
    
    final func destroy(_ completion:ShiftNetworkEvent? = nil) {
        // DELETE
        if var url = self.get("url") as? String {
            if var name = self.get("name") as? String {
                url = url.stringByAppendingPathComponent(name)
                
                if var id = self.get("id") as? String {
                    if id.length == 0 {
                        Debug.log(.Notify, message: "Model.destroy(): attempted to destroy an object that doesn't have an ID")
                        return
                    }
                    
                    // Compile URL
                    url = url.stringByAppendingPathComponent(id)
                    
                    var req = request(.DELETE, url)
                    self.authenticate(req)
                    self.parse(.DELETE, req)
                    
                    req.response({(request, response, data, error) -> Void in
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                            var userInfo = Object()
                            userInfo["request"]  = req
                            userInfo["response"] = response ?? nil
                            userInfo["error"]    = error ?? nil
                            
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.trigger(.Delete, info: userInfo)
                                
                                if completion != nil {
                                    completion!(request: req)
                                }
                            })
                            
                            // Delete from local context
                            if error == nil {
                                self.managedObjectContext?.deleteObject(self)
                                self.managedObjectContext?.save(nil)
                            }
                        })
                    }).resume()
                }
            }
            
            return
        }
        
        NSException(name: "Invalid URL", reason: "Model is configured without a URL", userInfo: nil).raise()
    }
    
    func parse(method:Method, _ request:Request) {}
    //func parse(method:Method, _ request:NSURLRequest, response:NSHTTPURLResponse?, json:JSON, error:NSError?) {}
    func authenticate(request:Request) {}
    
    func validate(inout error:NSError?) -> Bool {
        return true
    }
    
    func validate(validationFunc:(model:Model) -> Bool) -> Bool {
        return validationFunc(model: self)
    }
}




