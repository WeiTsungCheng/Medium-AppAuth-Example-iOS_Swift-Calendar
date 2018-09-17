//
//  ViewController.swift
//  AppAuth-Example-iOS_Swift_Calendar
//
//  Created by wei-tsung-cheng on 2018/9/17.
//  Copyright © 2018 wei-tsung-cheng. All rights reserved.
//
import UIKit
import Foundation

import GTMAppAuth
import AppAuth
import GoogleAPIClientForREST

class ViewController: UIViewController {

    @IBOutlet weak var logTextField: UITextView!

    private let kIssuer = "Your's Issuer"
    private let kClientID = "Your's ClientID"
    private let kRedirectURL = "Your's RedirectURL"
    private let kAppAuthExampleAuthStateKey = "authStateKey"

    var _authState: OIDAuthState!

    override func viewDidLoad() {
        super.viewDidLoad()

        logTextField.textContainer.lineBreakMode = .byCharWrapping
        loadState()
    }

    func saveState() {

        let archivedAuthState = NSKeyedArchiver.archivedData(withRootObject: _authState)
        UserDefaults.standard.set(archivedAuthState, forKey: kAppAuthExampleAuthStateKey)
        UserDefaults.standard.synchronize()

    }

    func loadState() {

        let archivedAuthState = UserDefaults.standard.object(forKey: kAppAuthExampleAuthStateKey)

        if let  archivedAuthState = archivedAuthState as? Data,
            let authState = NSKeyedUnarchiver.unarchiveObject(with: archivedAuthState) as? OIDAuthState {
            setAuthState(authState: authState)
        }

    }

    func setAuthState(authState: OIDAuthState?) {
        if (_authState == authState) {
            return
        }

        _authState = authState

        if _authState != nil {
            _authState.stateChangeDelegate = self
        }
        stateChanged()

    }

    func stateChanged() {
        saveState()
    }

    typealias PostRegistrationCallback = (_ configuration: OIDServiceConfiguration, _ registrationResponse: OIDRegistrationResponse) -> Void

    func doClientRegistration(configuration: OIDServiceConfiguration, callBack: @escaping PostRegistrationCallback) {

        let redireURI:URL = URL(string: kRedirectURL)!

        let request: OIDRegistrationRequest = OIDRegistrationRequest.init(configuration: configuration,
                                                                          redirectURIs: [redireURI],
                                                                          responseTypes: nil,
                                                                          grantTypes: nil,
                                                                          subjectType: nil,
                                                                          tokenEndpointAuthMethod: "client_secret_post",
                                                                          additionalParameters: nil
        )

        self.logMessage(format: "Initiating registration request")

        OIDAuthorizationService.perform(request) { (regResp, error) in

            if let regResp = regResp {
                self.setAuthState(authState: OIDAuthState.init(registrationResponse: regResp))

                self.logMessage(format: "Got registration response: \(regResp)")
                callBack(configuration ,regResp)
            } else {
                self.logMessage(format: "Registration error:\(error?.localizedDescription)" )
                self.setAuthState(authState: nil)

            }

        }
    }

