
import UIKit

class Debug {
    
    // MARK: Class Level Methods
    
    /**
     *  Returns a singleton instance of the Debug object
     *  :returns: Debug Singleton Instance
     */
    class var sharedInstance:Debug {
        struct Static {
            static let instance:Debug = Debug()
        }
        return Static.instance
    }
    
    /**
     *  Logs a message to the console with a timestamp if the log level is less than or greater than the
     *  log level defined in Config.plist.
     *  5: DEBUG
     *  4: INFO
     *  3: NOTIFY
     *  2: WARNING
     *  1: ERROR
     *  0: CRITICAL
     *
     *  :param: DebugLevel Level indiciating when to print the message
     *  :param: String... Message to print to the console with any params that need to replace %s in the message
     *
     */
    func log(level:DebugLevel, message:AnyObject?...) {
        var dict:NSDictionary? = nil
        if let path   = NSBundle.mainBundle().pathForResource("Info", ofType: "plist") {
            dict = NSDictionary(contentsOfFile: path)
        }
        
        if message.count == 0 || !(message[0] is String) {
            return
        }
        
        if let strMessage = message[0] as? String {
            var mutableMessage:NSMutableString? = NSMutableString(string: strMessage)
            for var i_param = 1; i_param < message.count; i_param++ {
                var param = "\(message[i_param]!)"
                let regExp = NSRegularExpression(pattern: "%s", options: NSRegularExpressionOptions.CaseInsensitive, error: nil)!
                let rangeToReplace = regExp.rangeOfFirstMatchInString(mutableMessage!, options: nil, range: NSMakeRange(0, mutableMessage!.length))
                if rangeToReplace.location != NSNotFound {
                    mutableMessage!.replaceCharactersInRange(rangeToReplace, withString: param)
                }
            }
            
            var debugLevel = dict?["Debug.level"] as? Int ?? 5
            if level.rawValue <= debugLevel {
                let timeStampLength:Int = 30
                let timeStampFormat:NSDateFormatter = NSDateFormatter()
                timeStampFormat.dateFormat = "MM/dd/yyyy HH:mm:ss"
                var fullTimestamp:String = "\(timeStampFormat.stringFromDate(NSDate())) [\(level.toString)]"
                for _ in countElements(fullTimestamp)...timeStampLength {
                    fullTimestamp += " "
                }
                
                println("\(fullTimestamp)-   \(mutableMessage!)")
            }
        }
    }
    
    required init() {}
    
    // MARK: Nested Enumerations
    
    enum DebugLevel: Int {
        case Critical = 0, Error, Warning, Notify, Info, Debug
        
        var toString: String {
            switch self {
            case .Critical:
                return "CRITICAL"
            case .Error:
                return "ERROR"
            case .Warning:
                return "WARNING"
            case .Notify:
                return "NOTIFY"
            case .Info:
                return "INFO"
            case .Debug:
                return "DEBUG"
            default:
                return "UNKNOWN"
            }
        }
    }
}
var debug = Debug.sharedInstance
