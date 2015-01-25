
import UIKit

/*
    TODO: Views
    TODO: Templating
*/

// MARK: Aliases

typealias SwiftlyEvent        = (notification:NSNotification) -> ()
typealias SwiftlyNetworkEvent = (request:Request) -> Void
typealias Hash                = [String:AnyObject]
typealias Options             = Swiftly.Options

// MARK: Operator Overloads

/**
    Supports chaining expressions.  Expressions are evaluated left to right, passing in the returned value to the next expression.
    To work properly, the returned value type must be exactly equal to the next expressions parameter type and length.
*/
infix operator ~> { associativity left precedence 80 }
func ~> <T, U>(value: T, function: (T -> U)) -> U {
    return function(value)
}

/**
    Makes the Swiftly.EventListener Struct Equatable
*/
func == (left: Swiftly.EventListener, right: Swiftly.EventListener) -> Bool {
    return  (left.object === right.object) &&
            (left.listener === right.listener) &&
            (left.event == right.event)
}

func != (left: Swiftly.EventListener, right: Swiftly.EventListener) -> Bool {
    return  (left.object !== right.object) ||
            (left.listener !== right.listener) ||
            (left.event != right.event)
}



// MARK: Swiftly Class

let $ = Swiftly.sharedInstance
class Swiftly {
    /*
        Singleton instance for the Swiftly framework
    */
    class var sharedInstance:Swiftly {
        struct Static {
            static let instance:Swiftly = Swiftly()
        }
        return Static.instance
    }
    
    var version = "0.1"
    
    init() {
        for event in Event.allEntries {
            NSNotificationCenter.defaultCenter().addObserverForName(event.toString, object: nil, queue: nil, usingBlock: { (notification) -> Void in
                self.eventTriggered(event, notification: notification)
            })
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    
    // MARK: Events
    
    /**
        Array of event listeners to notify when SwiftlyEvents occur.
    */
    private var eventListeners = [EventListener]()
    
    /**
        Adds an event listener to the array of listeners if the EventListener doesn't already exist.
    */
    private func addListener(listener:EventListener) {
        if !self.eventListeners.inArray(listener) {
            self.eventListeners.append(listener)
        }
    }
    
    /**
        Callback function that controls calling all listeners callbacks.  EventListeners are recognized
        in the order that they register to hear events.
    */
    private func eventTriggered(event:Event, notification:NSNotification) {
        if notification.object != nil {
            var notifyListeners = $.filter(self.eventListeners, predicate: { (elem, index, array) -> Bool in
                var include = !(elem.event != nil && elem.event!.toString != notification.name)
                    && !(elem.object != nil && elem.object !== notification.object!)
                return include
            })
            
            // Notify listeners
            notifyListeners.forEach { (elem, index, array, exit) -> () in
                elem.callback(notification: notification)
            }
        }
    }
    
    /*
        Executes a function once after the passed in timeout in milliseconds
    
        :param: fn function to execute
        :param: timeout time to wait before execution
    */
    func setTimeout(fn:()->(), timeout:UInt) {
        var queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
        dispatch_after(UInt64(timeout), queue, { () -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                fn()
            })
        })
    }
    
    /**
        Triggers a Swiftly event on the passed in object with the passed in user information.
        
        :param: sender Hash to listen to
        :param: event Event to listen for
        :param: info Additional info to send with the notification
    */
    func trigger(sender:AnyObject, event:Event, info:[String:AnyObject]? = nil) {
        NSNotificationCenter.defaultCenter().postNotificationName(event.toString, object: sender, userInfo: info)
    }
    
    /*
        Provides a quick means of listening to Swiftly events on an object.  Called from the object wanting to received
        the callback, passing in the object and event to listen to.
        
        :param: object:Hash object to listen to
        :param: event:Event event to listen for
        :param: callback:SwiftlyEvent closure to execute when the event occurs
    */
    func listenTo(listener: AnyObject, object:AnyObject?, event:Event, callback:SwiftlyEvent) {
        self.addListener(EventListener(listener: listener, object: object, event: event, callback: callback))
    }
    
    /*
        Provides a quick means of listening to Swiftly events on an object.  Called from the object wanting to received
        the callback, passing in the object and events to listen to.
        
        :param: object:Hash object to listen to
        :param: events:[Event] events to listen for
        :param: callback:SwiftlyEvent closure to execute when one of the events occurs
    */
    func listenTo(listener: AnyObject, object:AnyObject?, events:[Event], callback:SwiftlyEvent) {
        events.forEach { (elem, index, array, exit)  in
            self.addListener(EventListener(listener: listener, object: object, event: elem, callback: callback))
        }
    }
    
