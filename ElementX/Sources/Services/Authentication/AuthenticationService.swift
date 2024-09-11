//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

class AuthenticationService: AuthenticationServiceProtocol {
    private var client: Client?
    private var sessionDirectories: SessionDirectories
    private let passphrase: String
    
    private let userSessionStore: UserSessionStoreProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    
    private let homeserverSubject: CurrentValueSubject<LoginHomeserver, Never>
    var homeserver: CurrentValuePublisher<LoginHomeserver, Never> { homeserverSubject.asCurrentValuePublisher() }
    
    init(userSessionStore: UserSessionStoreProtocol, encryptionKeyProvider: EncryptionKeyProviderProtocol, appSettings: AppSettings, appHooks: AppHooks) {
        sessionDirectories = .init()
        passphrase = encryptionKeyProvider.generateKey().base64EncodedString()
        self.userSessionStore = userSessionStore
        self.appSettings = appSettings
        self.appHooks = appHooks
        
        homeserverSubject = .init(LoginHomeserver(address: appSettings.defaultHomeserverAddress,
                                                  loginMode: .unknown))
    }
    
    // MARK: - Public
    
    func configure(for homeserverAddress: String) async -> Result<Void, AuthenticationServiceError> {
        do {
            var homeserver = LoginHomeserver(address: homeserverAddress, loginMode: .unknown)
            
            let client = try await makeClientBuilder().build(homeserverAddress: homeserverAddress)
            let loginDetails = await client.homeserverLoginDetails()
            
            MXLog.info("Sliding sync: \(client.slidingSyncVersion())")
            
            if loginDetails.supportsOidcLogin() {
                homeserver.loginMode = .oidc
            } else if loginDetails.supportsPasswordLogin() {
                homeserver.loginMode = .password
            } else {
                homeserver.loginMode = .unsupported
            }
            
            self.client = client
            homeserverSubject.send(homeserver)
            return .success(())
        } catch ClientBuildError.WellKnownDeserializationError(let error) {
            MXLog.error("The user entered a server with an invalid well-known file: \(error)")
            return .failure(.invalidWellKnown(error))
        } catch ClientBuildError.SlidingSyncVersion(let error) {
            MXLog.info("User entered a homeserver that isn't configured for sliding sync: \(error)")
            return .failure(.slidingSyncNotAvailable)
        } catch {
            MXLog.error("Failed configuring a server: \(error)")
            return .failure(.invalidHomeserverAddress)
        }
    }
    
    func urlForOIDCLogin() async -> Result<OIDCAuthorizationDataProxy, AuthenticationServiceError> {
        guard let client else { return .failure(.oidcError(.urlFailure)) }
        do {
            let oidcData = try await client.urlForOidcLogin(oidcConfiguration: appSettings.oidcConfiguration.rustValue)
            return .success(OIDCAuthorizationDataProxy(underlyingData: oidcData))
        } catch {
            MXLog.error("Failed to get URL for OIDC login: \(error)")
            return .failure(.oidcError(.urlFailure))
        }
    }
    
    func abortOIDCLogin(data: OIDCAuthorizationDataProxy) async {
        guard let client else { return }
        MXLog.info("Aborting OIDC login.")
        await client.abortOidcLogin(authorizationData: data.underlyingData)
    }
    
    func loginWithOIDCCallback(_ callbackURL: URL, data: OIDCAuthorizationDataProxy) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else { return .failure(.failedLoggingIn) }
        do {
            try await client.loginWithOidcCallback(authorizationData: data.underlyingData, callbackUrl: callbackURL.absoluteString)
            return await userSession(for: client)
        } catch OidcError.Cancelled {
            return .failure(.oidcError(.userCancellation))
        } catch {
            MXLog.error("Login with OIDC failed: \(error)")
            return .failure(.failedLoggingIn)
        }
    }
    
    func login(username: String, password: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else { return .failure(.failedLoggingIn) }
        do {
            try await client.login(username: username, password: password, initialDeviceName: initialDeviceName, deviceId: deviceID)
            
            let refreshToken = try? client.session().refreshToken
            if refreshToken != nil {
                MXLog.warning("Refresh token found for a non oidc session, can't restore session, logging out")
                _ = try? await client.logout()
                return .failure(.sessionTokenRefreshNotSupported)
            }
            
            return await userSession(for: client)
        } catch {
            MXLog.error("Failed logging in with error: \(error)")
            // FIXME: How about we make a proper type in the FFI? 😅
            guard let error = error as? ClientError else { return .failure(.failedLoggingIn) }
            
            switch error.code {
            case .forbidden:
                return .failure(.invalidCredentials)
            case .userDeactivated:
                return .failure(.accountDeactivated)
            default:
                return .failure(.failedLoggingIn)
            }
        }
    }
    
    // MARK: - Private
    
    private func makeClientBuilder() -> AuthenticationClientBuilder {
        // Use a fresh session directory each time the user enters a different server
        // so that caches (e.g. server versions) are always fresh for the new server.
        rotateSessionDirectory()
        
        return AuthenticationClientBuilder(sessionDirectories: sessionDirectories,
                                           passphrase: passphrase,
                                           clientSessionDelegate: userSessionStore.clientSessionDelegate,
                                           appSettings: appSettings,
                                           appHooks: appHooks)
    }
    
    private func rotateSessionDirectory() {
        if FileManager.default.directoryExists(at: sessionDirectories.dataDirectory) {
            try? FileManager.default.removeItem(at: sessionDirectories.dataDirectory)
        }
        if FileManager.default.directoryExists(at: sessionDirectories.cacheDirectory) {
            try? FileManager.default.removeItem(at: sessionDirectories.cacheDirectory)
        }
        
        sessionDirectories = .init()
    }
    
    private func userSession(for client: Client) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        switch await userSessionStore.userSession(for: client, sessionDirectories: sessionDirectories, passphrase: passphrase) {
        case .success(let clientProxy):
            return .success(clientProxy)
        case .failure:
            return .failure(.failedLoggingIn)
        }
    }
}