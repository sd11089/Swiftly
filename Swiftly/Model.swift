
import UIKit
import CoreData

class Model:NSManagedObject {
    
    /**
        Contains all model properties.  These properties arent stored directly on the object, and should
        only be accessed through the provided get/set/unset methods
    */
    var properties = Hash()
    
    /**
        Contains a record of all properties that were last saved to the server.
    */
    var priorProperties = Hash()
    
    /**
        All properties that have changed since the last save to the server.
    */
    var changedProperties:Hash {
        return $.diff(self.properties, comparison: self.priorProperties)
    }
    
    /**
        Pointer to the collection that this model is a part of.
    */
    var collection:Collection?
    
    private var propertyToModelMap = [String:String]()
    
    /**
        Parses what is populated from the Map function and returns all properties
        associated with the ManagedObjectModel.
    */
    var managedObjectModelProperties:[String] {
        var props = [String]()
        self.propertyToModelMap.forEach { (key, value, index, dictionary, exit) -> () in
            props.append(value)
        }
        return props
    }
    
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
        return self.validate(nil, &self.validationError)
    }
    
    /**
        Flag indicating if the model is valid based on validation rules and the passed in method.
    */
    func isValid(method:Method) -> Bool {
        return self.validate(method, &self.validationError)
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
    
    subscript (property:String, options:[Options]?) -> AnyObject? {
        get { return self.properties[property] }
        set { self.set(property, value: newValue, options:options) }
    }
    
    
    // MARK: Initialization
    
    final override func awakeFromInsert() {
        self.initalize()
    }
    
    /**
        Method called when a model is created in the Managed Hash context.  This method can be overriden,
        but should always call its super implementation.
    */
    func initalize() {
        self.defaults()
        self.extend()
        self.map(&self.propertyToModelMap)
    }
    
    
    // MARK: Property Observation
    
    /**
        Triggers a Swiftly Event that objects can listen and react to.
    */
    func trigger(event:Swiftly.Event, info:[String:AnyObject]? = nil) {
        $.trigger(self, event: event, info: info)
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
        Get the current value of an array of properties from the model in the form of a hash.
        
        :param: properties property names to retrieve
    
        :returns: Hash hash object containing property values
    */
    func get(properties:[String]) -> Hash {
        var hash = Hash()
        properties.forEach { (prop, index, array, exit) -> () in
            if let value:AnyObject = self.get(prop) {
                hash[prop] = value
            }
        }
        return hash
    }
    
    /**
        Sets the current value of a property in the model.  Options can be passed in to make the update silent.
        
        :param: property property name to set
        :param: value value to set the property to
        :param: options allows manipulating how property updates are handled
    */
    func set(property:String, value:AnyObject?, options:[Options]? = nil) {
        if value == nil {
            if self.preservedProperties.inArray(property) {
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
            silent = options!.inArray(Options.Silent)
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
    func set(properties:[String:AnyObject], options:[Options]? = nil) {
        var adjOptions = options ?? [Options]()
        properties.forEach {(key, value, index, dictionary, exit) -> () in
            self.set(key, value: value, options: $.extend(adjOptions, [.Silent]))
        }
        
        var silent = false
        if options != nil {
            silent = options!.inArray(Options.Silent)
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
    
        :param: property property name to check in the model
        
        :returns: bool true if the model contains the passed in property name
    */
    func has(property:String) -> Bool {
        return self.properties[property] != nil
    }
    
    /**
        Method to remove a property from the model
    
        :param: property property name to remove from the model
        :param: options array of options that affect how the property is removed
    */
    func unset(property:String, options:[Options]? = nil) {
        self.set(property, value: nil, options: options)
    }
    
    /**
        Removes all properties from the model and sets it back to its default state
    
        :options: options array of options that affect how the properties are cleared from the model
    */
    func clear(options:[Options]? = nil) {
        self.properties.removeAll(keepCapacity: false)
        self.defaults() // Sets back to default state
        
        var opts = options ?? [Options]()
        if !opts.inArray(Options.Silent) {
            self.trigger(.Change)
        }
    }
    
    /**
        Returns a JSON representation of the entire model, or the passed in properties
    
        :param: properties array of properties to return in JSON format
        
        :returns: string JSON string
    */
    func toJSON(properties:[String]? = nil, options:NSJSONWritingOptions = .PrettyPrinted) -> String {
        var error:NSError? = nil
        var props = self.properties
        if properties != nil {
            props = Hash()
            properties!.forEach({ (elem, index, array, exit) -> () in
                props[elem] = self.get(elem)
            })
        }
        
        if let data = NSJSONSerialization.dataWithJSONObject(props, options: options, error: &error) {
            return NSString(data: data, encoding: NSUTF8StringEncoding)!
        }
        return ""
    }
    
    /**
        Returns the value of a property from the last time the model was saved to the server.
    
        :param: property property name to get the prior value for
        
        :returns: prior property value
    */
    func prior(property:String) -> AnyObject? {
        return self.priorProperties[property]
    }
    
    // MARK: Core Data
    
    /**
        Syncs the models properties with it's core data model.  Provides hooks for user to transform property
        value prior to it being synced into the core data model.
    */
    final func sync() {
        // Map properties to core data model
        self.propertyToModelMap.forEach({ (key, value, index, dictionary, exit) -> () in
            var propertyValue:AnyObject? = self.get(key)
            self.syncMassage(key, value: &propertyValue)
            self.setValue(propertyValue, forKey: value)
        })
        self.managedObjectContext?.save(nil)
    }
    
    /**
        Should be overridden.  This method provides the hook for model properties to be massaged prior
        to being synced with the Core Data model
    */
    func syncMassage(property:String, inout value:AnyObject?) {}
    
    
    // MARK: REST Web Services
    
    /**
        Convience method for save that takes a completion closure
    */
    final func save(completion:SwiftlyNetworkEvent?) {
        self.save(nil, nil, completion)
    }
    
    /**
        Convience method for save that takes options and a completion closure
    */
    final func save(options:[Options]? = nil, completion:SwiftlyNetworkEvent?) {
        self.save(nil, options, completion)
    }
    
    /**
        Handles saving the model to a remote server, as well as syncing core data properties.  Adheres to the CRUD principle.
        This executes either a PUT or POST call, depending on if the model has an ID.
    
        :param: properties array of properties to save
        :param: options array of options that affect how the object is saved
        :param: completion closure that is executed after receiving a response
    */
    final func save(_ properties:[String]? = nil, _ options:[Options]? = nil, _ completion:SwiftlyNetworkEvent? = nil) {
        var options = options == nil ? [Options]() : options
        
        var url  = self.get("url") as? String ?? ""
        var name = self.get("name") as? String ?? ""
        var id   = self.get("id") as? String ?? ""
        if url.length == 0 || name.length == 0 {
            NSException(name: "Invalid URL", reason: "Model is configured without a URL or Name", userInfo: nil).raise()
        }
        
        // Validate model
        self.validationError = nil
        if !self.validate((id.length == 0) ? .POST : .PUT, &self.validationError) {
            return
        }
        
        // Generate URL - url/name/id
        url = url.stringByAppendingPathComponent(name).stringByAppendingPathComponent(id)
        
        // Compile parameters to pass to web service
        var params = self.properties
        if properties != nil {
            params = Hash()
            properties!.forEach({ (elem, index, array, exit) -> () in
                params[elem] = self.get(elem)
            })
        }
        
        // Check if saving model difference only
        if options!.inArray(Options.Difference) {
            params = $.diff(params, comparison: self.priorProperties)
        }
        
        // Massage properties
        params.forEach {(key, value, index, dictionary, exit) -> () in
            var propertyValue:AnyObject? = value
            self.saveMassage(key, value: &propertyValue)
            params[key] = propertyValue
        }
        
        // Compile Web Service request
        var method:Method = (id.length == 0) ? .POST : .PUT
        var req           = request(method, url, parameters: params, encoding: ParameterEncoding.JSON)
        
        // Supply hooks for authentication
        self.authenticate(req)
        
        // Execute request and handle response
        req.responseMulti({ (request, response, responseTuple, error) -> Void in
            // Save context
            if error == nil {
                self.priorProperties = self.properties
            }
            
            // Parse response
            if let hash = self.parse(request, response: response, json: responseTuple.json, error: error) {
                self.set(hash)
            }
            
            self.sync()
            
            // Notify listeners that fetch request completed
            var userInfo = Hash()
            userInfo["request"]  = req
            userInfo["response"] = response ?? nil
            userInfo["error"]    = error ?? nil
            self.trigger(.Save, info: userInfo)
            
            // Execute completion handler
            if completion != nil {
                completion!(request: req)
            }
        }).resume()
    }
    
    /**
        Should be overridden.  This method provides the hook for model properties to be massaged prior
        to being saved to the remote server.
    */
    func saveMassage(property:String, inout value:AnyObject?) {}
    
    /**
        Handles fetching the model from a remote server, as well as syncing core data properties.  Adheres to the CRUD principle.
        This executes a GET request.
    
        :param: completion closure that is executed after receiving a response
    */
    final func fetch(_ completion:SwiftlyNetworkEvent? = nil) {
        var url  = self.get("url") as? String ?? ""
        var name = self.get("name") as? String ?? ""
        var id   = self.get("id") as? String ?? ""
        if url.length == 0 || name.length == 0 || id.length == 0 {
            NSException(name: "Invalid URL", reason: "Model is configured without a URL, Name or ID", userInfo: nil).raise()
        }
        
        // Generate URL - url/name/id
        url = url.stringByAppendingPathComponent(name).stringByAppendingPathComponent(id)
        
        // Create request
        var req = request(.GET, url)
        
        // Provide hooks for authentication
        self.authenticate(req)
        
        // Execute request and handle response
        req.responseMulti({ (request, response, responseTuple, error) -> Void in
            if error == nil {
                self.priorProperties = self.properties
            }
            
            // Parse response
            if let hash = self.parse(request, response: response, json: responseTuple.json, error: error) {
                var diffLen = $.diff(self.priorProperties, comparison: hash).length
                if diffLen > 0 {
                    self.set(hash)
                }
            }
            
            // Save context
            self.sync()
            
            // Notify listeners that fetch request completed
            var userInfo = Hash()
            userInfo["request"]  = req
            userInfo["response"] = response ?? nil
            userInfo["error"]    = error ?? nil
            self.trigger(.Fetch, info: userInfo)
            
            // Execute completion handler
            if completion != nil {
                completion!(request: req)
            }
        }).resume()
    }
    
    /**
        Handles deleting the model from a remote server, as well as removing the model in Core Data.  Adheres to the CRUD principle.
        This executes a DELETE request.
    
        :param: completion closure that is executed after receiving a response
    */
    final func destroy(_ completion:SwiftlyNetworkEvent? = nil) {
        self.validationError = nil
        if !self.validate(.DELETE, &self.validationError) {
            return
        }
        
        var url  = self.get("url") as? String ?? ""
        var name = self.get("name") as? String ?? ""
        var id   = self.get("id") as? String ?? ""
        if url.length == 0 || name.length == 0 || id.length == 0 {
            NSException(name: "Invalid URL", reason: "Model is configured without a URL, Name or ID", userInfo: nil).raise()
        }
        
        // Generate URL - url/name/id
        url = url.stringByAppendingPathComponent(name).stringByAppendingPathComponent(id)
                
        // Create request
        var req = request(.DELETE, url)
        
        // Provide hooks for authentication
        self.authenticate(req)
        
        // Execute request and handle response
        req.response({ (request, response, data, error) -> Void in
            // Notify listeners that delete request completed
            var userInfo = Hash()
            userInfo["request"]  = req
            userInfo["response"] = response ?? nil
            userInfo["error"]    = error ?? nil
            self.trigger(.Delete, info: userInfo)
            
            // Execute completion closure
            if completion != nil {
                completion!(request: req)
            }
            
            // Delete from local context
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                if error == nil {
                    self.managedObjectContext?.deleteObject(self)
                    self.managedObjectContext?.save(nil)
                }
            })
        }).resume()
    }

    /**
        Called from Save and Fetch when a response is returned.  Provides a hook for digesting the returned response.  This method should return a 
        porperty hash to be set.
    
        :param: request URL Request - contains request headers and other information
        :param: response URL Response - contains response headers and other information
        :param: responseObjects Formatted response objects - raw data, string and json
        :param: error error that occured during request, if any
    */
    //func parse(request:NSURLRequest, response:NSHTTPURLResponse?, responseObjects:(data:AnyObject?, string:String?, json:JSON?), error:NSError?) {}
    func parse(request:NSURLRequest, response:NSHTTPURLResponse?, json:JSON?, error:NSError?) -> Hash? { return nil }
    
    /**
        Provides a hook to authenticate requests.  Refer to AlamoFire's documentation to learn more.
    */
    func authenticate(request:Request) {}
    
    
    // MARK: Model Validation
    
    /**
        Standard validation method.  This is called from Save and Delete, as well as when calling isValid.
    */
    func validate(_ method:Method? = nil, inout _ error:NSError?) -> Bool {
        return true
    }
    
    /**
        Stand alone validation method.  Pass in a validation closure to determine if the model passes validation tests.  The closure is not stored,
        and doesn't affect the model.  This is used for individual scenario validation testing.
    */
    func validate(validationFunc:(model:Model) -> Bool) -> Bool {
        return validationFunc(model: self)
    }
    
    /**
        Checks if the model that is passed in is equal to this model.  This equality check is 
        used to check if it is representing the same server side object.
    */
    func isEqualTo(model:Model) -> Bool {
        var isEqual = true
        self.properties.forEach {(prop, value, index, dictionary, exit) -> () in
            if value !== model.get(prop) {
                isEqual = false
                exit    = true
            }
        }
        return isEqual
    }
    
    func instance() -> Model? {
        if self.managedObjectContext != nil {
            return NSEntityDescription.insertNewObjectForEntityForName(self.modelName, inManagedObjectContext: self.managedObjectContext!) as? Model
        }
        return nil
    }
}




