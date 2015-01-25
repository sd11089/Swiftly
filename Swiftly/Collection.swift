
import UIKit
import CoreData

class Collection:NSObject {
    
    /**
        Name of the model.  Used to compile the URL to the server location as well as to create the local Core Data models.
    */
    var modelName:String!

    /**
        Array of models contained in the collection.
    */
    var models = [Model]()
    
    /**
        Array of models that were contained in the collection prior to the last fetch event.
    */
    var priorModels = [Model]()
    
    /**
        Array of all the models that have changed since the last update.
    */
    var updatedModels:[Model] {
        var models = [Model]()
        self.models.forEach {(model, index, allModels, exit) -> () in
            if !self.priorModels.inArray(model) || model.hasChanged  {
                models.append(model)
            }
        }
        return models
    }
    
    /**
        Core Data context to create models in.
    */
    var managedObjectContext:NSManagedObjectContext!
    
    /**
        Base URL on the server.
    */
    var url:String!
    
    /**
        Name of the handler on the server that returns the collection of objects.
    */
    var name:String?
    
    /**
        Returns the total number of models in the collection.
    */
    var length:Int {
        return self.models.length
    }
    
    /**
        Flag indicating if the collection is empty.
    */
    var isEmpty:Bool {
        return self.length == 0
    }
    
    /**
        A sorting operator that is used when sorting the collection.
    */
    var comparator:((modelA:Model, modelB:Model) -> Int)?
    
    // MARK: Initializers
    
    override init() {
        super.init()
        self.initalize()
    }
    
    /**
        Provides a convenient way to initialize a new collection with the managed object context.
    */
    convenience init(context:NSManagedObjectContext) {
        self.init()
        self.managedObjectContext = context
    }
    
    /**
        Provides a convenient way to initialize a new collection with the model name and context
    */
    convenience init(model:String, context:NSManagedObjectContext) {
        self.init()
        self.modelName = model
        self.managedObjectContext = context
    }
    
    /**
        Provides a convenient way to initialze a new collection and populate it with models.  Automatically sets the
        model name based on the passed in models.
    */
    convenience init(models:[Model], context:NSManagedObjectContext) {
        self.init()
        self.models    = models
        self.modelName = models.first?.modelName
        self.managedObjectContext = context
    }
    
    deinit {
        self.stopListening(object: self)
    }
    
    /**
        Should be overwritten.  Called when the class is first initialized.  Call super.initialize() to chain initalizations.
    */
    func initalize() {
        self.defaults()
        self.extend()
    }
    
    /**
        Should be overwritten, used to extend and overwrite this class.
    */
    func extend() {}
    
    /**
        Should be overwritten, used to populate default property values.
    */
    func defaults() {
        self.name = self.modelName
    }
    
    /**
        Returns a string JSON representation of the entire collection
        
        :param: options JSON writing options
        
        :returns: returns a string representation of a JSON object
    */
    func toJSON(properties:[String]? = nil, options:NSJSONWritingOptions = .PrettyPrinted) -> String? {
        var error:NSError? = nil
        var allModels      = [Hash]()
        self.models.forEach { (model, index, array, exit) -> () in
            var props = model.properties
            if properties != nil {
                props = Hash()
                properties!.forEach({ (elem, index, array, exit) -> () in
                    props[elem] = model.get(elem)
                })
            }
            allModels.append(props)
        }
        
        if let data = NSJSONSerialization.dataWithJSONObject(allModels, options: options, error: &error) {
            return NSString(data: data, encoding: NSUTF8StringEncoding)!
        }
        
        return ""
    }
    
    /**
        Triggers a Swiftly Event that objects can listen and react to.
    */
    func trigger(event:Swiftly.Event, info:[String:AnyObject]? = nil) {
        $.trigger(self, event: event, info: info)
    }
    
    
    // MARK: Core Data
    
    /**
        Syncs all models in the collection to their core data models.
    */
    func sync() {
        self.models.forEach {(model, index, models, exit) -> () in
            model.sync()
        }
    }
    
    
    // MARK: Collection Manipulation
    
