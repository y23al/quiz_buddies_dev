// WiFi情報取得サービス
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:crypto/crypto.dart' as crypto;

class WifiService {
  static final WifiService _instance = WifiService._internal();
  factory WifiService() => _instance;
  WifiService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();

  // WiFiキーを取得（SSIDをハッシュ化）
  // WebやiOSでは取得できないためnullを返す
  Future<String?> getWifiKey() async {
    try {
      // Webプラットフォームでは取得不可
      if (kIsWeb) {
        return null;
      }

      final ssid = await _networkInfo.getWifiName();
      if (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>') {
        return null;
      }

      // SSIDをFirebase-safeなキーに変換（特殊文字を除去）
      final cleanSsid = ssid
          .replaceAll('"', '')
          .replaceAll('.', '_')
          .replaceAll('#', '_')
          .replaceAll('\$', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('/', '_');

      // 短いハッシュを追加して衝突を減らす
      final hash = _generateShortHash(ssid);
      return '${cleanSsid}_$hash';
    } catch (e) {
      debugPrint('WiFi情報取得エラー: $e');
      return null;
    }
  }

  // SSID名を取得（表示用）
  Future<String?> getWifiName() async {
    try {
      if (kIsWeb) {
        return null;
      }
      final ssid = await _networkInfo.getWifiName();
      if (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>') {
        return null;
      }
      return ssid.replaceAll('"', '');
    } catch (e) {
      return null;
    }
  }

  // WiFi情報が取得可能かどうか
  Future<bool> isWifiAvailable() async {
    final key = await getWifiKey();
    return key != null;
  }

  // 短いハッシュを生成（衝突防止用）
  String _generateShortHash(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.md5.convert(bytes);
    return digest.toString().substring(0, 8);
  }
}