    /*
        Stops listenting to the specified object and Swiftly event.
    
        :param: object Hash that was being listend to
        :param: event Event that was being listened for
    */
    func stopListening(listener:AnyObject, object:AnyObject? = nil, event:Event? = nil) {
        $.filter(self.eventListeners, predicate: { (elem, index, array) -> Bool in
            var include = true
            if listener !== elem.listener ||
                (object != nil && object !== elem.object) ||
                (event != nil && event != elem.event) {
                include = false
            }
            return include
        }).forEach { (elem, index, array, exit) -> () in
            if self.eventListeners.inArray(elem) {
                var index = $.indexOf(self.eventListeners, elem: elem)
                self.eventListeners.removeAtIndex(index!)
            }
        }
    }
    
    /**
        Listen for an event only once. After the event is triggered, the object will no longer receive notifications
        about the event.
    */
    func listenToOnce(listener: AnyObject, object:AnyObject?, event:Event, callback:SwiftlyEvent) {
        $.listenTo(listener, object: object, event: event) { (notification) -> () in
            callback(notification: notification)
            $.stopListening(listener, object: object, event: event)
        }
    }
    
    
    // MARK: Array and Dictionary Methods
    
    /*
        Fills in undefined properties in the Hash
        
        :param: object Hash object to fill in with defaults
        :param: defaults Hash object containing default values
        
        :returns: Hash object + defaults
    */
    func defaults(destination:Hash, _ defaults:Hash) -> Hash {
        var retObj = destination
        defaults.forEach {(key, value, index, dictionary, exit) -> () in
            if retObj[key] == nil {
                retObj[key] = value
            }
        }
        return retObj
    }
    
    /*
        Adds all entries from the second object to the first object.  Similar to defaults,
        but it always overwrites with the second objects values.
        
        :param: destination Hash object to add entries to
        :param: source Hash object containing entries to add to the destination object
        
        :returns: Hash destination + source
    */
    func extend(destination:Hash, _ source:Hash) -> Hash {
        var retObj = destination
        source.forEach {(key, value, index, dictionary, exit) -> () in
            retObj[key] = value
        }
        return retObj
    }
    
    func extend<T:Equatable>(destination:[T], _ source:[T]) -> [T] {
        var retObj = destination
        source.forEach { (elem, index, array, exit) -> () in
            if !retObj.inArray(elem) {
                retObj.append(elem)
            }
        }
        return retObj
    }
    
    /*
        Compares the first object against the second object and returns all properties from Hash 1 
        that don't match the property value in Hash 2
        
        :param: source Hash to compare to comparison
        :param: comparison Hash to compare against
    
        :returns: Hash all differences in source relative to comparison
    */
    func diff(source:Hash, comparison:Hash) -> Hash {
        var retObj = Hash()
        source.forEach { (key, value, index, dictionary, exit) -> () in
            if !$.equal(value, objB: comparison[key]) {
                retObj[key] = value
            }
        }
        return retObj
    }
    
    
    // MARK: Underscore Functions
    
    /**
        Iterates over an array of elements, yielding each in turn to the iteratee function.  Each iteratee function
        is called with 4 arguments: (elem:Element, index:Int, array:Array, &exit)
    */
    func forEach<T>(array:[T], iteratee:(elem:T, index:Int, array:[T], inout exit:Bool) -> Void) {
        for var i = 0; i < array.count; i++ {
            var exitLoop = false
            iteratee(elem: array[i], index: i, array: array, exit: &exitLoop)
            if exitLoop == true {
                break
            }
        }
    }
    
    /**
        Iterates over a dictionary of elements, yielding each in turn to the iteratee function.  Ech iteratee function
        is called with 5 arguments: key, value, index, dictionary, &exit
    */
    func forEach<K,V>(dictionary:[K:V], iteratee:(key:K, value:V, index:Int, dictionary:[K:V], inout exit:Bool) -> ()) {
        var idx = 0
        for (key, val) in dictionary {
            var exitLoop = false
            iteratee(key: key, value: val, index: idx, dictionary: dictionary, exit: &exitLoop)
            if exitLoop { break }
            idx++
        }
    }
    