    /**
        Add a model to the collection.  An Add event is triggered if the model is successfully added to the collection.
        The event can be silenced by passing in the Silent option.
    */
    func add(models:[Model], options:[Options]? = nil) {
        var options = options ?? [Options]()        
        var updated = false
        models.forEach {(model, index, array, exit) -> () in
            if !self.models.inArray(model) {
                self.models.append(model)
                model.collection = self
                updated = true
            }
        }
        
        if updated {
            if !options.inArray(Options.Silent) {
                self.trigger(.Add, info: ["models": models])
            }
        }
    }
    
    /**
        Insert an array of models at the specified index.
    */
    func insert(models:[Model], var atIndex:Int, options:[Options]? = nil) {
        var options   = options ?? [Options]()
        atIndex       = min(max(atIndex, 0), self.models.count)
        
        models.forEach {(model, index, array, exit) -> () in
            if self.models.inArray(model) {
                self.remove([model], options: [.Silent])
            }
            
            self.models.insert(model, atIndex: atIndex)
            atIndex++
        }
        
        if !options.inArray(Options.Silent) {
            self.trigger(.Add, info: ["models": models])
        }
    }

    
    /**
        Remove a model to the collection.  A Remove event is triggered if the model is successfully removed from the collection.
        The event can be silenced by passing in the Silent option.
    */
    func remove(models:[Model], options:[Options]? = nil) {
        var options = options ?? [Options]()
        var updated = false
        models.forEach {(model, index, array, exit) -> () in
            if self.models.inArray(model) {
                self.models.removeAtIndex(self.indexOf(model)!)
                model.collection = nil
                updated = true
            }
        }
        
        if updated {
            if !options.inArray(Options.Silent) {
                self.trigger(.Remove, info: ["models": models])
            }
        }
    }
    
    /**
        Removes all elements from the collection and adds in the passed in models, if specified.
    */
    func reset(models:[Model]? = nil, options:[Options]? = nil) {
        var options = options ?? [Options]()
        self.priorModels = self.models
        self.remove(self.models, options: $.extend(options, [.Silent]))
        
        if models != nil {
            self.add(models!, options: $.extend(options, [.Silent]))
        }
        
        if !options.inArray(Options.Silent) {
            self.trigger(.Reset, info: models != nil ? ["models": models!] : nil)
        }
    }
    
    /**
        Sets the content of the collection to the passed in models.  Triggers Remove and Add updates as models are added and removed,
        rather than at the end of the process.
    */
    func set(models:[Model], options:[Options]? = nil) {
        var options = options ?? [Options]()
        
        // Remove stale models
        for var i = self.length - 1; i >= 0; i-- {
            if !models.inArray(self.models[i]) {
                self.remove([self.models[i]], options: options)
            }
        }
        
        // Add new models
        self.add(models, options: options)
    }
    
    /**
        Returns the model with the associated ID or Client ID.
    */
    func get(id:String) -> Model? {
        return self.find({ (model, index, models) -> Bool in
            return model.get("id") as? String == id || model.get("clientId") as? String == id
        })
    }
    
    /**
        Returns the model at the specified index.
    */
    func at(index:Int) -> Model? {
        return index >= 0 && index < self.length ? self.models[index] : nil
    }
    
    /**
        Add a model to the collection.  An Add event is triggered if the model is successfully added to the collection.
        The event can be silenced by passing in the Silent option.
    */
    func push(models:[Model], options:[Options]? = nil) {
        self.add(models, options: options)
    }
    
    /**
        Removes the last model from the collection and returns it.
    */
    func pop(options:[Options]? = nil) -> Model? {
        if let model = self.models.last? {
            self.remove([model], options: options)
            return model
        }
        return nil
    }
    
    /**
        Inserts the passed in model at the first index in the collection.
    */
    func unshift(model:Model, options:[Options]? = nil) {
        var options = options ?? [Options]()
        if !self.models.inArray(model) {
            self.insert([model], atIndex: 0, options: options)
        }
    }
    
