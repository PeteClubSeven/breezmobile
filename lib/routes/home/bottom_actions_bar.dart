import 'dart:async';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/account/add_fund_vendor_model.dart';
import 'package:breez/bloc/account/add_funds_bloc.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/bloc/invoice/invoice_bloc.dart';
import 'package:breez/bloc/invoice/invoice_model.dart';
import 'package:breez/bloc/lnurl/lnurl_bloc.dart';
import 'package:breez/bloc/lsp/lsp_bloc.dart';
import 'package:breez/bloc/lsp/lsp_model.dart';
import 'package:breez/routes/spontaneous_payment/spontaneous_payment_page.dart';
import 'package:breez/services/injector.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/utils/dynamic_fees.dart';
import 'package:breez/utils/exceptions.dart';
import 'package:breez/utils/stream_builder_extensions.dart';
import 'package:breez/widgets/enter_payment_info_dialog.dart';
import 'package:breez/widgets/escher_dialog.dart';
import 'package:breez/widgets/loader.dart';
import 'package:breez/widgets/lsp_fee.dart';
import 'package:breez/widgets/route.dart';
import 'package:breez/widgets/warning_box.dart';
import 'package:breez_translations/breez_translations_locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class BottomActionsBar extends StatefulWidget {
  final GlobalKey firstPaymentItemKey;

  const BottomActionsBar(this.firstPaymentItemKey);

  @override
  State<BottomActionsBar> createState() => _BottomActionsBarState();
}