    /**
        Returns a new array that has been generated using the iteratee function.  The iteratee function is passed in each
        element in the array sequentially.
    */
    func map<T>(array:[T], iteratee:(elem:T, array:[T]) -> T) -> [T] {
        var results = [T]()
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            results.append(iteratee(elem: elem, array:array))
        })
        return results
    }
    
    /**
        Returns a new array that has been generated using the iteratee function against the passed in dictionary.  The iteratee function is passed in each
        element in the dictionary sequentially.
    */
    func map<K, V>(obj:[K:V], iteratee:(elem:V, key:K, obj:[K:V]) -> V?) -> [V] {
        var results = [V]()
        obj.forEach { (key, value, index, dictionary, exit) -> () in
            if let value = iteratee(elem: value, key: key, obj: dictionary) {
                results.append(value)
            }
        }
        return results
    }
    
    /**
        Looks through each value in the array, returning the first one that passes the predicate's test, or nil if no objects pass.
    */
    func find<T>(array:[T], predicate:(elem:T, index:Int, array:[T]) -> Bool) -> T? {
        var matchedElem:T? = nil
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            if predicate(elem: elem, index: index, array: array) {
                exit        = true
                matchedElem = elem
            }
        })
        return matchedElem
    }
    
    /**
        Looks through each value in the array, returning an array of all elements that matched the predicate's test.
    */
    func filter<T>(array:[T], predicate:(elem:T, index:Int, array:[T]) -> Bool) -> [T] {
        var matchedElems = [T]()
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            if predicate(elem: elem, index: index, array: array) {
                matchedElems.append(elem)
            }
        })
        return matchedElems
    }
    
    /**
        Looks through each value in the array, returing an array of all elements that failed the predicates' test.
    */
    func reject<T>(array:[T], predicate:(elem:T) -> Bool) -> [T] {
        var failedElems = [T]()
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            if !predicate(elem: elem) {
                failedElems.append(elem)
            }
        })
        return failedElems
    }
    
    /**
        Looks through each value in the array, and checks if it passes the predicate's test.  If all values passed, the 
        function returns true, otherwise the function returns false.
    */
    func every<T>(array:[T], predicate:(elem:T, array:[T]) -> Bool) -> Bool {
        var passed = true
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            if !predicate(elem: elem, array: array) {
                passed = false
                exit   = true
            }
        })
        return passed
    }
    
    /**
        Returns true if atleast one element in the array passes the predicates test.
    */
    func some<T>(array:[T], predicate:(elem:T, array:[T]) -> Bool) -> Bool {
        var passed = false
        $.forEach(array, iteratee: { (elem, index, array, exit) -> Void in
            if predicate(elem: elem, array: array) {
                passed = true
                exit   = true
            }
        })
        return passed
    }
    
    /**
        Manipulates the array's values directly.  Invokes the iteratee function on each array element.
    */
    func invoke<T>(inout array:[T], iteratee:(elem:T) -> T) {
        $.forEach(array, iteratee: {(elem, index, arr, exit) -> Void in
            array[index] = iteratee(elem: elem)
        })
    }
    
    /**
        Returns a sorted version of the passed in array.  The comparator is called, and should return a value
        of less than 0, 0 or greater than 0 to indiciate sort order.  A value < 0 indicates A comes before B,
        a value of 0 means both elements are equal, and a value of > 0 indicates A comes after B.
    */
    func sort<T>(array:[T], comparator:(elemA:T, elemB:T) -> Int) -> [T] {
        var sortedArray = [T]()
        array.forEach { (elem, index, array, exit) -> () in
            if index == 0 {
                sortedArray.append(elem)
            }
            else {
                var idx     = 0
                var order   = comparator(elemA: elem, elemB: sortedArray[idx])
                while order > 0 && ++idx < sortedArray.length {
                    order = comparator(elemA: elem, elemB: sortedArray[idx])
                }
                sortedArray.insert(elem, atIndex: idx)
            }
        }
        return sortedArray
    }

    /**
        Extracts an array of property values for the passed in key from an array of dictionaries
    */
    func pluck<K,V>(objects:[[K:V]], key:K) -> [V] {
        var plucked  = [V]()
        objects.forEach { (elem, index, array, exit) -> () in
            if let prop = $.property(key)(elem) {
                plucked.append(prop)
            }
        }
        return plucked
    }
    
    /**
        Groups elements in the passed in array based on the result of the iteratee function.
    */
    func group<T, R:Hashable>(objects:[T], iteratee:(elem:T) -> R?) -> [R:[T]] {
        var groups = [R:[T]]()
        objects.forEach {(elem, index, array, exit) -> () in
            if let groupId = iteratee(elem: elem) {
                if groups[groupId] != nil {
                    groups[groupId]!.append(elem)
                }
                else {
                    groups[groupId] = [elem]
                }
            }
        }
        return groups
    }
    
    /**
        Shuffles the passed in array in a random order using the Fisher-Yates method.
    */
    func shuffle<T>(array:[T]) -> [T] {
        var shuffled = array
        for var i = 0, rand:Int; i < array.length; i++ {
            rand = $.random(0, end: i)
            if rand != i {
                shuffled[i] = shuffled[rand]
            }
            shuffled[rand] = array[i]
        }
        return shuffled
    }
    
    /**
        Returns the first element(s) up to the length parameter.
    */
    func first<T>(array:[T], length:Int = 1) -> [T] {
        var elems = [T]()
        for var i = 0; i < length && i < array.length; i++ {
            elems.append(array[i])
        }
        return elems
    }
    
    /**
        Returns the last element of the array, or last n elements if a length if specified
    */
    func last<T>(array:[T], length:Int = 1) -> [T] {
        var elems = [T]()
        for var i = array.length - 1; i >= 0 && elems.length < length; i-- {
            elems.insert(array[i], atIndex: 0)
        }
        return elems
    }
    
    /**
        Returns everything but the last element in the array.  If a length property is populated, all but the last x elements are returned.
    */
    func initial<T>(array:[T], length:Int = 1) -> [T] {
        var elems = [T]()
        for var i = 0; i < array.length - length; i++ {
            elems.append(array[i])
        }
        return elems
    }
    
    /**
        Returns all elements from the specified index to the end of the array.
    */
    func rest<T>(array:[T], index:Int = 0) -> [T] {
        var elems = [T]()
        for var i = index; i < array.length; i++ {
            elems.append(array[i])
        }
        return elems
    }
    
    /**
        Returns all elements from the first array that don't exist in the exclude array.
    */
    func without<T:Equatable>(array:[T], exclude:[T]) -> [T] {
        var elems = [T]()
        array.forEach { (elem, index, array, exit) -> () in
            if !exclude.inArray(elem) {
                elems.append(elem)
            }
        }
        return elems
    }
    
    /**
        Returns the index of the specified element in the array, or nil of not found.
    */
    func indexOf<T:Equatable>(array:[T], elem:T) -> Int? {
        var index:Int? = nil
        array.forEach { (aElem, idx, array, exit) -> () in
            if elem == aElem {
                index = idx
                exit  = true
            }
        }
        return index
    }
    
    /**
        Returns the last index of the specified element in the array, or nil if not found.
    */
    func lastIndexOf<T:Equatable>(array:[T], elem:T) -> Int? {
        var index:Int? = nil
        for var i = array.length - 1; i >= 0; i-- {
            if elem == array[i] {
                return i
            }
        }
        return nil
    }
    
    /**
        Returns a curried function that accepts an object and returns the value of the specified curried key.
    */
    func property<K, V>(key:K) -> ([K:V]) -> V? {
        return {(object:[K:V]) -> V? in
            return object[key]
        }
    }
    
    /**
        Generates a random integer between the start and end value, inclusive.
    */
    func random(start:Int, end:Int) -> Int {
        return Int(arc4random_uniform(UInt32(end))) + start
    }
    
    /**
        Returns an array of key's from a dictionary object.
    */
    func keys<K,V>(dict:[K:V]) -> [K] {
        var allKeys = [K]()
        dict.forEach { (key, value, index, dictionary, exit) -> () in
            allKeys.append(key)
        }
        return allKeys
    }
    
    /**
        Checks to see if two AnyObjects are equal to each other.
    */
    func equal(objA:AnyObject?, objB:AnyObject?) -> Bool {
        // Attemp to convert objects to NSObjects
        if let nsObjA = objA as? NSObject {
            return nsObjA.isEqual(objB)
        }
        else if let nsObjB = objB as? NSObject {
            return nsObjB.isEqual(objA)
        }
        else {
            // Check if identical
            return $.identical(objA, objB: objB)
        }
    }
    
    /**
        Checks if two AnyObject's are identical to each other.
    */
    func identical(objA:AnyObject?, objB:AnyObject?) -> Bool {
        return objA === objB
    }
    
    func chain<T>(object:T, function:((object:T)->Any?)...) -> T {
        function.forEach {(fn, index, array, exit) -> () in
            var obj = fn(object: object)
        }
        return object
    }
    
    // MARK: Enumerations
    
    enum Event:Int {
        case Change = 0, Save, Delete, Fetch, Add, Remove, Reset
        
        var toString:String {
            switch self {
            case .Change:   return "kEventChange"
            case .Save:     return "kEventSave"
            case .Delete:   return "kEventDelete"
            case .Fetch:    return "kEventFetch"
            case .Add:      return "kSwiftlyCollectionEventAdd"
            case .Remove:   return "kSwiftlyCollectionEventRemove"
            case .Reset:    return "kSwiftlyCollectionEventReset"
            }
        }
        
        static var allEntries:[Event] {
            return [.Change, .Save, .Delete, .Fetch, .Add, .Remove, .Reset]
        }
    }
    
    enum Options:Int {
        case Difference = 0, Silent, Wait, StandAlone, Fetch, Save
        
        static var allEntries:[Options] {
            return [.Difference, .Silent, .Wait, .StandAlone, .Fetch, .Save]
        }
    }
    
    
    // MARK: Structs
    
    struct EventListener: Equatable {
        var listener:AnyObject
        var object:AnyObject?
        var event:Swiftly.Event?
        var callback:SwiftlyEvent
        
        init(listener:AnyObject, object:AnyObject?, event:Swiftly.Event?, callback:SwiftlyEvent) {
            self.listener = listener
            self.object   = object
            self.event    = event
            self.callback = callback
        }
    }
}

