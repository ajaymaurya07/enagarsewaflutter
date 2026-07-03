import UIKit

/// Thin seam over the PayU iOS SDK.
///
/// No PayU pod is integrated yet (see the commented-out `pod 'PayUbiz'` line in
/// `ios-swift/Podfile`) — this type exists so the rest of the checkout flow
/// (`PaymentDetailsViewModel`/`PaymentDetailsViewController`) can already be wired end-to-end for
/// when the SDK lands, with only this one call site needing a real implementation.
///
/// Mirrors Flutter's `PayUCheckoutProFlutter` + `PayUCheckoutProProtocol` delegate
/// (see `_PayuDelegate` / `_startPayuFlow` in `payment_details_screen.dart`): the SDK is handed a
/// map of `PayUPaymentParamKey` values plus a delegate, and the delegate's `generateHash` /
/// `onPaymentSuccess` / `onPaymentFailure` / `onPaymentCancel` / `onError` calls report the outcome.
enum PayUCheckoutBridge {

    enum Outcome: Equatable {
        case success
        case failure
        case cancelled
        /// The SDK itself couldn't be invoked (not integrated yet) — distinct from a real
        /// checkout failure so the caller can show an accurate message instead of implying a
        /// payment attempt actually happened.
        case unavailable
    }

    /// - Parameters:
    ///   - transaction: server-issued PayU params (key/txnid/amount/hash/env/etc. — see
    ///     `PayUTransaction`), exactly what Flutter forwards into `PayUPaymentParamKey`.
    ///   - generateHash: invoked by the SDK mid-checkout to sign a `hashName`/`hashString` pair
    ///     via the backend (`APIService.generateHash`) before continuing.
    ///   - completion: called exactly once with the final outcome, on the main actor.
    @MainActor
    static func openCheckout(
        transaction: PayUTransaction,
        from viewController: UIViewController,
        generateHash: @escaping (_ hashName: String, _ hashString: String) async -> String?,
        completion: @escaping (Outcome) -> Void
    ) {
        // TODO(payu-ios-sdk): wire the real PayU iOS SDK here.
        //   1. Uncomment + pin `pod 'PayUbiz'` (confirm the exact current pod name/version from
        //      PayU's iOS integration docs — it has changed over the years) in
        //      `ios-swift/Podfile`, then `pod install`.
        //   2. Build the SDK's payment-params object from `transaction`: key, txnid, amount,
        //      productinfo, firstname, email, phone, surl, furl, and
        //      `transaction.resolvedPayuEnvironment` — the same fields Flutter passes via
        //      `PayUPaymentParamKey` in `_startPayuFlow`.
        //   3. Implement the SDK's hash-generation delegate method by calling `generateHash`
        //      above (already wired to the backend) and returning its result to the SDK.
        //   4. Map the SDK's onPaymentSuccess/onPaymentFailure/onPaymentCancel/onError callbacks
        //      to `completion(.success)` / `.failure` / `.cancelled` respectively — do NOT trust
        //      the SDK's own status text; the caller always re-verifies server-side afterwards
        //      (mirrors Flutter's `_PayuDelegate._verify`, which is called from every one of
        //      those four callbacks).
        //
        // Until the SDK is wired in, honestly report that checkout can't be presented rather than
        // guessing at a fake SDK API or fabricating a payment outcome.
        completion(.unavailable)
    }
}
