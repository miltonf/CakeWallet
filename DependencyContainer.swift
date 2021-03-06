//
//  DependencyContainer.swift
//  Wallet
//
//  Created by FotoLockr on 11/30/17.
//  Copyright © 2017 FotoLockr. All rights reserved.
//

import Foundation
import Dip
import SwiftKeychainWrapper

let container = DependencyContainer.configure()

extension DependencyContainer {
    static func configure() -> DependencyContainer {
        return DependencyContainer { container in
            // MARK: KeychainStorage
            
            container.register(.singleton) {
                KeychainStorageImpl(keychain: KeychainWrapper.standard) as KeychainStorage
            }
            
            // MARK: WalletProxy
            
            container.register(.singleton) {
                WalletProxy(origin: EmptyWallet())
                }.implements(WalletProxy.self)
            
            // MARK: AuthenticationProtocol, Account, AccountSettingsConfigurable
            
            container.register(.singleton) {
                AccountImpl(keychainStorage: try! container.resolve(), proxyWallet: try! container.resolve() as WalletProxy)
                }.implements(AuthenticationProtocol.self, Account.self, AccountSettingsConfigurable.self)
            
            // MARK: Wallets
            
            container.register { moneroWalletGateway, account, keychainStorage in
                Wallets(moneroWalletGateway: moneroWalletGateway, account: account, keychainStorage: keychainStorage)
                }.implements(
                    WalletsCreating.self,
                    WalletsRecoverable.self,
                    WalletsLoadable.self,
                    WalletsRemovable.self)
                .implements(EstimatedFeeCalculable.self)
            
            // MARK: RateTicker
            
            container.register(.singleton) { MoneroRateTicker() }
                .implements(RateTicker.self)
            
            // MARK: WelcomeViewController
            
            container.register { WelcomeViewController() }
            
            // MARK: PinPasswordViewController
            
            container.register { canClose in PinPasswordViewController(canClose: canClose) }
            
            // MARK: SetupPinPasswordViewController
            
            container.register {
                SetupPinPasswordViewController(
                    account: try! container.resolve() as AccountImpl,
                    pinPasswordViewController: try! container.resolve(arguments: false) as PinPasswordViewController)
            }
            
            
            // MARK: AddWalletViewController
            
            container.register { AddWalletViewController() }
            
            // MARK: NewWalletViewController
            
            container.register { (wallets: Wallets) in  NewWalletViewController(wallets: wallets as WalletsCreating) }
            
            // MARK: RecoveryViewController
            
            container.register { (wallets: Wallets) in  RecoveryViewController(wallets: wallets as WalletsRecoverable) }
            
            // MARK: SeedViewController
            
            container.register { (seed: String) in SeedViewController(seed: seed) }
            
            // MARK: SummaryViewController
            
            container.register { (wallet: WalletProtocol) in
                DashboardViewController(wallet: wallet, rateTicker: try! container.resolve() as RateTicker)
            }
            
            // MARK: ReceiveViewController
            
            container.register { (wallet: WalletProtocol) in ReceiveViewController(wallet: wallet) }
            
            // MARK: SendViewController
            
            container.register {
                SendViewController(
                    accountSettings: try! container.resolve() as AccountSettingsConfigurable,
                    estimatedFeeCalculation: (try! container.resolve() as Account).wallets(),
                    transactionCreation:  (try! container.resolve() as Account).currentWallet,
                    rateTicker: try! container.resolve() as RateTicker)
            }
            
            // MARK: UnlockViewController
            
            container.register { (account: Account & AuthenticationProtocol) in
                LoginViewController(account: account)
            }
            
            // MARK: SettingsViewController
            
            container.register { SettingsViewController(accountSettings: try! container.resolve() as AccountSettingsConfigurable) }
                .resolvingProperties { (container: DependencyContainer, vc: SettingsViewController) in
                    vc.presentWalletsScreen = { [weak vc] in
                        let walletsListViewController = try! container.resolve() as WalletsViewController
                        vc?.navigationController?.pushViewController(walletsListViewController, animated: true)
                    }
                    
                    vc.presentChangePasswordScreen = { [weak vc] in
                        let changePasswordViewController = try! container.resolve() as ChangePasswordViewController
                        changePasswordViewController.onPasswordChanged = { [weak changePasswordViewController] in
                            changePasswordViewController?.dismiss(animated: true)
                        }
                        vc?.present(changePasswordViewController, animated: true)
                    }
                    
                    vc.presentNodeSettingsScreen = { [weak vc] in
                        let nodeSettingsViewController = try! container.resolve() as NodeSettingsViewController
                        vc?.navigationController?.pushViewController(nodeSettingsViewController, animated: true)
                    }
                }
            
            // MARK: WalletsViewController
            
            container.register { WalletsViewController(account: try! container.resolve()) }
                .resolvingProperties { (container: DependencyContainer, vc: WalletsViewController) in
                    vc.presentLoadWalletScreen = { index in
                        let account = try! container.resolve() as Account
                        let wallets = account.wallets()
                        let name = index.name
                        let laodWalletViewController = try! container.resolve(arguments: name, wallets) as LoadWalletViewController
                        
                        if laodWalletViewController.canBePresented {
                            laodWalletViewController.onLogined = { [weak laodWalletViewController, weak vc] in
                                laodWalletViewController?.dismiss(animated: true) {
                                    vc?.navigationController?.popToRootViewController(animated: true)
                                }
                            }
                            
                            vc.present(laodWalletViewController, animated: true)
                        } else {
                            let alert = UIAlertController.showSpinner(message: "Loading wallet - \(index.name)")
                            vc.present(alert, animated: true)
                            
                            
                            wallets.loadWallet(withName: name)
                                .then { [weak vc] in
                                    alert.dismiss(animated: true) {
                                        vc?.navigationController?.popToRootViewController(animated: true)
                                    }
                                }.catch { [weak vc] error in
                                    alert.dismiss(animated: true) {
                                        vc?.showError(error)
                                    }
                            }
                        }
                    }
                    
                    vc.presentNewWalletScreen = { [weak vc] in
                        let navController = UINavigationController()
                        let account = try! container.resolve() as Account
                        let signUpFlow = try! container.resolve(arguments: navController, account.wallets()) as SignUpFlow
                        signUpFlow.finalHandler = {
                            navController.dismiss(animated: true) {
                                vc?.navigationController?.popToRootViewController(animated: true)
                            }
                        }
                        
                        signUpFlow.changeRoute(.addNewWallet)
                        vc?.present(signUpFlow.currentViewController, animated: true)
                    }
                    
                    vc.presentSeedWalletScreen = { index in
                        let verifyPinPasswordViewController = try! container.resolve() as VerifyPinPasswordViewController
                        verifyPinPasswordViewController.onVerified = { [weak vc, weak verifyPinPasswordViewController] in
                            let account = try! container.resolve() as Account
                            let wallets = account.wallets()
                            wallets.fetchSeed(for: index)
                                .then { seed -> Void in
                                    let seedViewController = try! container.resolve(arguments: seed) as SeedViewController
                                    let navController = UINavigationController(rootViewController: seedViewController)
                                    seedViewController.finishHandler = { [weak seedViewController] in
                                        seedViewController?.dismiss(animated: true) {
                                            navController.viewControllers = []
                                        }
                                    }
                                    
                                    verifyPinPasswordViewController?.dismiss(animated: true) {
                                        vc?.present(navController, animated: true)
                                    }
                                }.catch { error in
                                    verifyPinPasswordViewController?.showError(error)
                            }
                        }
                        
                        vc.present(verifyPinPasswordViewController, animated: true)
                    }
                    
                    vc.presentRemoveWalletScreen = { [weak vc] index in
                        let verifyPinPasswordViewController = try! container.resolve() as VerifyPinPasswordViewController
                        verifyPinPasswordViewController.onVerified = {
                            let account = try! container.resolve() as Account
                            let wallets = account.wallets()
                            let alert = UIAlertController.showSpinner(message: "Removing wallet")
                            verifyPinPasswordViewController.present(alert, animated: true)
                            
                            wallets.removeWallet(withIndex: index)
                                .then { _ in
                                    alert.dismiss(animated: false) {
                                        verifyPinPasswordViewController.dismiss(animated: true)
                                    }
                                }.catch { error in
                                    alert.dismiss(animated: false) {
                                        verifyPinPasswordViewController.showError(error)
                                    }
                            }
                        }
                        
                        vc?.present(verifyPinPasswordViewController, animated: true)
                    }
                }
            
            // MARK: LoadWalletViewController
            
            container.register { (name: String, wallets: Wallets) in
                LoadWalletViewController(
                    walletName: name,
                    wallets: wallets as WalletsLoadable,
                    verifyPasswordViewController: try! container.resolve() as VerifyPinPasswordViewController)
                }
            
            // MARK: VerifyPinPasswordViewController
            
            container.register {
                VerifyPinPasswordViewController(
                    account: try! container.resolve() as AccountImpl,
                    pinPasswordViewController: try! container.resolve(arguments: true) as PinPasswordViewController)
            }
            
            // MARK: ChangePasswordViewController

            container.register { ChangePasswordViewController(
                account: try! container.resolve() as Account,
                pinPasswordViewController: try! container.resolve(arguments: true) as PinPasswordViewController)
            }
            
            // MARK: TransactionDetailsViewController
            
            container.register { (tx: TransactionDescription) in TransactionDetailsViewController(transaction: tx) }
            
            // MARK: NodeSettingsViewController
            
            container.register { NodeSettingsViewController(account: try! container.resolve() as Account) }
            
            // MARK: DisclaimerViewController
            
            container.register { DisclaimerViewController() }
            
            // Flows
            
            container.register { rootViewController, wallets in  SignUpFlow(rootViewController: rootViewController, wallets: wallets) }
            container.register { MainFlow(rootViewController: UINavigationController(), wallet: try! container.resolve() as WalletProxy) }
            container.register { RootFlow(window: $0, account: try! container.resolve() as AccountImpl) }
        }
    }
}
