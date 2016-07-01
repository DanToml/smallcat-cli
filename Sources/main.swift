import Commander
import Darwin.C
import AppKit

private let api = APIClient()
private let pasteboard = NSPasteboard.generalPasteboard()

private func requestWith(url: String, expiry: URLExpiry) {
    var sema = dispatch_semaphore_create(0)
    api.shortern(URL: url, expiry: expiry) { (result: Result<String, MeowErrors>) in
        switch result {
        case let .Success(url):
            print("URL: \(url)")
            pasteboard.clearContents()
            pasteboard.setString(url, forType: NSPasteboardTypeString)
            print("Copied to clipboard!")
        case let .Error(error):
            print("Error: \(error)")
            exit(1)
        }
        dispatch_semaphore_signal(sema)
    }
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER)
}

private func createCLI() -> Group {
    return Group {
        $0.command("10m") { (url: String) in
            requestWith(url, expiry: .TenMins)
        }

        $0.command("1h") { (url: String) in
            requestWith(url, expiry: .OneHour)
        }

        $0.command("1d") { (url: String) in
            requestWith(url, expiry: .OneDay)
        }

        $0.command("1w") { (url: String) in
            requestWith(url, expiry: .OneWeek)
        }
    }
}

createCLI().run()
