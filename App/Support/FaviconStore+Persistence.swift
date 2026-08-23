import CryptoKit
import Foundation
import SQLite3
import UIKit

extension FaviconStore {
    // MARK: - Cache Persistence
    
    func storeLocked(remoteImage: RemoteImage, for pageURL: URL, now: Date) {
        let imageKey = Self.sha256(remoteImage.data)
        let imageURL = imageFileURL(for: imageKey)
        
        if !fileManager.fileExists(atPath: imageURL.path) {
            try? remoteImage.data.write(to: imageURL, options: .atomic)
        }
        
        let scopeKey = faviconScopeKey(for: pageURL, iconURL: remoteImage.url)
        guard executeLocked("BEGIN IMMEDIATE TRANSACTION;") else {
            return
        }
        
        guard upsertImageLocked(imageKey: imageKey, now: now),
              upsertSourceURLLocked(remoteImage.url.absoluteString, imageKey: imageKey),
              upsertAssociationLocked(scopeKey: scopeKey, imageKey: imageKey, iconURL: remoteImage.url.absoluteString, now: now) else {
            _ = executeLocked("ROLLBACK TRANSACTION;")
            return
        }
        
        guard executeLocked("COMMIT TRANSACTION;") else {
            _ = executeLocked("ROLLBACK TRANSACTION;")
            return
        }
    }
    
    // MARK: - Cache Maintenance
    
    func pruneExpiredEntriesLocked(now: Date) {
        let imageKeysBeforePruning = Set(fetchImageKeysLocked())
        let startOfToday = Calendar.current.startOfDay(for: now)
        let cutoff = (Calendar.current.date(byAdding: .day, value: 1 - Self.expirationDays, to: startOfToday) ?? startOfToday).timeIntervalSince1970
        
        _ = deleteExpiredAssociationsLocked(cutoff: cutoff)
        _ = deleteExpiredImagesLocked(cutoff: cutoff)
        _ = executeLocked(
            """
            DELETE FROM favicon_images
            WHERE image_key NOT IN (
                SELECT image_key
                FROM favicon_associations
            );
            """
        )
        
        let imageKeysAfterPruning = Set(fetchImageKeysLocked())
        for imageKey in imageKeysBeforePruning where !imageKeysAfterPruning.contains(imageKey) {
            let imageURL = imageFileURL(for: imageKey)
            if fileManager.fileExists(atPath: imageURL.path) {
                try? fileManager.removeItem(at: imageURL)
            }
        }
    }
    
    func lookupAssociationLocked(for pageURL: URL) -> SiteAssociation? {
        for lookupKey in faviconLookupKeys(for: pageURL) {
            if let association = associationLocked(scopeKey: lookupKey) {
                return association
            }
        }
        return nil
    }
    
