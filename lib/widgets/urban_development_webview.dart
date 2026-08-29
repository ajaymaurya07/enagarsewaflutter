import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Unrestricted WebView for the department portal.
///
/// By design there is NO host/scheme allow-list, NO certificate check and NO
/// mixed-content blocking here: every link the portal opens - including links
/// to other websites - must load on every device. Only non-web schemes
/// (tel:, mailto:, upi:, intent:) are handed to the OS, because a WebView
/// cannot render those at all.
class UrbanDevelopmentWebView extends StatefulWidget {
  const UrbanDevelopmentWebView({super.key});

  @override
  State<UrbanDevelopmentWebView> createState() =>
      _UrbanDevelopmentWebViewState();
}

class _UrbanDevelopmentWebViewState extends State<UrbanDevelopmentWebView> {
  late final WebViewController _controller;

  bool _isLoading = true;

  /// Set only when the page itself fails (no network at all, etc.) so the user
  /// never stares at a blank screen. Certificate problems no longer land here.
  String? _errorTitle;
  String? _errorDetail;

  /// Some devices never fire onPageFinished nor an error. Fall back to the
  /// error card so the spinner can't run forever.
  Timer? _loadTimeout;

  static const _initialUrl = 'https://upulbots.in/';
  static const _loadTimeoutDuration = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController.fromPlatformCreationParams(
      _platformParams(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Without this some devices paint the WebView black before first frame.
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => _setLoading(true),
          onPageFinished: (String url) => _setLoading(false),

          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);

            // Anything the WebView can render - any host, any depth, http or
            // https - is allowed through untouched.
            if (uri == null || uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }

            // tel:, mailto:, upi:, intent:, whatsapp: ... only the OS can open
            // these, so pass them on instead of failing inside the WebView.
            _openExternally(uri);
            return NavigationDecision.prevent;
          },

          onWebResourceError: (WebResourceError error) {
            // Sub-resource failures (a font, a CDN file) must never blank the
            // page - report only failures of the page itself.
            if (error.isForMainFrame == false) {
              return;
            }
            final code = error.errorType?.name ?? 'code ${error.errorCode}';
            _setError(
              'Page could not be loaded',
              '${error.description} ($code)',
            );
          },

          onSslAuthError: (SslAuthError error) {
            // Deliberately continue past certificate problems (untrusted root
            // on older devices, wrong device date, self-signed staging certs)
            // so the portal opens everywhere.
            error.proceed();
          },
        ),
      );

    _applyAndroidSettings();
    _load();
  }

  /// Platform params that switch off the built-in media/inline restrictions.
  PlatformWebViewControllerCreationParams _platformParams() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    return const PlatformWebViewControllerCreationParams();
  }

  /// Android-only knobs: allow http content inside an https page and let the
  /// portal play media without a tap.
  void _applyAndroidSettings() {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMixedContentMode(MixedContentMode.alwaysAllow);
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setAllowFileAccess(true);
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  void _load() {
    setState(() {
      _errorTitle = null;
      _errorDetail = null;
      _isLoading = true;
    });
    _restartTimeout();
    _controller.loadRequest(Uri.parse(_initialUrl));
  }

  void _restartTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(_loadTimeoutDuration, () {
      if (mounted && _isLoading) {
        _setError(
          'Taking too long to load',
          'The portal did not respond. Check your internet connection, or '
              'update Android System WebView from the Play Store.',
        );
      }
    });
  }

  void _setLoading(bool loading) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = loading;
      if (loading) {
        _errorTitle = null;
        _errorDetail = null;
      }
    });
    if (loading) {
      _restartTimeout();
    } else {
      _loadTimeout?.cancel();
    }
  }

  void _setError(String title, String detail) {
    if (!mounted) {
      return;
    }
    _loadTimeout?.cancel();
    setState(() {
      _isLoading = false;
      _errorTitle = title;
      _errorDetail = detail;
    });
  }

  Future<void> _openExternally(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No app available to open ${uri.scheme}: links'),
        ),
      );
    }
  }

  /// Handle Android back button and AppBar back button
  Future<void> _handleBack() async {
    final bool canGoBack = await _controller.canGoBack();

    if (canGoBack) {
      // First go back inside WebView history
      await _controller.goBack();
    } else {
      // WebView history finished -> go back to Dashboard
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Don't pop Flutter screen immediately.
      // First check WebView history.
      canPop: false,

      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },

      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),

          title: Text(
            'OTS',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),

          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFE67514),
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),

        body: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),

            if (_errorTitle != null)
              Positioned.fill(child: _buildError())
            else if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE67514),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: Color(0xFFE67514),
          ),
          const SizedBox(height: 16),
          Text(
            _errorTitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorDetail ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Retry', style: GoogleFonts.poppins(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67514),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
