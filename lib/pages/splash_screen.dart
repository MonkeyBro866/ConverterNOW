import 'package:collection/collection.dart';
import 'package:converterpro/app_router.dart';
import 'package:converterpro/models/order.dart';
import 'package:converterpro/data/default_order.dart';
import 'package:converterpro/data/property_unit_maps.dart';
import 'package:converterpro/models/settings.dart';
import 'package:converterpro/styles/consts.dart';
import 'package:converterpro/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:umeng_ad_flutter/umeng_ad_flutter.dart';
import 'dart:async';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _showSplash = true;
  bool _isDataReady = false;
  bool _adFlowCompleted = false;
  bool _hasNavigated = false;
  Timer? _splashTimer;
  ProviderSubscription<bool>? _dataLoadedSubscription;

  @override
  void initState() {
    super.initState();

    _listenForDataLoading();

    // 等待 Widget 构建完成后再显示开屏广告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSplashAd();
    });

    // 启动3秒延时计时器作为备用
    _splashTimer = Timer(const Duration(seconds: 3), _handleSplashTimeout);
  }

  void _listenForDataLoading() {
    final alreadyLoaded = ref.read(isEverythingLoadedProvider);
    if (alreadyLoaded) {
      _isDataReady = true;
    }

    _dataLoadedSubscription = ref.listenManual<bool>(
      isEverythingLoadedProvider,
      (previous, next) {
        if (next && mounted) {
          setState(() {
            _isDataReady = true;
          });
          _maybeNavigateToMainPage();
        }
      },
    );
  }

  void _handleSplashTimeout() {
    if (!mounted || _adFlowCompleted) return;
    _dismissSplashVisual();
    _completeAdFlow();
  }

  void _showSplashAd() async {
    if (!mounted) {
      print('开屏广告: Widget 未挂载，取消显示');
      return;
    }

    print('开屏广告: 开始加载广告，adSlotId: 100004449');
    // 给原生 SDK 预留初始化时间
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await UmengAdFlutter.showSplashAd(
        adSlotId: '100004449',
        onAdLoaded: () {
          print('开屏广告: 加载成功回调');
          // 广告加载成功后，SDK 会自动显示广告，此时启动页会被广告覆盖
        },
        onAdDisplayed: () {
          print('开屏广告: 显示回调');
          // 广告显示时，隐藏启动页（因为广告已经覆盖了启动页）
          if (mounted) {
            _dismissSplashVisual();
          }
        },
        onAdClicked: () {
          print('开屏广告: 被点击');
        },
        onAdClosed: () {
          print('开屏广告: 关闭回调');
          // 广告关闭后，完成广告流程并导航到主页面
          if (mounted) {
            _completeAdFlow();
          }
        },
        onAdError: (error) {
          print('开屏广告: 错误回调 - code: ${error.code}, message: ${error.message}');
          // 广告加载失败时，隐藏启动页并直接进入主页面
          if (mounted) {
            _dismissSplashVisual();
            _completeAdFlow();
          }
        },
      );
      print('开屏广告: showSplashAd 调用完成');
    } catch (e, stackTrace) {
      print('开屏广告: 异常 - $e');
      print('开屏广告: 堆栈跟踪 - $stackTrace');
      if (mounted) {
        _dismissSplashVisual();
        _completeAdFlow();
      }
    }
  }

  void _dismissSplashVisual() {
    if (!mounted || !_showSplash) return;
    setState(() {
      _showSplash = false;
    });
  }

  void _completeAdFlow() {
    if (!mounted || _adFlowCompleted) return;
    _splashTimer?.cancel();
    setState(() {
      _adFlowCompleted = true;
    });
    _maybeNavigateToMainPage();
  }

  void _maybeNavigateToMainPage() {
    if (_hasNavigated || !_adFlowCompleted || !_isDataReady) {
      return;
    }
    _hasNavigated = true;
    _navigateToMainPage();
  }

  void _navigateToMainPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final conversionsOrderDrawer =
            ref.read(PropertiesOrderNotifier.provider).value!;

        initializeQuickAction(
          conversionsOrderDrawer: conversionsOrderDrawer,
          propertyUiMap: getPropertyUiMap(context),
          onActionSelection: (String shortcut) {
            final selectedProperty = defaultPropertiesOrder
                .firstWhereOrNull((e) => e.toString() == shortcut);
            if (selectedProperty != null) {
              context.go('/conversions/${selectedProperty.toKebabCase()}');
            }
          },
        );

        GoRouter.of(context).go(
          MediaQuery.sizeOf(context).width > pixelFixedDrawer ||
                  !ref.read(propertySelectionOnStartupProvider).value!
              ? '/conversions/${conversionsOrderDrawer[0].toKebabCase()}'
              : '/conversions',
        );
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _dataLoadedSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? _SplashScreenWidget() : const SizedBox.shrink();
  }
}

class _SplashScreenWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.compare_arrows,
                size: 60,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 30),
            // App Name
            const Text(
              'Converter NOW',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // App Description
            const Text(
              '快速单位转换工具',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
