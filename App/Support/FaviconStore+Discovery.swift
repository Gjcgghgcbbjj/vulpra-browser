import CryptoKit
import Foundation
import SQLite3
import UIKit

extension FaviconStore {
    // MARK: - Cache Keys And URLs
    
    func imageFileURL(for imageKey: String) -> URL {
        storage.directoryURL.appendingPathComponent(Self.imageFilePrefix + imageKey, isDirectory: false)
    }
    
    func requestScopeKey(for pageURL: URL) -> String {
        faviconLookupKeys(for: pageURL).first ?? pageURL.absoluteString.lowercased()
    }
    
    func faviconLookupKeys(for pageURL: URL) -> [String] {
        guard let origin = URLUtils.httpOriginString(for: pageURL) else {
            return []
        }
        
        let pathComponents = pageURL.path.split(separator: "/").map(String.init)
        guard !pathComponents.isEmpty else {
            return [origin]
        }
        
        var keys = stride(from: pathComponents.count, through: 1, by: -1).map {
            origin + "/" + pathComponents.prefix($0).joined(separator: "/")
        }
        keys.append(origin)
        return keys
    }
    
    func faviconScopeKey(for pageURL: URL, iconURL: URL) -> String {
        guard let origin = URLUtils.httpOriginString(for: pageURL),
              let pageHost = URLUtils.normalizedHost(pageURL.host) else {
            return pageURL.absoluteString
        }
        
        guard URLUtils.normalizedHost(iconURL.host) == pageHost else {
            return origin
        }
        
        let pagePath = pageURL.path.split(separator: "/").map(String.init)
        var iconDirectory = iconURL.path.split(separator: "/").map(String.init)
        if !iconURL.path.hasSuffix("/"), !iconDirectory.isEmpty {
            iconDirectory.removeLast()
        }
        
        var sharedPath: [String] = []
        for (pageComponent, iconComponent) in zip(pagePath, iconDirectory) {
            guard pageComponent == iconComponent else {
                break
            }
            sharedPath.append(pageComponent)
        }
        return sharedPath.isEmpty ? origin : origin + "/" + sharedPath.joined(separator: "/")
    }
    
    func defaultFaviconURL(for pageURL: URL) -> URL? {
        guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }
    
    // MARK: - Networking
    
    func fetchHTMLDocument(for pageURL: URL, redirectDepth: Int) async -> HTMLDocument? {
        var request = URLRequest(url: pageURL)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        guard let (data, response) = await data(for: request),
              data.count <= Self.maxHTMLBytes else {
            return nil
        }
        
        let mimeType = (response.mimeType ?? "").lowercased()
        guard mimeType.isEmpty || mimeType.contains("html") || mimeType.contains("xml") else {
            return nil
        }
        
        let html = string(from: data, response: response)
        guard !html.isEmpty else {
            return nil
        }
        
        let finalURL = response.url ?? pageURL
        if redirectDepth < Self.maxRedirectDepth,
           let redirectURL = metaRefreshRedirectURL(in: html, baseURL: finalURL),
           redirectURL != finalURL {
            return await fetchHTMLDocument(for: redirectURL, redirectDepth: redirectDepth + 1)
        }
        
        return HTMLDocument(html: html, url: finalURL)
    }
    
    func fetchRemoteImage(from url: URL) async -> RemoteImage? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        guard let (data, response) = await data(for: request),
              data.count <= Self.maxImageBytes,
              let image = UIImage(data: data) else {
            return nil
        }
        
        return RemoteImage(image: image, data: data, url: response.url ?? url)
    }
    
    func data(for request: URLRequest) async -> (Data, URLResponse)? {
        await withCheckedContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                guard error == nil,
                      let data,
                      let response else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
    
    // MARK: - HTML Parsing
    
    func iconURLs(in html: String, baseURL: URL) -> [URL] {
        let nsHTML = html as NSString
        let matches = linkTagExpression.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        var candidates: [URL] = []
        
        for match in matches {
            let tag = nsHTML.substring(with: match.range)
            let attributes = attributes(in: tag)
            let rel = attributes["rel"]?.lowercased() ?? ""
            let href = attributes["href"] ?? ""
            
            guard !href.isEmpty,
                  rel.contains("icon"),
                  !rel.contains("mask-icon"),
                  let url = URL(string: decodeHTMLEntities(in: href), relativeTo: baseURL)?.absoluteURL else {
                continue
            }
            
            candidates.append(url)
        }
        
        return candidates
    }
    
    func attributes(in tag: String) -> [String: String] {
        let nsTag = tag as NSString
        let matches = attributeExpression.matches(in: tag, range: NSRange(location: 0, length: nsTag.length))
        var result: [String: String] = [:]
        
        for match in matches {
            guard match.numberOfRanges >= 6 else {
                continue
            }
            
            let name = nsTag.substring(with: match.range(at: 1)).lowercased()
            let value: String
            if match.range(at: 3).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 3))
            } else if match.range(at: 4).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 4))
            } else if match.range(at: 5).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 5))
            } else {
                value = ""
            }
            
            result[name] = value
        }
        
        return result
    }
    
    func metaRefreshRedirectURL(in html: String, baseURL: URL) -> URL? {
        let nsHTML = html as NSString
        let matches = metaTagExpression.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        
        for match in matches {
            let tag = nsHTML.substring(with: match.range)
            let attributes = attributes(in: tag)
            let httpEquiv = attributes["http-equiv"]?.lowercased() ?? ""
            guard httpEquiv == "refresh",
                  let content = attributes["content"] else {
                continue
            }
            
            let parts = content.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else {
                continue
            }
            
            let redirectPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard redirectPart.lowercased().hasPrefix("url=") else {
                continue
            }
            
            let value = redirectPart.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
            let unquotedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if let redirectURL = URL(string: decodeHTMLEntities(in: unquotedValue), relativeTo: baseURL)?.absoluteURL {
                return redirectURL
            }
        }
        
        return nil
    }
    
    func string(from data: Data, response: URLResponse) -> String {
        if let encodingName = response.textEncodingName,
           let encoding = String.Encoding.ianaCharacterSetName(encodingName),
           let string = String(data: data, encoding: encoding) {
            return string
        }
        
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        if let string = String(data: data, encoding: .isoLatin1) {
            return string
        }
        
        return ""
    }
    
    func decodeHTMLEntities(in string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
    
}
