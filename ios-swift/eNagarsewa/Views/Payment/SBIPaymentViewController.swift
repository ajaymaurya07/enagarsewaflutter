import UIKit
import WebKit

/// Hosts the SBI Secure Plus payment gateway in a WKWebView.
/// Mirrors Flutter's sbi_payment_screen.dart (WebView-based).
final class SBIPaymentViewController: UIViewController, WKNavigationDelegate {

    private let transactionData: SbiTransactionData
    weak var coordinator: PaymentCoordinator?

    private let webView = WKWebView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(transactionData: SbiTransactionData, coordinator: PaymentCoordinator) {
        self.transactionData = transactionData
        self.coordinator     = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SBI Payment"
        view.backgroundColor = .appBackground
        navigationItem.hidesBackButton = true  // prevent going back mid-payment

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        view.addSubview(webView)
        view.addSubview(activityIndicator)
        webView.pinToEdges(of: view)
        activityIndicator.center(in: view)

        loadPaymentPage()
    }

    private func loadPaymentPage() {
        // If backend returns HTML directly, load it
        if let html = transactionData.paymentPageHtml {
            webView.loadHTMLString(html, baseURL: URL(string: transactionData.sbiPostUrl ?? ""))
            return
        }
        // Otherwise POST encrypted data to SBI URL
        guard let urlString = transactionData.sbiPostUrl,
              let url = URL(string: urlString),
              let encdata = transactionData.encdata,
              let merchantId = transactionData.merchantId else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "encdata=\(encdata)&merchantId=\(merchantId)"
        request.httpBody = body.data(using: .utf8)
        webView.load(request)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let urlStr = action.request.url?.absoluteString ?? ""

        if urlStr.contains("payment_success") || urlStr.contains("surl") {
            decisionHandler(.cancel)
            coordinator?.showPaymentResult(status: .success, txnId: transactionData.txnid ?? "", gateway: .sbi)
        } else if urlStr.contains("payment_failure") || urlStr.contains("furl") {
            decisionHandler(.cancel)
            coordinator?.showPaymentResult(status: .failure, txnId: transactionData.txnid ?? "", gateway: .sbi)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showAlert(message: "Payment page failed to load. Please try again.")
    }
}
