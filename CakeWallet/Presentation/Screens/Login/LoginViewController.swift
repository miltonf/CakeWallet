//
//  UnlockViewController.swift
//  Wallet
//
//  Created by FotoLockr on 11/14/17.
//  Copyright © 2017 FotoLockr. All rights reserved.
//

import UIKit
import PromiseKit
import SnapKit

final class LoginViewController: BaseViewController<BaseView>, BiometricAuthenticationActions, BiometricLoginPresentable {
    
    // MARK: Property injections
    
    var onBiometricAuthenticate: () -> Promise<Void> {
        return account.biometricAuthentication
    }
    
    var onLogined: VoidEmptyHandler
    private let account: Account & AuthenticationProtocol
    private let pinViewController: PinPasswordViewController
    
    init(account: Account & AuthenticationProtocol) {
        self.account = account
        self.pinViewController = try! container.resolve(arguments: false) as PinPasswordViewController
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinViewController.pin { [weak self] in self?.loadWallet(withPassword: $0) }
        view.addSubview(pinViewController.view)
        pinViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if account.biometricAuthenticationIsAllow() {
            biometricLogin() {
                self.onBiometricLogin()
            }
        }
    }
    
    private func onBiometricLogin() {
        let alert =  UIAlertController.showSpinner(message: "Unlocking your wallet")
        present(alert, animated: true)
        
        account.loadCurrentWallet()
            .then { [weak self] in
                alert.dismiss(animated: false) {
                    self?.onLogined?()
                }
            }.catch { [weak self] error in
                alert.dismiss(animated: true) {
                    self?.pinViewController.empty()
                    self?.pinViewController.showError(error)
                }
        }
    }
    
    private func loadWallet(withPassword password: String) {
        let alert =  UIAlertController.showSpinner(message: "Unlocking your wallet")
        present(alert, animated: true)
        
        account.login(withPassword: password)
            .then { [weak self] in
                alert.dismiss(animated: false) {
                    self?.onLogined?()
                }
            }.catch { [weak self] error in
                alert.dismiss(animated: true) {
                    self?.pinViewController.empty()
                    self?.pinViewController.showError(error)
                }
        }
    }
}