class _BottomActionsBarState extends State<BottomActionsBar> {
  @override
  Widget build(BuildContext context) {
    final texts = context.texts();
    AutoSizeGroup actionsGroup = AutoSizeGroup();

    return BottomAppBar(
      child: Container(
        height: 60,
        color: Theme.of(context).bottomAppBarTheme.color,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _Action(
              onPress: () => _showSendOptions(),
              group: actionsGroup,
              text: texts.bottom_action_bar_send,
              iconAssetPath: "src/icon/send-action.png",
            ),
            Container(
              width: 64,
            ),
            StreamBuilder<AccountModel>(
              stream: AppBlocsProvider.of<AccountBloc>(context).accountStream,
              builder: (context, accountSnapshot) {
                final account = accountSnapshot.data;
                return _Action(
                  onPress: () => showReceiveOptions(context, account),
                  group: actionsGroup,
                  text: texts.bottom_action_bar_receive,
                  iconAssetPath: "src/icon/receive-action.png",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future _showSendOptions() async {
    final texts = context.texts();
    final invoiceBloc = AppBlocsProvider.of<InvoiceBloc>(context);
    final accBloc = AppBlocsProvider.of<AccountBloc>(context);
    final lnurlBloc = AppBlocsProvider.of<LNUrlBloc>(context);
    final accountBloc = AppBlocsProvider.of<AccountBloc>(context);

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final themeData = Theme.of(ctx);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: themeData.appBarTheme.systemOverlayStyle.copyWith(
            systemNavigationBarColor: themeData.canvasColor,
          ),
          child: StreamBuilder2<Future<DecodedClipboardData>, AccountModel>(
            streamA: invoiceBloc.decodedClipboardStream,
            streamB: accountBloc.accountStream,
            builder: (context, clipBoardSnapshot, accountSnapshot) {
              final account = accountSnapshot.data;
              if (!accountSnapshot.hasData) {
                return const SizedBox();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 8.0),
                  ListTile(
                    enabled: account.connected,
                    leading: _ActionImage(
                      iconAssetPath: "src/icon/paste.png",
                      enabled: account.connected,
                    ),
                    title: Text(
                      texts.bottom_action_bar_paste_invoice,
                      style: theme.bottomSheetTextStyle,
                    ),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      if (clipBoardSnapshot.hasData) {
                        await clipBoardSnapshot.data.then((clipboardData) {
                          if (clipboardData != null) {
                            if (clipboardData.type == "lnurl" ||
                                clipboardData.type == "lightning-address") {
                              lnurlBloc.lnurlInputSink.add(clipboardData.data);
                            } else if (clipboardData.type == "invoice") {
                              invoiceBloc.decodeInvoiceSink.add(
                                clipboardData.data,
                              );
                            } else if (clipboardData.type == "nodeID") {
                              navigator.push(
                                FadeInRoute(
                                  builder: (_) => SpontaneousPaymentPage(
                                    clipboardData.data,
                                    widget.firstPaymentItemKey,
                                  ),
                                ),
                              );
                            }
                          } else {
                            _showEnterPaymentInfoDialog();
                          }
                        });
                      } else {
                        _showEnterPaymentInfoDialog();
                      }
                    },
                  ),
                  Divider(
                    height: 0.0,
                    color: Colors.white.withOpacity(0.2),
                    indent: 72.0,
                  ),
                  ListTile(
                    enabled: account.connected,
                    leading: _ActionImage(
                      iconAssetPath: "src/icon/connect_to_pay.png",
                      enabled: account.connected,
                    ),
                    title: Text(
                      texts.bottom_action_bar_connect_to_pay,
                      style: theme.bottomSheetTextStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed("/connect_to_pay");
                    },
                  ),
                  Divider(
                    height: 0.0,
                    color: Colors.white.withOpacity(0.2),
                    indent: 72.0,
                  ),
                  ListTile(
                    enabled: account.connected,
                    leading: _ActionImage(
                        iconAssetPath: "src/icon/bitcoin.png",
                        enabled: account.connected),
                    title: Text(
                      texts.bottom_action_bar_send_btc_address,
                      style: theme.bottomSheetTextStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed("/withdraw_funds");
                    },
                  ),
                  StreamBuilder(
                    stream: accBloc.accountSettingsStream,
                    builder: (context, settingsSnapshot) {
                      if (!settingsSnapshot.hasData) {
                        return const SizedBox();
                      }
                      AccountSettings settings = settingsSnapshot.data;
                      if (settings.isEscherEnabled) {
                        return Column(
                          children: [
                            Divider(
                              height: 0.0,
                              color: Colors.white.withOpacity(0.2),
                              indent: 72.0,
                            ),
                            ListTile(
                              enabled: account.connected,
                              leading: _ActionImage(
                                  iconAssetPath: "src/icon/escher.png",
                                  enabled: account.connected),
                              title: Text(
                                texts.bottom_action_bar_escher,
                                style: theme.bottomSheetTextStyle,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  useRootNavigator: false,
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => EscherDialog(
                                    context,
                                    accBloc,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      } else {
                        return const SizedBox();
                      }
                    },
                  ),
                  const SizedBox(height: 8.0)
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<dynamic> _showEnterPaymentInfoDialog() {
    final invoiceBloc = AppBlocsProvider.of<InvoiceBloc>(context);
    final lnurlBloc = AppBlocsProvider.of<LNUrlBloc>(context);
    return showDialog(
      useRootNavigator: false,
      context: context,
      barrierDismissible: false,
      builder: (_) => EnterPaymentInfoDialog(
        context,
        invoiceBloc,
        lnurlBloc,
        widget.firstPaymentItemKey,
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String text;
  final AutoSizeGroup group;
  final String iconAssetPath;
  final Function() onPress;

  const _Action({
    Key key,
    this.text,
    this.group,
    this.iconAssetPath,
    this.onPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        onPressed: onPress,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.bottomAppBarBtnStyle.copyWith(
            fontSize: 13.5 / MediaQuery.of(context).textScaleFactor,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _ActionImage extends StatelessWidget {
  final String iconAssetPath;
  final String svgAssetPath;
  final bool enabled;

  const _ActionImage({
    Key key,
    this.iconAssetPath,
    this.svgAssetPath,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Theme.of(context).disabledColor;
    const fit = BoxFit.contain;
    const height = 24.0;
    const width = 24.0;
    if (svgAssetPath != null && svgAssetPath.isNotEmpty) {
      return SvgPicture.asset(
        svgAssetPath,
        colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
        fit: BoxFit.contain,
        width: width,
        height: height,
      );
    }
    return Image(
      image: AssetImage(iconAssetPath),
      color: color,
      fit: fit,
      width: width,
      height: height,
    );
  }
}

Future showReceiveOptions(
  BuildContext parentContext,
  AccountModel account,
) {
  final texts = parentContext.texts();
  AddFundsBloc addFundsBloc = BlocProvider.of<AddFundsBloc>(parentContext);
  LSPBloc lspBloc = AppBlocsProvider.of<LSPBloc>(parentContext);

  return showModalBottomSheet(
    context: parentContext,
    builder: (ctx) {
      final themeData = Theme.of(ctx);

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: themeData.appBarTheme.systemOverlayStyle.copyWith(
          systemNavigationBarColor: themeData.canvasColor,
        ),
        child: StreamBuilder<LSPStatus>(
          stream: lspBloc.lspStatusStream,
          builder: (context, lspSnapshot) {
            return StreamBuilder<List<AddFundVendorModel>>(
              stream: addFundsBloc.availableVendorsStream,
              builder: (context, snapshot) {
                final themeData = Theme.of(context);

                if (snapshot.data == null) {
                  return const SizedBox();
                }

                List<Widget> children =
                    snapshot.data.where((v) => v.isAllowed).map(
                  (v) {
                    return Column(
                      children: [
                        Divider(
                          height: 0.0,
                          color: themeData.dividerColor.withOpacity(0.2),
                          indent: 72.0,
                        ),
                        ListTile(
                          enabled: v.enabled &&
                              (account.connected || !v.requireActiveChannel),
                          leading: _ActionImage(
                            iconAssetPath: v.icon,
                            enabled:
                                account.connected || !v.requireActiveChannel,
                          ),
                          title: Text(
                            v.shortName ?? v.name,
                            style: theme.bottomSheetTextStyle,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            if (v.refreshLSP || v.showLSPFee) {
                              final navigator = Navigator.of(context);
                              var loaderRoute = createLoaderRoute(context);
                              try {
                                navigator.push(loaderRoute);

                                fetchLSPList(lspBloc).then(
                                  (lspList) {
                                    if (loaderRoute.isActive) {
                                      navigator.removeRoute(loaderRoute);
                                    }
                                    var refreshedLSP = lspList.firstWhere(
                                      (lsp) =>
                                          lsp.lspID ==
                                          lspSnapshot.data.selectedLSP,
                                    );
                                    (v.showLSPFee)
                                        ? promptLSPFeeAndNavigate(
                                            parentContext,
                                            account,
                                            refreshedLSP
                                                .longestValidOpeningFeeParams,
                                            v.route,
                                          )
                                        : navigator.pushNamed(v.route);
                                  },
                                  onError: (e) {
                                    if (loaderRoute.isActive) {
                                      navigator.removeRoute(loaderRoute);
                                    }
                                    _showError(parentContext, e);
                                  },
                                );
                              } catch (e) {
                                if (loaderRoute.isActive) {
                                  navigator.removeRoute(loaderRoute);
                                }
                                _showError(parentContext, e);
                              }
                            } else {
                              Navigator.of(context).pushNamed(v.route);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ).toList();

                // We need an option to scan Satscards on iOS. Unnecessary on Android due to background scanning
                final nfc = ServiceInjector().nfc;
                if (Platform.isIOS && nfc.isAvailable) {
                  children.add(
                    Column(
                      children: <Widget>[
                        Divider(
                          height: 0.0,
                          color: themeData.dividerColor.withOpacity(0.2),
                          indent: 72.0,
                        ),
                        ListTile(
                          leading: const _ActionImage(
                            enabled: true,
                            svgAssetPath: "src/icon/nfc.svg",
                          ),
                          title: Text(
                            texts.bottom_action_bar_sweep_satscard,
                            style: theme.bottomSheetTextStyle,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            ServiceInjector().nfc.startSession(
                                  autoClose: false,
                                  satscardOnly: true,
                                  iosAlert: texts
                                      .bottom_action_bar_sweep_satscard_nfc_prompt,
                                );
                          },
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 8.0),
                    ListTile(
                      enabled: true,
                      leading: const _ActionImage(
                        iconAssetPath: "src/icon/paste.png",
                        enabled: true,
                      ),
                      title: Text(
                        texts.bottom_action_bar_receive_invoice,
                        style: theme.bottomSheetTextStyle,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed("/create_invoice");
                      },
                    ),
                    ...children,
                    account.warningMaxChanReserveAmount == 0
                        ? const SizedBox(height: 8.0)
                        : WarningBox(
                            boxPadding: const EdgeInsets.all(16),
                            contentPadding: const EdgeInsets.all(8),
                            child: AutoSizeText(
                              texts.bottom_action_bar_warning_balance_title(
                                account.currency.format(
                                  account.warningMaxChanReserveAmount,
                                ),
                              ),
                              maxFontSize:
                                  themeData.textTheme.titleMedium.fontSize,
                              style: themeData.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ],
                );
              },
            );
          },
        ),
      );
    },
  );
}

void _showError(BuildContext context, Object e) {
  final texts = context.texts();
  final themeData = Theme.of(context);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(extractExceptionMessage(e, texts: texts)),
      actions: [
        TextButton(
          child: Text(
            texts.flushbar_default_action,
            style: themeData.primaryTextTheme.labelLarge,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}