    func doAuthWithAutoCodeExchange(configuration: OIDServiceConfiguration,
                                    clientID: String,
                                    clientSecret: String?) {

        let redirectURI = URL(string: kRedirectURL)!

        let request = OIDAuthorizationRequest.init(configuration: configuration,
                                                   clientId: clientID,
                                                   scopes: [OIDScopeOpenID, OIDScopeProfile, kGTLRAuthScopeCalendar],
                                                   redirectURL: redirectURI,
                                                   responseType: OIDResponseTypeCode,
                                                   additionalParameters: nil)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        self.logMessage(format: "Initiating authorization request with scope: \(request.scope)")

        appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request,
                                                                      presenting: self,
                                                                      callback: { (authState, error) in

                                                                        if let authState = authState {
                                                                            self.setAuthState(authState: authState)
                                                                            self.logMessage(format: "Got authorization tokens. Access token:\(authState.lastTokenResponse?.accessToken)")

                                                                        } else {
                                                                            self.logMessage(format: "Authorization error: \(error?.localizedDescription)")
                                                                            self.setAuthState(authState: nil)
                                                                        }
        })
    }


    func doAuthWithoutCodeExchange(configuration: OIDServiceConfiguration,
                                   clientID: String,
                                   clientSecret: String?) {

        let redirectURI = URL(string: kRedirectURL)!
        let request = OIDAuthorizationRequest.init(configuration: configuration,
                                                   clientId: clientID,
                                                   scopes: [OIDScopeOpenID, OIDScopeProfile, kGTLRAuthScopeCalendar],
                                                   redirectURL: redirectURI,
                                                   responseType: OIDResponseTypeCode,
                                                   additionalParameters: nil)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        appDelegate.currentAuthorizationFlow = OIDAuthorizationService.present(request,
                                                                               presenting: self,
                                                                               callback: { (authorizationResponse, error) in
                                                                                if let authorizationResponse = authorizationResponse {
                                                                                    let authState: OIDAuthState = OIDAuthState.init(authorizationResponse: authorizationResponse)
                                                                                    self.setAuthState(authState: authState)
                                                                                    self.logMessage(format: "Authorization response with code: \(authorizationResponse.authorizationCode)")

                                                                                } else {

                                                                                    self.logMessage(format: "Authorization error: \(error?.localizedDescription)")
                                                                                }
        })

    }


    // 自動更新token
    @IBAction func authWithAutoCodeExchange(_ sender: UIButton) {

        let issuer: URL = URL(string: kIssuer)!

        self.logMessage(format: "Fetching configuration for issuer: \(issuer)")

        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { (configuration, error) in

            if configuration == nil  {
                self.logMessage(format: "Error retrieving discovery document: \(error?.localizedDescription)")

                self.setAuthState(authState: nil)
                return
            }

            if self.kClientID == nil {

                self.doClientRegistration(configuration: configuration!,
                                          callBack: { (configuration, registrationResponse) in

                                            self.doAuthWithAutoCodeExchange(configuration: configuration,
                                                                            clientID: registrationResponse.clientID,
                                                                            clientSecret: registrationResponse.clientSecret!
                                            )
                })
            } else {
                self.doAuthWithAutoCodeExchange(configuration: configuration!,
                                                clientID: self.kClientID,
                                                clientSecret: nil)
            }
        }
    }

    // 手動更新token
    @IBAction func authNoCodeExchange(_ sender: UIButton) {
        let issuer: URL = URL(string: kIssuer)!

        self.logMessage(format: "Fetching configuration for issuer: \(issuer)")

        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { (configuration, error) in

            if configuration == nil  {
                self.logMessage(format: "Error retrieving discovery document: \(error?.localizedDescription)")
                return
            }

            self.logMessage(format: "Got configuration: \(configuration)")

            if self.kClientID == nil {
                self.doClientRegistration(configuration: configuration!,
                                          callBack: { (configuration, registrationResponse) in

                                            self.doAuthWithoutCodeExchange(configuration: configuration,
                                                                           clientID: registrationResponse.clientID,
                                                                           clientSecret: registrationResponse.clientSecret!
                                            )
                })
            } else {
                self.doAuthWithoutCodeExchange(configuration: configuration!,
                                               clientID: self.kClientID,
                                               clientSecret: nil
                )

            }
        }

    }

    @IBAction func codeExchange(_ sender: UIButton) {

        guard _authState != nil else {
            return
        }

        let tokenExchangeRequest: OIDTokenRequest = _authState.lastAuthorizationResponse.tokenExchangeRequest()!

        self.logMessage(format: "Performing authorization code exchange with request \(tokenExchangeRequest)")

        OIDAuthorizationService.perform(tokenExchangeRequest) { (tokenResponse, error) in

            if tokenResponse == nil {
                self.logMessage(format: "Token exchange error: \(error?.localizedDescription)")

            } else {
                self.logMessage(format: "Received token response with accessToken: \(tokenResponse!.accessToken)")

            }
            self._authState.update(with: tokenResponse, error: error)
        }

    }

    @IBAction func clearAuthState(_ sender: UIButton) {
        self.setAuthState(authState: nil)
    }

    @IBAction func clearLog(_ sender: UIButton) {
        logTextField.text = ""
    }

    @IBAction func userInfo(_ sender: UIButton) {

        let userinfoEndpoint: URL? = _authState.lastAuthorizationResponse.request.configuration.discoveryDocument!.userinfoEndpoint

        if userinfoEndpoint == nil {
            self.logMessage(format: "Userinfo endpoint not declared in discovery document")
            return
        }

        let currentAccessToken = _authState.lastTokenResponse?.accessToken
        self.logMessage(format: "Performing userinfo request")

        _authState.performAction { (accesstoken, idToken, error) in

            if let error = error {
                self.logMessage(format: "Error fetching fresh tokens: \(error)")
                return
            }

            if !(currentAccessToken == accesstoken) {
                self.logMessage(format: "Access token was refreshed automatically \(currentAccessToken) to \(accesstoken)")
            } else {
                self.logMessage(format: "Access token was fresh and not updated \(accesstoken)")
            }
            var request = URLRequest(url: userinfoEndpoint!)

            let authorizationHeaderValue = "Bearer \(accesstoken!)"

            request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")

            let configuration = URLSessionConfiguration.default

            let session = URLSession.init(configuration: configuration,
                                          delegate: nil,
                                          delegateQueue: nil)

            let postDataTask = session.dataTask(with: request, completionHandler: {
                (data,
                response,
                error) in

                DispatchQueue.main.async {
                    if let error = error {
                        self.logMessage(format: "HTTP request failed \(error)")
                    }

                    guard  let response  = response  else { return }

                    if !(response.isKind(of: URLResponse.self)) {
                        self.logMessage(format: "Non-HTTP response")
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        return
                    }

                    do {
                        print(httpResponse.statusCode)

                        let jsonDictionaryOrArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: 0))

                        if httpResponse.statusCode != 200 {
                            let responseText: String = String.init(data: data!, encoding: String.Encoding.utf8)!

                            if httpResponse.statusCode == 401 {

                                let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                                                                                    errorResponse: jsonDictionaryOrArray as? [AnyHashable : Any],
                                                                                                    underlyingError: error)

                                self._authState.update(withAuthorizationError: oauthError)
                                self.logMessage(format: "Authorization Error \(oauthError), Response: \(responseText)")
                                print( "Authorization Error \(oauthError),  Response: \(responseText)")


                            } else {
                                self.logMessage(format: "HTTP: \(httpResponse.statusCode). Response: \(responseText)")
                            }

                            return

                        }

                        if let jsonDictionaryOrArray = jsonDictionaryOrArray as? [AnyHashable : Any] {
                            self.logMessage(format: "Success: \(jsonDictionaryOrArray)")
                            print(jsonDictionaryOrArray)
                        }

                    } catch(let error) {
                        print(error.localizedDescription)
                    }
                }

            })
            postDataTask.resume()
        }
    }


    @IBAction func calendar(_ sender: Any) {

        let calendarsEventEndpoint: URL? = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")

        if calendarsEventEndpoint == nil {
            self.logMessage(format: "CalendarsEvent endpoint not declared")
            return
        }

        let currentAccessToken = _authState.lastTokenResponse?.accessToken
        self.logMessage(format: "Performing calendarsEvent request")

        _authState.performAction { (accesstoken, idToken, error) in

            if let error = error {
                self.logMessage(format: "Error fetching fresh tokens: \(error)")
                return
            }

            if !(currentAccessToken == accesstoken) {
                self.logMessage(format: "Access token was refreshed automatically \(currentAccessToken) to \(accesstoken)")
            } else {
                self.logMessage(format: "Access token was fresh and not updated \(accesstoken)")
            }
            var request = URLRequest(url: calendarsEventEndpoint!)
            let authorizationHeaderValue = "Bearer \(accesstoken!)"
            request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")

            let configuration = URLSessionConfiguration.default

            let session = URLSession.init(configuration: configuration,
                                          delegate: nil,
                                          delegateQueue: nil)

            let postDataTask = session.dataTask(with: request, completionHandler: {
                (data,
                response,
                error) in

                DispatchQueue.main.async {

                    if let error = error {
                        self.logMessage(format: "HTTP request failed \(error)")
                    }

                    guard  let response  = response  else { return }

                    if !(response.isKind(of: URLResponse.self)) {
                        self.logMessage(format: "Non-HTTP response")
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        return
                    }

                    do {
                        let jsonDictionaryOrArray = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: 0))

                        if httpResponse.statusCode != 200 {
                            let responseText: String = String.init(data: data!, encoding: String.Encoding.utf8)!
                            if httpResponse.statusCode == 401 {
                                let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                                                                                    errorResponse: jsonDictionaryOrArray as? [AnyHashable : Any],
                                                                                                    underlyingError: error)

                                self._authState.update(withAuthorizationError: oauthError)
                                self.logMessage(format: "Authorization Error \(oauthError), Response: \(responseText)")
                                print( "Authorization Error \(oauthError),  Response: \(responseText)")


                            } else {
                                self.logMessage(format: "HTTP: \(httpResponse.statusCode). Response: \(responseText)")
                            }
                            return
                        }

                        if let jsonDictionaryOrArray = jsonDictionaryOrArray as? [String : Any],
                            let items = jsonDictionaryOrArray["items"] as? [[String: Any]]{
                            self.logMessage(format: "Success: \(items)")
                            print(jsonDictionaryOrArray)
                        }

                    } catch(let error) {
                        print(error.localizedDescription)
                    }
                }
            })
            postDataTask.resume()
        }
    }

    func logMessage(format: String) {
        logTextField.text = format
    }
}

extension ViewController: OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate {

    func didChange(_ state: OIDAuthState) {
        self.stateChanged()

    }

    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        logMessage(format: "Received authorization error: \(error)")
    }
}
