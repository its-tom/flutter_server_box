import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/locale.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/model/app/tab.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

import '../../core/utils/misc.dart';
import '../../core/utils/platform.dart';
import '../../core/update.dart';
import '../../core/utils/ui.dart';
import '../../data/provider/app.dart';
import '../../data/provider/server.dart';
import '../../data/res/build_data.dart';
import '../../data/res/color.dart';
import '../../data/res/path.dart';
import '../../data/res/ui.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/future_widget.dart';
import '../widget/round_rect_card.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final themeKey = GlobalKey<PopupMenuButtonState<int>>();
  final startPageKey = GlobalKey<PopupMenuButtonState<int>>();
  final updateIntervalKey = GlobalKey<PopupMenuButtonState<int>>();
  final maxRetryKey = GlobalKey<PopupMenuButtonState<int>>();
  final fontSizeKey = GlobalKey<PopupMenuButtonState<double>>();
  final localeKey = GlobalKey<PopupMenuButtonState<String>>();
  final editorThemeKey = GlobalKey<PopupMenuButtonState<String>>();

  late final SettingStore _setting;
  late final ServerProvider _serverProvider;
  late MediaQueryData _media;
  late S _s;

  final _selectedColorValue = ValueNotifier(0);
  final _launchPageIdx = ValueNotifier(0);
  final _nightMode = ValueNotifier(0);
  final _maxRetryCount = ValueNotifier(0);
  final _updateInterval = ValueNotifier(0);
  final _fontSize = ValueNotifier(0.0);
  final _localeCode = ValueNotifier('');
  final _editorTheme = ValueNotifier('');

  final _pushToken = ValueNotifier<String?>(null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
    _localeCode.value = _setting.locale.fetch() ?? _s.localeName;
  }

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    _setting = locator<SettingStore>();
    _launchPageIdx.value = _setting.launchPage.fetch()!;
    _nightMode.value = _setting.themeMode.fetch()!;
    _updateInterval.value = _setting.serverStatusUpdateInterval.fetch()!;
    _maxRetryCount.value = _setting.maxRetryCount.fetch()!;
    _selectedColorValue.value = _setting.primaryColor.fetch()!;
    _fontSize.value = _setting.termFontSize.fetch()!;
    _editorTheme.value = _setting.editorTheme.fetch()!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.setting),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        children: [
          // App
          _buildTitle('App'),
          _buildApp(),
          // Server
          _buildTitle(_s.server),
          _buildServer(),
          // SSH
          _buildTitle('SSH'),
          _buildSSH(),
          // Editor
          _buildTitle(_s.editor),
          _buildEditor(),
          const SizedBox(height: 37),
        ],
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 23, bottom: 17),
      child: Center(
        child: Text(
          text,
          style: grey,
        ),
      ),
    );
  }

  Widget _buildApp() {
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      _buildLaunchPage(),
      _buildCheckUpdate(),
    ];
    if (isIOS) {
      children.add(_buildPushToken());
    }
    if (isAndroid) {
      children.add(_buildBgRun());
    }
    return Column(
      children: children.map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildServer() {
    return Column(
      children: [
        _buildUpdateInterval(),
        _buildMaxRetry(),
        _buildDiskIgnorePath(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildSSH() {
    return Column(
      children: [
        _buildFont(),
        _buildTermFontSize(),
        _buildSSHVirtualKeyAutoOff(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildEditorTheme(),
      ].map((e) => RoundRectCard(e)).toList(),
    );
  }

  Widget _buildCheckUpdate() {
    return Consumer<AppProvider>(
      builder: (_, app, __) {
        String display;
        if (app.newestBuild != null) {
          if (app.newestBuild! > BuildData.build) {
            display = _s.versionHaveUpdate(app.newestBuild!);
          } else {
            display = _s.versionUpdated(BuildData.build);
          }
        } else {
          display = _s.versionUnknownUpdate(BuildData.build);
        }
        return ListTile(
          trailing: const Icon(Icons.keyboard_arrow_right),
          title: Text(
            display,
          ),
          onTap: () => doUpdate(context, force: true),
        );
      },
    );
  }

  Widget _buildUpdateInterval() {
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text('$index ${_s.second}'),
      ),
      growable: false,
    ).toList();

    return ListTile(
      title: Text(
        _s.updateServerStatusInterval,
      ),
      subtitle: Text(
        _s.willTakEeffectImmediately,
        style: grey,
      ),
      onTap: () {
        updateIntervalKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
        listenable: _updateInterval,
        build: () => PopupMenuButton(
          key: updateIntervalKey,
          itemBuilder: (_) => items,
          initialValue: _updateInterval.value,
          onSelected: (int val) {
            _updateInterval.value = val;
            _setting.serverStatusUpdateInterval.put(val);
            _serverProvider.startAutoRefresh();
            if (val == 0) {
              showSnackBar(context, Text(_s.updateIntervalEqual0));
            }
          },
          child: Text(
            '${_updateInterval.value} ${_s.second}',
            style: textSize15,
          ),
        ),
      ),
    );
  }

  Widget _buildAppColor() {
    return ListTile(
      trailing: ClipOval(
        child: Container(
          color: primaryColor,
          height: 27,
          width: 27,
        ),
      ),
      title: Text(
        _s.appPrimaryColor,
      ),
      onTap: () async {
        await showRoundDialog(
          context: context,
          title: Text(_s.appPrimaryColor),
          child: MaterialColorPicker(
            shrinkWrap: true,
            allowShades: true,
            onColorChange: (color) {
              _selectedColorValue.value = color.value;
            },
            selectedColor: primaryColor,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _setting.primaryColor.put(_selectedColorValue.value);
                Navigator.pop(context);
                _showRestartSnackbar();
              },
              child: Text(_s.ok),
            )
          ],
        );
      },
    );
  }

  Widget _buildLaunchPage() {
    final items = AppTab.values
        .map(
          (e) => PopupMenuItem(
            value: e.index,
            child: Text(tabTitleName(context, e)),
          ),
        )
        .toList();

    return ListTile(
      title: Text(
        _s.launchPage,
      ),
      onTap: () {
        startPageKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
          listenable: _launchPageIdx,
          build: () => PopupMenuButton(
                key: startPageKey,
                itemBuilder: (BuildContext context) => items,
                initialValue: _launchPageIdx.value,
                onSelected: (int idx) {
                  _launchPageIdx.value = idx;
                  _setting.launchPage.put(_launchPageIdx.value);
                },
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: _media.size.width * 0.35),
                  child: Text(
                    tabTitleName(context, AppTab.values[_launchPageIdx.value]),
                    textAlign: TextAlign.right,
                    style: textSize15,
                  ),
                ),
              )),
    );
  }

  Widget _buildMaxRetry() {
    final items = List.generate(
      10,
      (index) => PopupMenuItem(
        value: index,
        child: Text('$index ${_s.times}'),
      ),
      growable: false,
    ).toList();
    final help =
        _maxRetryCount.value == 0 ? _s.maxRetryCountEqual0 : _s.canPullRefresh;

    return ListTile(
      title: Text(
        _s.maxRetryCount,
        textAlign: TextAlign.start,
      ),
      subtitle: Text(help, style: grey),
      onTap: () {
        maxRetryKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
        build: () => PopupMenuButton(
          key: maxRetryKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _maxRetryCount.value,
          onSelected: (int val) {
            _maxRetryCount.value = val;
            _setting.maxRetryCount.put(_maxRetryCount.value);
          },
          child: Text(
            '${_maxRetryCount.value} ${_s.times}',
            style: textSize15,
          ),
        ),
        listenable: _maxRetryCount,
      ),
    );
  }

  Widget _buildThemeMode() {
    final items = ThemeMode.values
        .map(
          (e) => PopupMenuItem(
            value: e.index,
            child: Text(_buildThemeModeStr(e.index)),
          ),
        )
        .toList();
    // Issue #57
    final len = ThemeMode.values.length;
    items.add(PopupMenuItem(value: len, child: Text(_buildThemeModeStr(len))));

    return ListTile(
      title: Text(
        _s.themeMode,
      ),
      onTap: () {
        themeKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
        listenable: _nightMode,
        build: () => PopupMenuButton(
          key: themeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _nightMode.value,
          onSelected: (int idx) {
            _nightMode.value = idx;
            _setting.themeMode.put(_nightMode.value);
          },
          child: Text(
            _buildThemeModeStr(_nightMode.value),
            style: textSize15,
          ),
        ),
      ),
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return _s.light;
      case 2:
        return _s.dark;
      case 3:
        return 'AMOLED';
      default:
        return _s.auto;
    }
  }

  Widget _buildPushToken() {
    return ListTile(
      title: Text(
        _s.pushToken,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (_pushToken.value != null) {
            copy2Clipboard(_pushToken.value!);
            showSnackBar(context, Text(_s.success));
          } else {
            showSnackBar(context, Text(_s.getPushTokenFailed));
          }
        },
      ),
      subtitle: FutureWidget<String?>(
        future: getToken(),
        loading: Text(_s.gettingToken),
        error: (error, trace) => Text('${_s.error}: $error'),
        noData: Text(_s.nullToken),
        success: (text) {
          _pushToken.value = text;
          return Text(
            text ?? _s.nullToken,
            style: grey,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        },
      ),
    );
  }

  Widget _buildFont() {
    final fontName = getFileName(_setting.fontPath.fetch());
    return ListTile(
      title: Text(_s.font),
      trailing: Text(
        fontName ?? _s.notSelected,
        style: textSize15,
      ),
      onTap: () {
        showRoundDialog(
          context: context,
          title: Text(_s.font),
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(_s.pickFile),
            ),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                _showRestartSnackbar();
              },
              child: Text(_s.clear),
            )
          ],
        );
      },
    );
  }

  Future<void> _pickFontFile() async {
    final path = await pickOneFile();
    if (path != null) {
      // iOS can't copy file to app dir, so we need to use the original path
      if (isIOS) {
        _setting.fontPath.put(path);
      } else {
        final fontDir_ = await fontDir;
        final fontFile = File(path);
        final newPath = '${fontDir_.path}/${path.split('/').last}';
        await fontFile.copy(newPath);
        _setting.fontPath.put(newPath);
      }

      context.pop();
      _showRestartSnackbar();
      return;
    }
    showSnackBar(context, Text(_s.failed));
  }

  void _showRestartSnackbar() {
    showSnackBarWithAction(
      context,
      '${_s.success}\n${_s.needRestart}',
      _s.restart,
      () => rebuildAll(context),
    );
  }

  Widget _buildBgRun() {
    return ListTile(
      title: Text(_s.bgRun),
      trailing: buildSwitch(context, _setting.bgRun),
    );
  }

  Widget _buildTermFontSize() {
    return ValueBuilder(
      listenable: _fontSize,
      build: () => ListTile(
        title: Text(_s.fontSize),
        trailing: Text(
          _fontSize.value.toString(),
          style: textSize15,
        ),
        onTap: () {
          final ctrller =
              TextEditingController(text: _fontSize.value.toString());
          showRoundDialog(
            context: context,
            title: Text(_s.fontSize),
            child: Input(
              controller: ctrller,
              type: TextInputType.number,
              icon: Icons.font_download,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.pop();
                  final fontSize = double.tryParse(ctrller.text);
                  if (fontSize == null) {
                    showRoundDialog(context: context, child: Text(_s.failed));
                    return;
                  }
                  _fontSize.value = fontSize;
                  _setting.termFontSize.put(_fontSize.value);
                },
                child: Text(_s.ok),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiskIgnorePath() {
    final paths = _setting.diskIgnorePath.fetch()!;
    return ListTile(
      title: Text(_s.diskIgnorePath),
      trailing: Text(_s.edit, style: textSize15),
      onTap: () {
        final ctrller = TextEditingController(text: json.encode(paths));
        void onSubmit() {
          try {
            final list = List<String>.from(json.decode(ctrller.text));
            _setting.diskIgnorePath.put(list);
            context.pop();
            showSnackBar(context, Text(_s.success));
          } catch (e) {
            showSnackBar(context, Text(e.toString()));
          }
        }

        showRoundDialog(
          context: context,
          title: Text(_s.diskIgnorePath),
          child: Input(
            controller: ctrller,
            label: 'JSON',
            type: TextInputType.visiblePassword,
            maxLines: 3,
            onSubmitted: (_) => onSubmit(),
          ),
          actions: [
            TextButton(onPressed: onSubmit, child: Text(_s.ok)),
          ],
        );
      },
    );
  }

  Widget _buildLocale() {
    final items = S.supportedLocales
        .map(
          (e) => PopupMenuItem<String>(
            value: e.name,
            child: Text(e.name),
          ),
        )
        .toList();
    return ListTile(
      title: Text(_s.language),
      onTap: () {
        localeKey.currentState?.showButtonMenu();
      },
      trailing: ValueBuilder(
          listenable: _localeCode,
          build: () => PopupMenuButton(
                key: localeKey,
                itemBuilder: (BuildContext context) => items,
                initialValue: _localeCode.value,
                onSelected: (String idx) {
                  _localeCode.value = idx;
                  _setting.locale.put(idx);
                  _showRestartSnackbar();
                },
                child: Text(
                  _s.languageName,
                  style: textSize15,
                ),
              )),
    );
  }

  Widget _buildSSHVirtualKeyAutoOff() {
    return ListTile(
      title: Text(_s.sshVirtualKeyAutoOff),
      subtitle: const Text('Ctrl & Alt', style: grey),
      trailing: buildSwitch(context, _setting.sshVirtualKeyAutoOff),
    );
  }

  Widget _buildEditorTheme() {
    final items = themeMap.keys.map(
      (key) {
        return PopupMenuItem<String>(
          value: key,
          child: Text(key),
        );
      },
    ).toList();
    return ListTile(
      title: Text("${_s.editor} ${_s.theme}"),
      trailing: ValueBuilder(
        listenable: _editorTheme,
        build: () => PopupMenuButton(
          key: editorThemeKey,
          itemBuilder: (BuildContext context) => items,
          initialValue: _editorTheme.value,
          onSelected: (String idx) {
            _editorTheme.value = idx;
            _setting.editorTheme.put(idx);
          },
          child: Text(
            _editorTheme.value,
            style: textSize15,
          ),
        ),
      ),
      onTap: () {
        editorThemeKey.currentState?.showButtonMenu();
      },
    );
  }
}
