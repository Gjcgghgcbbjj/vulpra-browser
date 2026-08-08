import Foundation

public struct EngineContextMenuElement: Equatable, Sendable {
    public let title: String?
    public let linkURL: URL?
    public let imageURL: URL?

    public init(title: String?, linkURL: URL?, imageURL: URL?) {
        self.title = title
        self.linkURL = linkURL
        self.imageURL = imageURL
    }
}

public struct EngineDownloadResponse: Equatable, Sendable {
    public let sourceURL: URL?
    public let suggestedFilename: String?
    public let contentType: String?
    public let contentLength: Int64
    public let localFilePath: String

    public init(sourceURL: URL?, suggestedFilename: String?, contentType: String?, contentLength: Int64,
                localFilePath: String) {
        self.sourceURL = sourceURL
        self.suggestedFilename = suggestedFilename
        self.contentType = contentType
        self.contentLength = contentLength
        self.localFilePath = localFilePath
    }
}

public enum EnginePermissionKind: String, Codable, Sendable {
    case camera, microphone, location, notifications, persistentStorage, unknown
}

public struct EnginePermissionRequest: Equatable, Sendable {
    public let origin: URL?
    public let kind: EnginePermissionKind
    public let isPrivate: Bool

    public init(origin: URL?, kind: EnginePermissionKind, isPrivate: Bool) {
        self.origin = origin
        self.kind = kind
        self.isPrivate = isPrivate
    }
}

public enum EnginePermissionDecision: Int, Codable, Sendable {
    case deny = 0
    case allow = 1
}

public enum EnginePromptKind: String, Codable, Sendable {
    case alert, confirm, text, authentication, file, share, unknown
}

public struct EnginePromptRequest: Equatable, Sendable {
    public let id: String
    public let kind: EnginePromptKind
    public let title: String
    public let message: String
    public let defaultValue: String?
    public let text: String?
    public let uri: URL?

    public init(id: String, kind: EnginePromptKind, title: String, message: String, defaultValue: String?,
                text: String? = nil, uri: URL? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.defaultValue = defaultValue
        self.text = text
        self.uri = uri
    }
}

public struct EnginePromptResponse: Equatable, Sendable {
    public let accepted: Bool
    public let text: String?
    public let files: [URL]

    public init(accepted: Bool, text: String? = nil, files: [URL] = []) {
        self.accepted = accepted
        self.text = text
        self.files = files
    }
}

public struct EngineStorageClearOptions: OptionSet, Sendable {
    public let rawValue: Int64
    public init(rawValue: Int64) { self.rawValue = rawValue }
    // Engine-side storage controller ClearFlags bit layout:
    // COOKIES=1<<0, NETWORK_CACHE=1<<1, IMAGE_CACHE=1<<2, HISTORY=1<<3,
    // DOM_STORAGES=1<<4, AUTH_SESSIONS=1<<5, PERMISSIONS=1<<6,
    // SITE_SETTINGS=1<<7, SITE_DATA=1<<8, ALL=1<<9.
    public static let cookies = Self(rawValue: 1 << 0)                 // COOKIES
    public static let webStorage = Self(rawValue: 1 << 4)              // DOM_STORAGES
    public static let cache = Self(rawValue: (1 << 1) | (1 << 2))      // NETWORK_CACHE | IMAGE_CACHE
    public static let authentication = Self(rawValue: 1 << 5)          // AUTH_SESSIONS
    public static let all: Self = Self(rawValue: 1 << 9)               // ALL -> CLEAR_ALL
}

@MainActor
public protocol EnginePromptHandler: AnyObject {
    func engineSession(_ id: EngineSessionID, handle prompt: EnginePromptRequest,
                       completion: @escaping (EnginePromptResponse?) -> Void)
}

public struct EngineScreenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

@MainActor
public protocol EngineClipboardPermissionHandler: AnyObject {
    func engineSession(_ id: EngineSessionID, requestedClipboardAccessAt point: EngineScreenPoint,
                       completion: @escaping (Bool) -> Void)
}

@MainActor
public protocol EnginePermissionHandler: AnyObject {
    func engineSession(_ id: EngineSessionID, decide request: EnginePermissionRequest,
                       completion: @escaping (EnginePermissionDecision) -> Void)
}

@MainActor
public protocol EngineDownloadHandler: AnyObject {
    func engineSession(_ id: EngineSessionID, accept response: EngineDownloadResponse,
                       completion: @escaping (Bool) -> Void)
    func engineSession(_ id: EngineSessionID, downloadAt path: String, received bytes: Int64) -> Bool
    func engineSession(_ id: EngineSessionID, completedDownloadAt path: String, succeeded: Bool)
}

@MainActor
public protocol EngineContentObserver: AnyObject {
    func engineSession(_ id: EngineSessionID, requestedContextMenu element: EngineContextMenuElement)
}
