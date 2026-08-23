import CryptoKit
import Foundation
import SQLite3
import UIKit

extension FaviconStore {
    // MARK: - Storage
    
    func prepareStorageLocked() {
        try? fileManager.createDirectory(at: storage.directoryURL, withIntermediateDirectories: true)
    }
    
    func openDatabaseLocked() {
        guard database == nil else {
            return
        }
        
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(storage.databaseURL.path, &database, flags, nil) == SQLITE_OK else {
            if let database {
                sqlite3_close(database)
            }
            assertionFailure("Failed to open Favicons database")
            return
        }
        
        self.database = database
    }
    
    func configureDatabaseLocked() {
        guard database != nil else {
            return
        }
        
        _ = executeLocked("PRAGMA foreign_keys = ON;")
        _ = executeLocked("PRAGMA journal_mode = WAL;")
        _ = executeLocked("PRAGMA synchronous = NORMAL;")
        _ = executeLocked("PRAGMA temp_store = MEMORY;")
        sqlite3_busy_timeout(database, 2_500)
    }
    
    func createSchemaLocked() {
        let sql = """
        CREATE TABLE IF NOT EXISTS favicon_images (
            image_key TEXT PRIMARY KEY,
            updated_at REAL NOT NULL
        );
        
        CREATE TABLE IF NOT EXISTS favicon_sources (
            source_url TEXT PRIMARY KEY,
            image_key TEXT NOT NULL REFERENCES favicon_images(image_key) ON DELETE CASCADE
        );
        
        CREATE TABLE IF NOT EXISTS favicon_associations (
            scope_key TEXT PRIMARY KEY,
            image_key TEXT NOT NULL REFERENCES favicon_images(image_key) ON DELETE CASCADE,
            icon_url TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        
        CREATE INDEX IF NOT EXISTS idx_favicon_images_updated_at ON favicon_images(updated_at);
        CREATE INDEX IF NOT EXISTS idx_favicon_sources_image_key ON favicon_sources(image_key);
        CREATE INDEX IF NOT EXISTS idx_favicon_associations_image_key ON favicon_associations(image_key);
        CREATE INDEX IF NOT EXISTS idx_favicon_associations_updated_at ON favicon_associations(updated_at);
        """
        
        _ = executeLocked(sql)
    }
    
    // MARK: - Cache Lookup
    
    func cachedImageLocked(for pageURL: URL, now: Date) -> UIImage? {
        pruneExpiredEntriesLocked(now: now)
        
        guard let association = lookupAssociationLocked(for: pageURL),
              let image = loadImageLocked(for: association.imageKey) else {
            return nil
        }
        
        _ = updateTimestampsLocked(scopeKey: association.scopeKey, imageKey: association.imageKey, now: now)
        return image
    }
    
    func fetchAndCacheFavicon(for pageURL: URL) async -> UIImage? {
        var candidates: [URL] = []
        
        if let document = await fetchHTMLDocument(for: pageURL, redirectDepth: 0) {
            candidates.append(contentsOf: iconURLs(in: document.html, baseURL: document.url))
        }
        
        if let fallbackURL = defaultFaviconURL(for: pageURL) {
            candidates.append(fallbackURL)
        }
        
        var seenCandidateURLs = Set<String>()
        for candidateURL in candidates {
            guard !Task.isCancelled else {
                return nil
            }
            
            let normalizedCandidateURL = candidateURL.absoluteString.lowercased()
            guard seenCandidateURLs.insert(normalizedCandidateURL).inserted else {
                continue
            }
            
            if let cachedImage = associateExistingIconIfPresent(candidateURL, with: pageURL) {
                return cachedImage
            }
            
            guard let remoteImage = await fetchRemoteImage(from: candidateURL) else {
                continue
            }
            
            stateQueue.sync {
                storeLocked(remoteImage: remoteImage, for: pageURL, now: Date())
            }
            return remoteImage.image
        }
        
        return nil
    }
    
    func associateExistingIconIfPresent(_ iconURL: URL, with pageURL: URL) -> UIImage? {
        stateQueue.sync {
            let now = Date()
            pruneExpiredEntriesLocked(now: now)
            
            guard let imageKey = imageKeyLocked(forSourceURL: iconURL.absoluteString),
                  let image = loadImageLocked(for: imageKey) else {
                return nil
            }
            
            let scopeKey = faviconScopeKey(for: pageURL, iconURL: iconURL)
            guard upsertAssociationLocked(scopeKey: scopeKey, imageKey: imageKey, iconURL: iconURL.absoluteString, now: now),
                  updateImageTimestampLocked(imageKey: imageKey, now: now) else {
                return nil
            }
            
            return image
        }
    }
    
}
