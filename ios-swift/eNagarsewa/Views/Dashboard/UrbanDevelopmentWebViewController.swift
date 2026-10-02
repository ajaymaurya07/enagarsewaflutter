import UIKit
import WebKit

/// Port of lib/widgets/urban_development_webview.dart — the "OTS" department portal.
///
/// Mirrors the Flutter screen by design: no host allow-list and certificate problems are
/// continued past so the portal opens everywhere. Only non-web schemes (tel:, mailto:, upi:
/// …) are handed to the OS. Back walks the web history before leaving the screen.
final class UrbanDevelopmentWebViewController: BaseViewController, WKNavigationDelegate, WKUIDelegate {

    private static let initialURL = URL(string: "https://upulbots.in/")!
    private static let loadTimeout: TimeInterval = 45

    private var webView: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorView = UIView()
    private let errorTitle = UILabel(nil, font: .poppins(16, .semibold), color: .black87, lines: 0, alignment: .center)
    private let errorDetail = UILabel(nil, font: .poppins(13), color: .black54, lines: 0, alignment: .center)
    private var timeoutWork: DispatchWorkItem?
    private var isLoading = true

    override var screenBackground: UIColor { .white }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "OTS", titleColor: .appPrimary, backColor: .appPrimary, titleSize: 16, titleWeight: .semibold)
        interceptsBack = true

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        webView.pinToSafeArea(of: view)

        spinner.color = .appPrimary
        view.addSubview(spinner)
        spinner.center(in: view)

        buildErrorView()
        load()
    }

    deinit { timeoutWork?.cancel() }

    private func buildErrorView() {
        errorView.backgroundColor = .white
        errorView.isHidden = true
        let retry = PrimaryButton("Retry", height: 40, radius: 20, fontSize: 13, weight: .regular, icon: "arrow.clockwise")
        retry.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        retry.onEvent { [weak self] in self?.load() }
        let views: [UIView] = [UIImageView(symbol: "icloud.slash", size: 56, color: .appPrimary), errorTitle, errorDetail, retry]
        let stack = UIStackView.v(0, alignment: .center, views)
        stack.setCustomSpacing(16, after: views[0])
        stack.setCustomSpacing(8, after: views[1])
        stack.setCustomSpacing(24, after: views[2])
        errorView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -24),
        ])
        view.addSubview(errorView)
        errorView.pinToSafeArea(of: view)
    }

    private func load() {
        errorView.isHidden = true
        setLoadingState(true)
        webView.load(URLRequest(url: Self.initialURL))
    }

    private func setLoadingState(_ loading: Bool) {
        isLoading = loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        if loading {
            errorView.isHidden = true
            restartTimeout()
        } else {
            timeoutWork?.cancel()
        }
    }

    /// Some pages never finish nor fail — fall back to the error card after 45 s.
    private func restartTimeout() {
        timeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isLoading else { return }
            self.showError("Taking too long to load",
                           "The portal did not respond. Check your internet connection, or update Android System WebView from the Play Store.")
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadTimeout, execute: work)
    }

    private func showError(_ title: String, _ detail: String) {
        timeoutWork?.cancel()
        isLoading = false
        spinner.stopAnimating()
        errorTitle.text = title
        errorDetail.text = detail
        errorView.isHidden = false
        view.bringSubviewToFront(errorView)
    }

    override func handleBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }
        if ["http", "https", "about", "data", "blob", "file"].contains(scheme) {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            if !opened { self?.snack("No app available to open \(scheme): links") }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setLoadingState(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setLoadingState(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleMainFrameError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleMainFrameError(error)
    }

    private func handleMainFrameError(_ error: Error) {
        let ns = error as NSError
        // A cancelled load (new navigation started / scheme handed to the OS) is not a failure.
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return } // frame load interrupted
        showError("Page could not be loaded", "\(ns.localizedDescription) (code \(ns.code))")
    }

    /// `onSslAuthError: error.proceed()` — continue past certificate problems.
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // MARK: - WKUIDelegate

    /// `target="_blank"` links load in the same view (as the Flutter WebView does).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
