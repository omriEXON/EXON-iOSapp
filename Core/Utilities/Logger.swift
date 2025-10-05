import Foundation

struct Logger {
    static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(fileName):\(line)] \(message)")
        #endif
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("❌ [\(fileName):\(line)] \(message)")
        #endif
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("⚠️ [\(fileName):\(line)] \(message)")
        #endif
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("ℹ️ [\(fileName):\(line)] \(message)")
        #endif
    }
}

// Global convenience functions
func devLog(_ message: String) {
    Logger.log(message)
}

func devError(_ message: String) {
    Logger.error(message)
}

func devWarn(_ message: String) {
    Logger.warning(message)
}

func devInfo(_ message: String) {
    Logger.info(message)
}
