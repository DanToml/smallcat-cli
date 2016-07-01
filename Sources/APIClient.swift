import Foundation

enum Result<T, E: ErrorType> {
    case Success(T)
    case Error(E)
}

enum MeowErrors: ErrorType {
    case InvalidResponse
    case UnableToFindToken
}

enum URLExpiry: Int {
    case TenMins = 10
    case OneHour = 60
    case OneDay  = 1440
    case OneWeek = 10080
}

typealias AuthenticityToken = String

final class APIClient {
    private let baseURL = NSURL(string: "https://small.cat")
    private let session = NSURLSession.sharedSession()

    func fetchAuthenticityToken(completion: Result<AuthenticityToken, MeowErrors> -> ()) {
        session.dataTaskWithURL(baseURL) { data, response, error in
            guard let data = data, text = String(data: data, encoding: NSUTF8StringEncoding) else {
                completion(.Error(MeowErrors.InvalidResponse))
                return
            }

            guard let authenticityToken = parseAuthenticityTokenFromHTML(text) else {
                completion(.Error(MeowErrors.UnableToFindToken))
                return
            }

            completion(.Success(authenticityToken))
        }.resume()
    }

    func submitURL(url: String, expiry: URLExpiry, token: AuthenticityToken, completion: Result<String, MeowErrors> -> ()) {
        let postBody = "utf8=%E2%9C%93&authenticity_token=\(token)&entry%5Bvalue%5D=\(url)&entry%5Bduration_in_minutes%5D=\(expiry.rawValue)".dataUsingEncoding(NSUTF8StringEncoding)
        let urlRequest = NSMutableURLRequest(URL: NSURL(string: "http://small.cat/entries")!)
        urlRequest.HTTPMethod = "POST"
        urlRequest.HTTPBody = postBody

        session.dataTaskWithRequest(urlRequest) { data, response, error in
            guard let response = response as? NSHTTPURLResponse,
            destination = response.URL
            else {
                completion(.Error(MeowErrors.InvalidResponse))
                return
            }

            self.session.dataTaskWithURL(destination) { data, response, error in
                guard let data = data,
                text = String(data: data, encoding: NSUTF8StringEncoding),
                urlString = parseSmallCatURLFromHTML(text)
                else {
                    completion(.Error(MeowErrors.InvalidResponse))
                    return
                }

                completion(.Success(urlString))
            }.resume()
        }.resume()
    }

    func shortern(URL url: String, expiry: URLExpiry, completion: (Result<String, MeowErrors>) -> ()) {
        fetchAuthenticityToken {
            switch $0 {
            case let .Success(token):
                self.submitURL(url, expiry: expiry, token: token, completion: completion)
            case let .Error(error):
                completion(.Error(error))
            }
        }
    }
}


private func parseAuthenticityTokenFromHTML(html: String) -> String? {
    let regex = try! NSRegularExpression(pattern: "<input name=\"authenticity_token\" type=\"hidden\" value=\"([^\"]*?)\" />", options: [])

    guard let match = regex.firstMatchInString(html, options: [], range: NSRange(location: 0, length: html.characters.count)) else {
        return nil
    }
    guard match.numberOfRanges >= 2 else { return nil }

    return (html as NSString).substringWithRange(match.rangeAtIndex(1))
}

private func parseSmallCatURLFromHTML(html: String) -> String? {
    let regex = try! NSRegularExpression(pattern: "<h2>Your Small.Cat link is:</h2>\n\n  <a href=\"([^\"]*?)\" rel=\"nofollow\" class=\"smallcat\">", options: [])

    guard let match = regex.firstMatchInString(html, options: [], range: NSRange(location: 0, length: html.characters.count)) else {
        return nil
    }
    guard match.numberOfRanges >= 2 else { return nil }

    return (html as NSString).substringWithRange(match.rangeAtIndex(1))
}
