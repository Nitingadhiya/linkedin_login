import 'dart:io';

import 'package:flutter/material.dart';
import 'package:linkedin_login/src/utils/configuration.dart';
import 'package:linkedin_login/src/utils/logger.dart';
import 'package:linkedin_login/src/utils/startup/graph.dart';
import 'package:linkedin_login/src/utils/startup/injector.dart';
import 'package:linkedin_login/src/webview/actions.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Class will fetch code and access token from the user
/// It will show web view so that we can access to linked in auth page
/// Please take into consideration to use [onWebViewCreated] only in testing
/// purposes
@immutable
class LinkedInWebViewHandler extends StatefulWidget {
  const LinkedInWebViewHandler({
    required this.onUrlMatch,
    this.appBar,
    this.destroySession = false,
    this.onCookieClear,
    this.onWebViewCreated,
    this.useVirtualDisplay = false,
    this.showLoading = false,
    final Key? key,
  }) : super(key: key);

  final bool? destroySession;
  final PreferredSizeWidget? appBar;
  final ValueChanged<WebViewController>? onWebViewCreated;
  final ValueChanged<DirectionUrlMatch> onUrlMatch;
  final ValueChanged<bool>? onCookieClear;
  final bool useVirtualDisplay;
  final bool showLoading;

  @override
  State createState() => _LinkedInWebViewHandlerState();
}

class _LinkedInWebViewHandlerState extends State<LinkedInWebViewHandler> {
  WebViewController? webViewController;
  final CookieManager cookieManager = CookieManager();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid && widget.useVirtualDisplay) {
      WebView.platform = AndroidWebView();
    }

    if (widget.destroySession!) {
      log('LinkedInAuth-steps: cache clearing... ');
      cookieManager.clearCookies().then((final value) {
        widget.onCookieClear?.call(true);
        log('LinkedInAuth-steps: cache clearing... DONE');
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    final viewModel = _ViewModel.from(context);
    return Scaffold(
      appBar: widget.appBar,
      body: Stack(
        children: [
          Builder(
            builder: (final BuildContext context) {
              return WebView(
                initialUrl: viewModel.initialUrl(),
                javascriptMode: JavascriptMode.unrestricted,
                onWebViewCreated: (final WebViewController webViewController) async {
                  log('LinkedInAuth-steps: onWebViewCreated ... ');

                  widget.onWebViewCreated?.call(webViewController);

                  log('LinkedInAuth-steps: onWebViewCreated ... DONE');
                },
                navigationDelegate: (final NavigationRequest request) async {
                  log('LinkedInAuth-steps: navigationDelegate ... ');
                  final isMatch = viewModel.isUrlMatchingToRedirection(
                    context,
                    request.url,
                  );
                  log(
                    'LinkedInAuth-steps: navigationDelegate '
                    '[currentUrL: ${request.url}, isCurrentMatch: $isMatch]',
                  );

                  if (isMatch) {
                    widget.onUrlMatch(viewModel.getUrlConfiguration(request.url));
                    log('Navigation delegate prevent... done');
                    return NavigationDecision.prevent;
                  }

                  return NavigationDecision.navigate;
                },
                onPageFinished: (final val) async {
                  if (widget.showLoading == true && isLoading == true) {
                    //show until ui build
                    await Future.delayed(const Duration(seconds: 2));
                    setState(() {
                      isLoading = false;
                    });
                  }
                },
              );
            },
          ),
          if (widget.showLoading == true && isLoading == true)
            const Center(
              child: CircularProgressIndicator(),
            )
        ],
      ),
    );
  }
}

@immutable
class _ViewModel {
  const _ViewModel._({
    required this.graph,
  });

  factory _ViewModel.from(final BuildContext context) => _ViewModel._(
        graph: InjectorWidget.of(context),
      );

  final Graph? graph;

  DirectionUrlMatch getUrlConfiguration(final String url) {
    final type = graph!.linkedInConfiguration is AccessCodeConfiguration ? WidgetType.fullProfile : WidgetType.authCode;
    return DirectionUrlMatch(url: url, type: type);
  }

  String initialUrl() => graph!.linkedInConfiguration.initialUrl;

  bool isUrlMatchingToRedirection(
    final BuildContext context,
    final String url,
  ) {
    return graph!.linkedInConfiguration.isCurrentUrlMatchToRedirection(url);
  }
}
