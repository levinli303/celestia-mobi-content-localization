import ArgumentParser
import Foundation
import OpenCloudKit
import Parser

enum ArgumentError: Error {
    case noAuth
}

extension ArgumentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noAuth:
            return "No authentication method is provided"
        }
    }
}

@main
struct UploaderApp: AsyncParsableCommand {
    static let containerID = "iCloud.space.celestia.Celestia"
    static let environment = CKEnvironment.production

    @Argument
    var oldPath: String
    @Argument
    var newPath: String
    @Argument
    var mainKey: String

    @Option(help: "The key file path for CloudKit.")
    var keyFilePath: String?

    @Option(help: "The key ID for CloudKit.")
    var keyID: String?

    @Option(help: "The API token for CloudKit.")
    var apiToken: String?

    @Option
    var englishKey: String?

    func run() async throws {
        let parser = Parser()
        
        let oldStringsByLocales = try parser.parseDirectory(at: oldPath)
        let newStringsByLocales = try parser.parseDirectory(at: newPath)
        let oldStringsByKeys = try parser.convertToStringsByKeys(oldStringsByLocales)
        let newStringsByKeys = try parser.convertToStringsByKeys(newStringsByLocales)

        let addedOnes = newStringsByKeys.filter({ oldStringsByKeys[$0.key] == nil })
        let removedOnes = oldStringsByKeys.filter({ newStringsByKeys[$0.key] == nil })
        let changedOnes = newStringsByKeys.filter({ oldStringsByKeys[$0.key] != nil && oldStringsByKeys[$0.key] != $0.value })

        let config: CKContainerConfig
        if let keyID, let keyFilePath {
            let serverKeyAuth = try CKServerToServerKeyAuth(keyID: keyID, privateKeyFile: keyFilePath)
            config = CKContainerConfig(containerIdentifier: Self.containerID, environment: Self.environment, serverToServerKeyAuth: serverKeyAuth)
        } else if let apiToken {
            config = CKContainerConfig(containerIdentifier: Self.containerID, environment: Self.environment, apiTokenAuth: apiToken)
        } else {
            throw ArgumentError.noAuth
        }

        CloudKitHandler.configure(config)
        let handler = CloudKitHandler()
        try await handler.uploadChanges(addedStrings: addedOnes, removedStrings: removedOnes, changedStrings: changedOnes, mainKey: mainKey, englishKey: englishKey)
    }
}
