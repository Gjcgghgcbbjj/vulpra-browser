//
//  FaviconStore.swift
//  Vulpra
//
//  Ported from the upstream proven baseline.
//

import CryptoKit
import Foundation
import SQLite3
import UIKit

final class FaviconStore {
    static let shared = FaviconStore()
    
    static let expirationDays = 30
    static let databaseName = "Favicons"
    static let imageFilePrefix = "img-"
    static let maxHTMLBytes = 768 * 1024
    static let maxImageBytes = 2 * 1024 * 1024
    static let maxRedirectDepth = 3
    
    struct StorageURLs {
        let directoryURL: URL
        let databaseURL: URL
    }
    
    struct SiteAssociation {
        let scopeKey: String
        let imageKey: String
    }
    
    struct HTMLDocument {
        let html: String
        let url: URL
    }
    
    struct RemoteImage {
        let image: UIImage
        let data: Data
        let url: URL
    }
    
    let fileManager: FileManager
    let storage: StorageURLs
    let stateQueue = DispatchQueue(label: "com.vulpra.browser.FaviconStore.Queue", qos: .utility)
    var database: OpaquePointer?
    let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()
    
    lazy var linkTagExpression = try! NSRegularExpression(
        pattern: "(?is)<link\\b[^>]*>",
        options: []
    )
    lazy var metaTagExpression = try! NSRegularExpression(
        pattern: "(?is)<meta\\b[^>]*>",
        options: []
    )
    lazy var attributeExpression = try! NSRegularExpression(
        pattern: "(?is)([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
        options: []
    )
    
    var activeRequests: [String: Task<UIImage?, Never>] = [:]
    
    // MARK: - Lifecycle
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        
        let directoryURL = applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("Favicons", isDirectory: true)
        
        self.storage = StorageURLs(
            directoryURL: directoryURL,
            databaseURL: directoryURL.appendingPathComponent(Self.databaseName, isDirectory: false)
        )
        
        stateQueue.sync {
            prepareStorageLocked()
            openDatabaseLocked()
            configureDatabaseLocked()
            createSchemaLocked()
            pruneExpiredEntriesLocked(now: Date())
        }
    }
    
    deinit {
        stateQueue.sync {
            guard let database else {
                return
            }
            
            sqlite3_close(database)
            self.database = nil
        }
    }
    
    // MARK: - Favicons
    
    func cachedFavicon(for pageURL: URL) -> UIImage? {
        stateQueue.sync {
            cachedImageLocked(for: pageURL, now: Date())
        }
    }
    
    func favicon(for pageURL: URL) async -> UIImage? {
        guard URLUtils.isWebURL(pageURL) else {
            return nil
        }
        
        if let cachedImage = cachedFavicon(for: pageURL) {
            return cachedImage
        }
        
        let requestKey = requestScopeKey(for: pageURL)
        if let activeRequest = stateQueue.sync(execute: { activeRequests[requestKey] }) {
            return await activeRequest.value
        }
        
        let task = Task<UIImage?, Never>(priority: .utility) { [weak self] in
            guard let self else {
                return nil
            }
            
            let image = await self.fetchAndCacheFavicon(for: pageURL)
            self.stateQueue.async {
                self.activeRequests[requestKey] = nil
            }
            return image
        }
        
        stateQueue.sync {
            activeRequests[requestKey] = task
        }
        return await task.value
    }
    
    func clearCache() {
        stateQueue.async {
            self.activeRequests.values.forEach { $0.cancel() }
            self.activeRequests.removeAll()
            
            let imageKeys = self.fetchImageKeysLocked()
            _ = self.executeLocked(
                """
                DELETE FROM favicon_associations;
                DELETE FROM favicon_sources;
                DELETE FROM favicon_images;
                """
            )
            
            for imageKey in imageKeys {
                let imageURL = self.imageFileURL(for: imageKey)
                if self.fileManager.fileExists(atPath: imageURL.path) {
                    try? self.fileManager.removeItem(at: imageURL)
                }
            }
        }
    }
    
}
