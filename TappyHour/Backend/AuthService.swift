import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()

    // MARK: - Apple

    /// Kicks off Sign in with Apple, then hands the identity token to Supabase.
    func signInWithApple() async throws {
        let nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let credential = try await performAppleRequest(request)
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        try await Supa.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    private func performAppleRequest(_ request: ASAuthorizationAppleIDRequest)
        async throws -> ASAuthorizationAppleIDCredential
    {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            // Retain delegate until the flow finishes
            objc_setAssociatedObject(controller, &Self.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    // MARK: - Google (OAuth via ASWebAuthenticationSession)

    func signInWithGoogle() async throws {
        try await Supa.client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "tappyhour://login-callback"),
            launchFlow: { url in
                try await self.presentWebAuth(url: url, callbackScheme: "tappyhour")
            }
        )
    }

    private func presentWebAuth(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error { continuation.resume(throwing: error); return }
                if let callbackURL = callbackURL { continuation.resume(returning: callbackURL); return }
                continuation.resume(throwing: AuthError.missingCallback)
            }
            session.presentationContextProvider = WebAuthPresenter.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Session

    func signOut() async throws { try await Supa.client.auth.signOut() }

    /// Permanently deletes the signed-in user's account and all server-side
    /// data. Calls the `delete-account` Edge Function (service-role key
    /// required for `auth.admin.deleteUser`, which can't ship in the app).
    /// Required by App Store Review Guideline 5.1.1(v).
    func deleteAccount() async throws {
        guard currentUser() != nil else { return }
        _ = try await Supa.client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(method: .post)
        )
        try? await Supa.client.auth.signOut()
    }

    func currentUser() -> User? { Supa.client.auth.currentUser }

    /// Calls the `is_app_admin()` RPC.
    func fetchIsAdmin() async -> Bool {
        guard currentUser() != nil else { return false }
        do {
            let v: Bool = try await Supa.client.rpc("is_app_admin").execute().value
            return v
        } catch { return false }
    }

    /// Calls `my_managed_venue_ids()` — returns venue ids the signed-in user can manage.
    func fetchManagedVenueIds() async -> Set<String> {
        guard currentUser() != nil else { return [] }
        do {
            let rows: [String] = try await Supa.client.rpc("my_managed_venue_ids").execute().value
            return Set(rows)
        } catch { return [] }
    }

    // MARK: - Helpers

    private static var delegateKey: UInt8 = 0

    private static func randomNonce(length: Int = 32) -> String {
        let chars: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        for _ in 0..<length {
            result.append(chars.randomElement()!)
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case missingToken
    case missingCallback
    case cancelled
    var errorDescription: String? {
        switch self {
        case .missingToken:    "No identity token from Apple."
        case .missingCallback: "OAuth flow did not return a callback URL."
        case .cancelled:       "Sign-in cancelled."
        }
    }
}

// MARK: - Apple delegate

private final class AppleDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: cred)
        } else {
            continuation.resume(throwing: AuthError.missingToken)
        }
    }
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        WebAuthPresenter.shared.anchor
    }
}

// MARK: - Presentation anchor provider (shared for Apple + ASWeb)

final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresenter()
    var anchor: ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
