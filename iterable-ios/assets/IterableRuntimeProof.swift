import CryptoKit
import Foundation
import UserNotifications

/// Evaluation-only facts consumed by the Iterable iOS verifier.
///
/// Add `ITERABLE_RUNTIME_PROOF` to a dedicated Debug or Release-evaluation
/// configuration. Normal App Store builds should compile the no-op branch.
final class IterableRuntimeProof: @unchecked Sendable {
    static let shared = IterableRuntimeProof()

    #if ITERABLE_RUNTIME_PROOF
    private let queue = DispatchQueue(label: "com.iterable.runtime-proof")
    private let runID: UUID?
    private let expiresAt: Date?
    private let proofPhase: String
    private let processLaunchID = UUID().uuidString
    private var sequence = 0
    private var fileURL: URL?

    private init() {
        let environment = ProcessInfo.processInfo.environment
        var selectedRunID = environment["ITERABLE_PROOF_RUN_ID"].flatMap(
            UUID.init(uuidString:)
        )
        var selectedExpiry = environment["ITERABLE_PROOF_EXPIRES_AT"].flatMap(
            Self.parseDate
        )
        var selectedPhase = environment["ITERABLE_PROOF_PHASE"].flatMap {
            ["initial", "restore", "switch"].contains($0) ? $0 : nil
        } ?? "initial"

        let manager = FileManager.default
        let support = try? manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let proofRoot = support?.appendingPathComponent(
            "IterableProof",
            isDirectory: true
        )
        let activeRun = proofRoot?.appendingPathComponent("active-run.json")

        if let selectedRunID, let selectedExpiry,
           selectedExpiry > Date(), let proofRoot, let activeRun {
            try? manager.createDirectory(
                at: proofRoot,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let context: [String: String] = [
                "run_id": selectedRunID.uuidString.lowercased(),
                "expires_at": Self.formatDate(selectedExpiry),
                "phase": selectedPhase
            ]
            if let data = try? JSONSerialization.data(
                withJSONObject: context,
                options: [.sortedKeys]
            ) {
                try? data.write(to: activeRun, options: .atomic)
                try? manager.setAttributes(
                    [
                        .posixPermissions: 0o600,
                        .protectionKey:
                            FileProtectionType.completeUntilFirstUserAuthentication
                    ],
                    ofItemAtPath: activeRun.path
                )
            }
        } else if let activeRun,
                  let data = try? Data(contentsOf: activeRun),
                  let context = try? JSONSerialization.jsonObject(with: data)
                    as? [String: String],
                  let persistedRun = context["run_id"].flatMap(
                    UUID.init(uuidString:)
                  ),
                  let persistedExpiry = context["expires_at"].flatMap(
                    Self.parseDate
                  ),
                  persistedExpiry > Date() {
            selectedRunID = persistedRun
            selectedExpiry = persistedExpiry
            selectedPhase = context["phase"].flatMap {
                ["initial", "restore", "switch"].contains($0) ? $0 : nil
            } ?? "initial"
        }

        runID = selectedRunID
        expiresAt = selectedExpiry
        proofPhase = selectedPhase

        guard let runID, let expiresAt, expiresAt > Date() else {
            return
        }

        do {
            guard let proofRoot else { return }
            let directory = proofRoot
                .appendingPathComponent("runs", isDirectory: true)
            try manager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDirectory = directory
            try mutableDirectory.setResourceValues(resourceValues)

            let file = directory.appendingPathComponent(
                "\(runID.uuidString.lowercased()).jsonl"
            )
            if !manager.fileExists(atPath: file.path) {
                manager.createFile(
                    atPath: file.path,
                    contents: nil,
                    attributes: [
                        .posixPermissions: 0o600,
                        .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                    ]
                )
            }
            fileURL = file
        } catch {
            fileURL = nil
        }
    }

    func applicationDidFinishLaunching(environment: String) {
        record(
            event: "application_did_finish_launching",
            fields: [
                "bundle_id": Bundle.main.bundleIdentifier ?? "",
                "version": Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "",
                "build": Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "",
                "environment": environment
            ]
        )
    }

    func sdkInitializeReturned(
        region: String,
        jwtRequired: Bool,
        autoPushRegistration: Bool
    ) {
        record(
            event: "sdk_initialize_returned",
            fields: [
                "region": region,
                "jwt_required": jwtRequired,
                "auto_push_registration": autoPushRegistration
            ]
        )
    }

    func identitySet(
        kind: String,
        value: String,
        source: String,
        sessionGeneration: Int
    ) {
        record(
            event: "iterable_identity_set_invoked",
            fields: [
                "identity_kind": kind,
                "identity_hmac": hmac(value),
                "source": source,
                "session_generation": sessionGeneration
            ]
        )
    }

    func localPersonalizedStateCleared(sessionGeneration: Int) {
        record(
            event: "local_personalized_state_cleared",
            fields: ["session_generation": sessionGeneration]
        )
    }

    func logoutInvoked(sessionGeneration: Int) {
        record(
            event: "iterable_logout_invoked",
            fields: ["session_generation": sessionGeneration]
        )
    }

    func logoutCallback(
        succeeded: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {
        record(
            event: "iterable_logout_callback",
            fields: callbackFields(
                succeeded: succeeded,
                errorDomain: errorDomain,
                errorCode: errorCode
            )
        )
    }

    func notificationSettingsObserved(
        _ settings: UNNotificationSettings,
        source: String
    ) {
        record(
            event: "notification_settings_observed",
            fields: [
                "authorization_status": settings.authorizationStatus.rawValue,
                "alert_setting": settings.alertSetting.rawValue,
                "badge_setting": settings.badgeSetting.rawValue,
                "sound_setting": settings.soundSetting.rawValue,
                "source": source
            ]
        )
    }

    func notificationAuthorizationCallback(
        granted: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {
        var fields: [String: Any] = ["granted": granted]
        if let errorDomain { fields["error_domain"] = allowlisted(errorDomain) }
        if let errorCode { fields["error_code"] = errorCode }
        record(event: "notification_authorization_callback", fields: fields)
    }

    func apnsRegistrationCallback(token: Data) {
        record(
            event: "apns_registration_callback",
            fields: [
                "token_sha256": sha256(token),
                "token_bytes": token.count
            ]
        )
    }

    func iterableRegisterInvoked(token: Data) {
        record(
            event: "iterable_register_invoked",
            fields: ["token_sha256": sha256(token)]
        )
    }

    func iterableRegisterCallback(
        succeeded: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {
        record(
            event: "iterable_register_callback",
            fields: callbackFields(
                succeeded: succeeded,
                errorDomain: errorDomain,
                errorCode: errorCode
            )
        )
    }

    func notificationResponseCallback(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {
        recordPushFact(
            event: "notification_response_callback",
            marker: marker,
            deliveryNonce: deliveryNonce,
            actionIdentifier: actionIdentifier,
            campaignID: campaignID,
            templateID: templateID,
            messageID: messageID
        )
    }

    func iterablePushForwardInvoked(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {
        recordPushFact(
            event: "iterable_push_forward_invoked",
            marker: marker,
            deliveryNonce: deliveryNonce,
            actionIdentifier: actionIdentifier,
            campaignID: campaignID,
            templateID: templateID,
            messageID: messageID
        )
    }

    func notificationResponseCompleted(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {
        recordPushFact(
            event: "notification_response_completion",
            marker: marker,
            deliveryNonce: deliveryNonce,
            actionIdentifier: actionIdentifier,
            campaignID: campaignID,
            templateID: templateID,
            messageID: messageID
        )
    }

    private func recordPushFact(
        event: String,
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {
        var fields: [String: Any] = [
            "action_identifier": allowlisted(actionIdentifier)
        ]
        if let marker, marker.range(
            of: #"^[A-Za-z0-9._-]{1,80}$"#,
            options: .regularExpression
        ) != nil {
            fields["marker_sha256"] = sha256(Data(marker.utf8))
        }
        if let deliveryNonce, deliveryNonce.range(
            of: #"^[0-9a-f]{64}$"#,
            options: .regularExpression
        ) != nil {
            fields["delivery_nonce_sha256"] = sha256(Data(deliveryNonce.utf8))
        }
        if let campaignID { fields["campaign_id"] = campaignID }
        if let templateID { fields["template_id"] = templateID }
        if let messageID { fields["message_id_sha256"] = sha256(Data(messageID.utf8)) }
        record(event: event, fields: fields)
    }

    private func callbackFields(
        succeeded: Bool,
        errorDomain: String?,
        errorCode: Int?
    ) -> [String: Any] {
        var fields: [String: Any] = ["result": succeeded ? "success" : "failure"]
        if let errorDomain { fields["error_domain"] = allowlisted(errorDomain) }
        if let errorCode { fields["error_code"] = errorCode }
        return fields
    }

    private func hmac(_ value: String) -> String {
        guard let runID else { return "" }
        let key = SymmetricKey(data: Data(runID.uuidString.lowercased().utf8))
        let authentication = HMAC<SHA256>.authenticationCode(
            for: Data(value.utf8),
            using: key
        )
        return Data(authentication).map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func allowlisted(_ value: String) -> String {
        String(value.unicodeScalars.filter {
            CharacterSet.alphanumerics.union(
                CharacterSet(charactersIn: "._-")
            ).contains($0)
        }.prefix(80))
    }

    private func record(event: String, fields: [String: Any]) {
        queue.async { [weak self] in
            guard let self, let runID, let expiresAt, expiresAt > Date(),
                  let fileURL else {
                return
            }
            sequence += 1
            var value: [String: Any] = [
                "schema": "iterable-ios-runtime-proof/1",
                "run_id": runID.uuidString.lowercased(),
                "recorded_at": Self.formatDate(Date()),
                "process_launch_id": processLaunchID,
                "proof_phase": proofPhase,
                "sequence": sequence,
                "event": event
            ]
            fields.forEach { value[$0] = $1 }
            guard JSONSerialization.isValidJSONObject(value),
                  var data = try? JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys]
                  ) else {
                return
            }
            data.append(0x0A)
            do {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                return
            }
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func formatDate(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }
    #else
    private init() {}

    func applicationDidFinishLaunching(environment: String) {}
    func sdkInitializeReturned(
        region: String,
        jwtRequired: Bool,
        autoPushRegistration: Bool
    ) {}
    func identitySet(
        kind: String,
        value: String,
        source: String,
        sessionGeneration: Int
    ) {}
    func localPersonalizedStateCleared(sessionGeneration: Int) {}
    func logoutInvoked(sessionGeneration: Int) {}
    func logoutCallback(
        succeeded: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {}
    func notificationSettingsObserved(
        _ settings: UNNotificationSettings,
        source: String
    ) {}
    func notificationAuthorizationCallback(
        granted: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {}
    func apnsRegistrationCallback(token: Data) {}
    func iterableRegisterInvoked(token: Data) {}
    func iterableRegisterCallback(
        succeeded: Bool,
        errorDomain: String? = nil,
        errorCode: Int? = nil
    ) {}
    func notificationResponseCallback(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {}
    func iterablePushForwardInvoked(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {}
    func notificationResponseCompleted(
        marker: String?,
        deliveryNonce: String?,
        actionIdentifier: String,
        campaignID: Int?,
        templateID: Int?,
        messageID: String?
    ) {}
    #endif
}
