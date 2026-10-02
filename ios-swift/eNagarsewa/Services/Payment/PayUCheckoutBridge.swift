import UIKit
#if canImport(PayUCheckoutProKit)
import PayUCheckoutProKit
import PayUCheckoutProBaseKit
import PayUParamsKit
#endif

/// PayU CheckoutPro integration — the native SDK that Flutter's `payu_checkoutpro_flutter`
/// plugin wraps on iOS (pod `PayUIndia-CheckoutPro`). Mirrors `_startPayuFlow` / `_PayuDelegate`
/// in payment_details_screen.dart: the same payment params and config are passed, hashes are
/// signed through `APIService.generateHash`, and every SDK outcome (success, failure, error,
/// cancel) ends in a server-side verification by the caller.
@MainActor
final class PayUCheckoutBridge: NSObject {

    enum Outcome { case success, failure, error, cancelled }

    private static var current: PayUCheckoutBridge?
    private let completion: (Outcome) -> Void

    private init(completion: @escaping (Outcome) -> Void) {
        self.completion = completion
    }

    /// Opens the checkout screen. Throws when the SDK is unavailable or refuses the params.
    static func open(transaction t: PayUTransaction, from vc: UIViewController,
                     completion: @escaping (Outcome) -> Void) throws {
        #if canImport(PayUCheckoutProKit)
        let bridge = PayUCheckoutBridge(completion: completion)
        current = bridge

        let param = PayUPaymentParam(key: t.key ?? "", transactionId: t.txnid ?? "", amount: t.amount ?? "",
                                     productInfo: t.productinfo ?? "", firstName: t.firstname ?? "",
                                     email: t.email ?? "", phone: t.phone ?? "",
                                     surl: t.surl ?? "", furl: t.furl ?? "",
                                     environment: t.isTestEnvironment ? .test : .production)
        param.userCredential = "\(t.key ?? ""):\(t.email ?? "")"
        param.additionalParam[PaymentParamConstant.udf1] = t.ulbId ?? ""

        let config = PayUCheckoutProConfig()
        config.merchantName = t.merchantName ?? ""

        PayUCheckoutPro.open(on: vc, paymentParam: param, config: config, delegate: bridge)
        #else
        throw APIError.message("Unable to start PayU payment right now. Please try again.")
        #endif
    }

    fileprivate func finish(_ outcome: Outcome) {
        Self.current = nil
        completion(outcome)
    }

    /// Signs a `hashName`/`hashString` pair through the backend (Dart `generateHash`).
    fileprivate static func sign(hashName: String, hashString: String) async -> String? {
        guard let response = try? await APIService.shared.generateHash(hashName: hashName, hashString: hashString),
              let hash = response.data, !hash.isEmpty else { return nil }
        return hash
    }
}

#if canImport(PayUCheckoutProKit)
extension PayUCheckoutBridge: PayUCheckoutProDelegate {

    nonisolated func onPaymentSuccess(response: Any?) {
        Task { @MainActor in self.finish(.success) }
    }

    nonisolated func onPaymentFailure(response: Any?) {
        Task { @MainActor in self.finish(.failure) }
    }

    nonisolated func onPaymentCancel(isTxnInitiated: Bool) {
        Task { @MainActor in self.finish(.cancelled) }
    }

    nonisolated func onError(_ error: Error?) {
        Task { @MainActor in self.finish(.error) }
    }

    nonisolated func generateHash(for param: DictOfString, onCompletion: @escaping PayUHashGenerationCompletion) {
        let hashName = param[HashConstant.hashName] ?? ""
        let hashString = param[HashConstant.hashString] ?? ""
        guard !hashName.isEmpty, !hashString.isEmpty else { return }
        Task { @MainActor in
            guard let hash = await PayUCheckoutBridge.sign(hashName: hashName, hashString: hashString) else { return }
            onCompletion([hashName: hash])
        }
    }
}
#endif
