import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // 테스트용 광고 단위 ID (실제 배포 시 변경 필요)
  static String get _bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // Android 테스트 ID
      : 'ca-app-pub-3940256099942544/2934735716'; // iOS 테스트 ID

  static String get _interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' // Android 테스트 ID
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS 테스트 ID

  static String get _rewardedAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android 테스트 ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID

  // AdMob 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // 배너 광고 생성
  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('배너 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('배너 광고 로드 실패: $error');
          ad.dispose();
        },
      ),
    );
  }

  // 전면 광고 생성
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;

  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          print('전면 광고 로드 성공');
        },
        onAdFailedToLoad: (error) {
          print('전면 광고 로드 실패: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  static void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('전면 광고 표시됨');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('전면 광고 닫힘');
          ad.dispose();
          _isInterstitialAdReady = false;
          loadInterstitialAd(); // 다음 광고 미리 로드
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('전면 광고 표시 실패: $error');
          ad.dispose();
          _isInterstitialAdReady = false;
        },
      );
      _interstitialAd!.show();
    }
  }

  // 보상형 광고 생성
  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdReady = false;

  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          print('보상형 광고 로드 성공');
        },
        onAdFailedToLoad: (error) {
          print('보상형 광고 로드 실패: $error');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  static void showRewardedAd({required Function(RewardItem) onRewarded}) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('보상형 광고 표시됨');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('보상형 광고 닫힘');
          ad.dispose();
          _isRewardedAdReady = false;
          loadRewardedAd(); // 다음 광고 미리 로드
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('보상형 광고 표시 실패: $error');
          ad.dispose();
          _isRewardedAdReady = false;
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onRewarded(reward);
      });
    }
  }

  // 광고 정리
  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
