
import UIKit

class SwiftlyTestCollection: Collection {
   
    override func extend() {
        self.modelName = "SwiftlyTestModel"
        self.url       = "http://jsonplaceholder.typicode.com"
        self.name      = "posts"
    }
    
    override func parse(request: NSURLRequest, response: NSHTTPURLResponse?, json: JSON?, error: NSError?) -> [JSON]? {
        switch request.HTTPMethod! {
        case "GET":
            return json?.array
        default:
            println("Unhandled HTTP Method")
        }
        
        return nil
    }
}