    func associationLocked(scopeKey: String) -> SiteAssociation? {
        guard let statement = prepareStatementLocked(
            """
            SELECT scope_key, image_key
            FROM favicon_associations
            WHERE scope_key = ?
            LIMIT 1;
            """
        ) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(scopeKey, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        return SiteAssociation(
            scopeKey: string(from: statement, at: 0),
            imageKey: string(from: statement, at: 1)
        )
    }
    
    func imageKeyLocked(forSourceURL sourceURL: String) -> String? {
        guard let statement = prepareStatementLocked(
            """
            SELECT image_key
            FROM favicon_sources
            WHERE source_url = ?
            LIMIT 1;
            """
        ) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(sourceURL, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        return string(from: statement, at: 0)
    }
    
    func loadImageLocked(for imageKey: String) -> UIImage? {
        let imageURL = imageFileURL(for: imageKey)
        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            removeImageLocked(imageKey)
            return nil
        }
        return image
    }
    
    func removeImageLocked(_ imageKey: String) {
        guard let statement = prepareStatementLocked(
            "DELETE FROM favicon_images WHERE image_key = ?;"
        ) else {
            let imageURL = imageFileURL(for: imageKey)
            if fileManager.fileExists(atPath: imageURL.path) {
                try? fileManager.removeItem(at: imageURL)
            }
            return
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(imageKey, to: statement, at: 1)
        _ = sqlite3_step(statement)
        
        let imageURL = imageFileURL(for: imageKey)
        if fileManager.fileExists(atPath: imageURL.path) {
            try? fileManager.removeItem(at: imageURL)
        }
    }
    
    func upsertImageLocked(imageKey: String, now: Date) -> Bool {
        guard let statement = prepareStatementLocked(
            """
            INSERT INTO favicon_images (image_key, updated_at)
            VALUES (?, ?)
            ON CONFLICT(image_key) DO UPDATE SET
                updated_at = excluded.updated_at;
            """
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(imageKey, to: statement, at: 1)
        sqlite3_bind_double(statement, 2, now.timeIntervalSince1970)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func upsertSourceURLLocked(_ sourceURL: String, imageKey: String) -> Bool {
        guard let statement = prepareStatementLocked(
            """
            INSERT INTO favicon_sources (source_url, image_key)
            VALUES (?, ?)
            ON CONFLICT(source_url) DO UPDATE SET
                image_key = excluded.image_key;
            """
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(sourceURL, to: statement, at: 1)
        bind(imageKey, to: statement, at: 2)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func upsertAssociationLocked(scopeKey: String, imageKey: String, iconURL: String, now: Date) -> Bool {
        guard let statement = prepareStatementLocked(
            """
            INSERT INTO favicon_associations (scope_key, image_key, icon_url, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(scope_key) DO UPDATE SET
                image_key = excluded.image_key,
                icon_url = excluded.icon_url,
                updated_at = excluded.updated_at;
            """
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        bind(scopeKey, to: statement, at: 1)
        bind(imageKey, to: statement, at: 2)
        bind(iconURL, to: statement, at: 3)
        sqlite3_bind_double(statement, 4, now.timeIntervalSince1970)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func updateTimestampsLocked(scopeKey: String, imageKey: String, now: Date) -> Bool {
        guard executeLocked("BEGIN IMMEDIATE TRANSACTION;") else {
            return false
        }
        
        guard updateAssociationTimestampLocked(scopeKey: scopeKey, now: now),
              updateImageTimestampLocked(imageKey: imageKey, now: now) else {
            _ = executeLocked("ROLLBACK TRANSACTION;")
            return false
        }
        
        guard executeLocked("COMMIT TRANSACTION;") else {
            _ = executeLocked("ROLLBACK TRANSACTION;")
            return false
        }
        
        return true
    }
    
    func updateAssociationTimestampLocked(scopeKey: String, now: Date) -> Bool {
        guard let statement = prepareStatementLocked(
            "UPDATE favicon_associations SET updated_at = ? WHERE scope_key = ?;"
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
        bind(scopeKey, to: statement, at: 2)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func updateImageTimestampLocked(imageKey: String, now: Date) -> Bool {
        guard let statement = prepareStatementLocked(
            "UPDATE favicon_images SET updated_at = ? WHERE image_key = ?;"
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
        bind(imageKey, to: statement, at: 2)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func fetchImageKeysLocked() -> [String] {
        guard let statement = prepareStatementLocked(
            "SELECT image_key FROM favicon_images;"
        ) else {
            return []
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var imageKeys: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            imageKeys.append(string(from: statement, at: 0))
        }
        return imageKeys
    }
    
    func deleteExpiredAssociationsLocked(cutoff: TimeInterval) -> Bool {
        guard let statement = prepareStatementLocked(
            "DELETE FROM favicon_associations WHERE updated_at < ?;"
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        sqlite3_bind_double(statement, 1, cutoff)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func deleteExpiredImagesLocked(cutoff: TimeInterval) -> Bool {
        guard let statement = prepareStatementLocked(
            "DELETE FROM favicon_images WHERE updated_at < ?;"
        ) else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        sqlite3_bind_double(statement, 1, cutoff)
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
}