    /**
        Removes the first model and returns it.
    */
    func shift(options:[Options]? = nil) -> Model? {
        var model = self.models.first
        if model != nil {
            self.remove([model!], options: options)
        }
        return model
    }
    
    /**
        Removes and returns a copy of all the objects within the specified range
    */
    func slice(start:Int, length:Int, options: [Options]? = nil) -> [Model] {
        var retObj = [Model]()
        for i in start...(start + length - 1) {
            if let model = self.at(i) {
                retObj.append(model)
            }
            else {
                break
            }
        }
        self.remove(retObj, options: options)
        return retObj
    }
    
    /**
        Removes objects in provided range and insert models at the specified starting index.
    */
    func splice(models:[Model], start:Int, length:Int, options: [Options]? = nil) -> [Model] {
        var removed = self.slice(start, length: length, options: options)
        self.insert(models, atIndex: start, options: options)
        return removed
    }
    
    
    // MARK: RESTful Web Services
    
    /**
        Fetchs a collection of models from the server.  The returned value is always treated as a JSON object,
        that is passed into the parsing method at the collection level (to retrieve the models) and then at the model 
        level to create models and set their properties.  The ID property must be mapped in the model's parsing method.
    */
    func fetch(_ completion:SwiftlyNetworkEvent? = nil) {
        var url  = self.url
        var name = self.name ?? ""
        
        if url.length == 0 {
            NSException(name: "Invalid URL", reason: "Collection is configured without a URL", userInfo: nil).raise()
        }
        
        // Generate URL - url/name/id
        url = url.stringByAppendingPathComponent(name)
        
        // Create request
        var req = request(.GET, url)
        
        // Provide hooks for authentication
        self.authenticate(req)
        
        // Execute request and handle response
        req.responseMulti({ (request, response, responseTuple, error) -> Void in
            self.priorModels = self.models
            
            // Parse response
            var modelJSON:[JSON]? = self.parse(request, response: response, json: responseTuple.json, error: error)
            if modelJSON != nil {
                modelJSON!.forEach({(json, index, models, exit) -> () in
                    var model:Model? = nil
                    if !self.isEmpty {
                        var id = json["id"].stringValue
                        if id.length > 0 {
                            model = self.get(id)
                        }
                    }
                    
                    // Create model if one was not found by ID
                    if model == nil {
                        model = self.instanceModel()
                    }
                    
                    if error == nil {
                        model!.priorProperties = model!.properties
                    }
                    
                    // Populate model with hash
                    if let hash = model?.parse(request, response: response, json: json, error: error) {
                        // Check if values would be updated
                        var diffLen = $.diff(hash, comparison: model!.get(hash.keys())).length
                        if diffLen > 0 {
                            model!.set(hash)
                        }
                    }
                    
                    // Add model if ID is populated
                    if let id = model!.get("id") as? String {
                        if id.length > 0 {
                            self.add([model!], options: [Options.Silent])
                        }
                    }
                })
            }
            
            // Save context
            if error == nil {
                self.sync()
            }
            
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
        Returns an instance of the Model object, created in the Core Data context.
    */
    func instanceModel() -> Model {
        return NSEntityDescription.insertNewObjectForEntityForName(self.modelName, inManagedObjectContext: self.managedObjectContext) as Model
    }
    
    /**
        Creates a managed object model in the Core Data database.  The add event is triggered
        instantly, unless the Wait option is passed in.  If .Fetch is passed in as an option, the model will be fetched from the server.
        If .Save is passed in, the model will be saved to the server.
    */
    func create(properties:Hash? = nil, options: [Options]? = nil) -> Model {
        // Create model in context
        var model = self.instanceModel()
        if properties != nil {
            properties!.forEach({ (key, value, index, dictionary, exit) -> () in
                if model.managedObjectModelProperties.inArray(key) {
                    model.setValue(value, forKey: key)
                }
            })
            
            // Set properties on model
            model.set(properties!, options: options)
        }
        self.managedObjectContext.save(nil)
        
        // Creation Options
        var options    = options ?? [Options]()
        var standAlone = options.inArray(Options.StandAlone)
        var fetch      = options.inArray(Options.Fetch)
        var save       = options.inArray(Options.Save)
        
        // Early addition
        if !options.inArray(Options.Wait) && !standAlone {
            self.add([model], options: options)
        }
        
        var callback:SwiftlyNetworkEvent = {(request) in
            // Delayed addition (after response from server)
            if options.inArray(Options.Wait) && !standAlone {
                self.add([model], options: options)
            }
        }
    
        // REST Events
        if fetch { model.fetch(callback) }
        if save  { model.save(callback) }
        
        if !fetch && !save {
            if options.inArray(Options.Wait) && !standAlone {
                self.add([model], options: options)
            }
        }
        
        
        return model
    }
    
    /**
        Called from Fetch when a response is returned.  Provides a hook for digesting the returned response.  This method
        should return an array of model attributes to be passed into models to be parsed.
    
        :param: request URL Request - contains request headers and other information
        :param: response URL Response - contains response headers and other information
        :param: json - response JSON
        :param: error error that occured during request, if any
    */
    func parse(request:NSURLRequest, response:NSHTTPURLResponse?, json:JSON?, error:NSError?) -> [JSON]? { return nil; }
    
    
    /**
        Provides a hook to authenticate requests.  Refer to AlamoFire's documentation to learn more.
    */
    func authenticate(request:Request) {}
    
    
    // MARK: Array Methods
    
    final func forEach(fn:(model:Model, index:Int, models:[Model], inout exit:Bool) -> Void) {
        $.forEach(self.models, iteratee: fn)
    }
    
    final func map(fn:(model:Model, models:[Model]) -> Model) -> [Model] {
        return $.map(self.models, iteratee: fn)
    }

    final func find(predicate:(model:Model, index:Int, models:[Model]) -> Bool) -> Model? {
        return $.find(self.models, predicate: predicate)
    }
    
    final func filter(predicate:(model:Model, index:Int, models:[Model]) -> Bool) -> [Model] {
        return $.filter(self.models, predicate: predicate)
    }
    
    final func some(predicate:(model:Model, models:[Model]) -> Bool) -> Bool {
        return $.some(self.models, predicate: predicate)
    }
    
    final func every(predicate:(model:Model, models:[Model]) -> Bool) -> Bool {
        return $.every(self.models, predicate: predicate)
    }
    
    final func contains(model:Model) -> Bool {
        return self.models.inArray(model)
    }
    
    final func invoke(fn:(model:Model) -> Model) {
        $.invoke(&self.models, iteratee: fn)
    }
    
    final func sort(comparator:((modelA:Model, modelB:Model) -> Int)? = nil) -> [Model] {
        var aComparator = comparator ?? self.comparator
        if aComparator != nil {
           self.models = $.sort(self.models, comparator: aComparator!)
        }
        return self.models
    }
    
    final func pluck(key:String) -> [AnyObject?] {
        var arrProperties = [Hash]()
        self.models.forEach { (elem, index, array, exit) -> () in
            arrProperties.append(elem.properties)
        }
        return $.pluck(arrProperties, key: key)
    }
    
    final func group<R:Hashable>(fn:(model:Model) -> R?) -> [R:[Model]] {
        return $.group(self.models, iteratee: fn)
    }
    
    final func shuffle() -> [Model] {
        return $.shuffle(self.models)
    }
    
    final func first(length:Int = 1) -> [Model] {
        return $.first(self.models, length: length)
    }
    
    final func last(length:Int = 1) -> [Model] {
        return $.last(self.models, length: length)
    }
    
    final func initial(length:Int = 1) -> [Model] {
        return $.initial(self.models, length: length)
    }
    
    final func rest(index:Int = 1) -> [Model] {
        return $.rest(self.models, index: length)
    }
    
    final func without(exclude:[Model]) -> [Model] {
        return $.without(self.models, exclude:exclude)
    }
    
    final func indexOf(model:Model) -> Int? {
        return $.indexOf(self.models, elem: model)
    }
    
    final func lastIndexOf(model:Model) -> Int? {
        return $.lastIndexOf(self.models, elem: model)
    }
}