// MARK: Extensions

extension NSObject {
    /*
        Provides a quick means of listening to Swiftly events on an object.  Called from the object wanting to received
        the callback, passing in the object and event to listen to.
        
        :param: object:Hash object to listen to
        :param: event:Event event to listen for
        :param: callback:SwiftlyEvent closure to execute when the event occurs
    */
    func listenTo(object:AnyObject?, event:Swiftly.Event, callback:SwiftlyEvent) {
        $.listenTo(self, object: object, event: event, callback: callback)
    }
    
    /*
        Provides a quick means of listening to Swiftly events on an object.  Called from the object wanting to received
        the callback, passing in the object and events to listen to.
        
        :param: object:Hash object to listen to
        :param: events:[Event] events to listen for
        :param: callback:SwiftlyEvent closure to execute when one of the events occurs
    */
    func listenTo(object:AnyObject?, events:[Swiftly.Event], callback:SwiftlyEvent) {
        $.listenTo(self, object: object, events: events, callback: callback)
    }
    
    /*
        Stops listenting to the specified object and Swiftly event.
        
        :param: object Hash that was being listend to
        :param: event Event that was being listened for
    */
    func stopListening(object:AnyObject? = nil, event:Swiftly.Event? = nil) {
       $.stopListening(self, object: object, event: event)
    }
    
    /**
        Listens for an event once then immediately removes itself as a listener.
    
        :param: object:Hash object to listen to
        :param: event:Event event to listen for
        :param: callback:SwiftlyEvent closure to execute when one of the events occurs
    */
    func listenToOnce(object:AnyObject? = nil, event:Swiftly.Event, callback:SwiftlyEvent) {
        $.listenToOnce(self, object: object, event: event, callback: callback)
    }
}


// MARK: Extensions

extension Dictionary {
    var length:Int {
        return self.count
    }
    
    func forEach(fn:(key:Key, value:Value, index:Int, dictionary:Dictionary, inout exit:Bool) -> ()) {
        return $.forEach(self, iteratee: fn)
    }
    
    func keys() -> [Key] {
        return $.keys(self)
    }
}

extension Array {
    var length:Int {
        return self.count
    }
    
    func forEach(fn:(elem:T, index:Int, array:Array, inout exit:Bool) -> ()) {
        return $.forEach(self, iteratee: fn)
    }
    
    func inArray<T:Equatable>(elem:T) -> Bool {
        let filtered = self.filter({$0 as? T == elem})
        return filtered.count > 0
    }
}

extension String {
    var length:Int {
        return countElements(self)
    }
}
