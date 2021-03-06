//
//  BiometricLoginPresentable.swift
//  CakeWallet
//
//  Created by FotoLockr on 31.01.2018.
//  Copyright © 2018 FotoLockr. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit

protocol BiometricAuthenticationActions {
    var onBiometricAuthenticate: () -> Promise<Void> { get }
}

protocol BiometricLoginPresentable: class {
    func biometricLogin(onLogined: @escaping  () -> Void)
}

extension BiometricLoginPresentable where Self: UIViewController, Self: BiometricAuthenticationActions {
    func biometricLogin(onLogined: @escaping () -> Void) {
        onBiometricAuthenticate()
            .then { onLogined() }
            .catch { error in print(error) }
    }
}
