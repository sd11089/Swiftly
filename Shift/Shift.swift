
import UIKit

typealias ShiftEvent        = (notification:NSNotification) -> ()
typealias ShiftNetworkEvent = (request:Request) -> Void
typealias Object            = [String:AnyObject]

enum ShiftEventType:Int {
    case Change = 0, Save, Delete, Fetch
    
    var toString:String {
        switch self {
        case .Change:   return "kShiftEventTypeChange"
        case .Save:     return "kShiftEventTypeSave"
        case .Delete:   return "kShiftEventTypeDelete"
        case .Fetch:    return "kShiftEventTypeFetch"
        }
    }
}

enum ShiftSyncType:Int {
    case Create = 0, Read, Update, Delete
    var ConvertToAF:Method {
        return [
            .Create: .POST,
            .Read:   .GET,
            .Update: .PUT,
            .Delete: .DELETE
            ][self]!
    }
}

enum ShiftModelSaveOptions:Int {
    case Difference = 0
}

enum ShiftModelUpdateOptions:Int {
    case Silent = 0
}

let $ = Shift.sharedInstance
class Shift {
    /*
        Singleton instance for the Shift framework
    */
    class var sharedInstance:Shift {
        struct Static {
            static let instance:Shift = Shift()
        }
        return Static.instance
    }
    
    var version = "0.1"
    var timers  = [NSTimer]()
    
    // MARK: Helper Methods
    
    /*
        Fills in undefined properties in the Object
        
        :param: object Object object to fill in with defaults
        :param: defaults Object object containing default values
        
        :returns: Object object + defaults
    */
    func defaults(destination:Object, _ defaults:Object) -> Object {
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
        
        :param: destination Object object to add entries to
        :param: source Object object containing entries to add to the destination object
        
        :returns: Object destination + source
    */
    func extend(destination:Object, _ source:Object) -> Object {
        var retObj = destination
        source.forEach {(key, value, index, dictionary, exit) -> () in
            retObj[key] = value
        }
        return retObj
    }
    
    func extend<T:Equatable>(destination:[T], _ source:[T]) -> [T] {
        var retObj = destination
        source.forEach { (elem, index, array, exit) -> () in
            if !retObj.contains(elem) {
                retObj.append(elem)
            }
        }
        return retObj
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
    
    /*
        Compares the first object against the second object and returns all properties from Object 1 
        that don't match the property value in Object 2
        
        :param: source Object to compare to comparison
        :param: comparison Object to compare against
    
        :returns: Object all differences in source relative to comparison
    */
    func diff(source:Object, comparison:Object) -> Object {
        var retObj = Object()
        source.forEach { (key, value, index, dictionary, exit) -> () in
            if value !== comparison[key] {
                retObj[key] = value
            }
        }
        return retObj
    }
}

// MARK: Extensions

extension NSObject {
    /*
        Provides a quick means of listening to Shift events on an object.  Called from the object wanting to received
        the callback, passing in the object and event to listen to.
        
        :param: object:Object object to listen to
        :param: event:ShiftEventType event to listen for
        :param: callback:ShiftEvent closure to execute when the event occurs
    */
    func listenTo(object:AnyObject?, event:ShiftEventType, callback:ShiftEvent) {
        NSNotificationCenter.defaultCenter().addObserverForName(event.toString, object: object, queue: nil) { (notification) -> Void in
            callback(notification:notification)
        }
    }
    
    /*
        Provides a quick means of listening to Shift events on an object.  Called from the object wanting to received
        the callback, passing in the object and events to listen to.
        
        :param: object:Object object to listen to
        :param: events:[ShiftEventType] events to listen for
        :param: callback:ShiftEvent closure to execute when one of the events occurs
    */
    func listenTo(object:AnyObject?, events:[ShiftEventType], callback:ShiftEvent) {
        events.forEach { (elem, index, array, exit)  in
            var event = elem as ShiftEventType
            NSNotificationCenter.defaultCenter().addObserverForName(event.toString, object: object, queue: nil) { (notification) -> Void in
                callback(notification:notification)
            }
        }
    }
    
    /*
        Stops listenting to the specified object and Shift event.
        
        :param: object Object that was being listend to
        :param: event Event that was being listened for
    */
    func stopListening(object:AnyObject? = nil, event:ShiftEventType? = nil) {
        var eventName:String? = event != nil ? event!.toString : nil
        NSNotificationCenter.defaultCenter().removeObserver(self, name: eventName, object: object)
    }
}


// MARK: Array Extensions

extension Dictionary {
    func forEach(fn:(key:Key, value:Value, index:Int, dictionary:Dictionary, inout exit:Bool) -> ()) {
        var idx = 0
        for (key, val) in self {
            var exitLoop = false
            fn(key: key, value: val, index: idx, dictionary: self, exit: &exitLoop)
            if exitLoop { break }
            idx++
        }
    }
    
    var length:Int {
        return self.count
    }
}

extension Array {
    func forEach(fn:(elem:T, index:Int, array:Array, inout exit:Bool) -> ()) {
        for var i = 0; i < self.count; i++ {
            var exitLoop = false
            fn(elem: self[i], index: i, array: self, exit: &exitLoop)
            if exitLoop == true {
                break
            }
        }
    }
    
    func contains<T:Equatable>(elem:T) -> Bool {
        let filtered = self.filter({$0 as? T == elem})
        return filtered.count > 0
    }
    
    var length:Int {
        return self.count
    }
}

extension String {
    var length:Int {
        return countElements(self)
    }
}

