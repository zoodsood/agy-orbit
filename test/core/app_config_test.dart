import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig Dynamic Variables Tests', () {
    test('Defaults to unconstrained egress allowlist (*)', () {
      final config = AppConfig();
      expect(config.networkAllowlist, contains('*'));
    });

    test('Allows runtime mutation of all endpoints and variables without rebuild', () {
      final config = AppConfig(
        controlPlaneBaseUrl: 'https://staging-generativelanguage.googleapis.com',
        apiVersion: 'v1alpha',
      );

      expect(config.controlPlaneBaseUrl, equals('https://staging-generativelanguage.googleapis.com'));
      expect(config.apiVersion, equals('v1alpha'));

      // Dynamically update at runtime
      config.updateVariables(
        controlPlaneBaseUrl: 'https://custom-enterprise-gateway.internal',
        apiVersion: 'v2',
        networkAllowlist: ['github.com', 'pub.dev', '*'],
      );

      expect(config.controlPlaneBaseUrl, equals('https://custom-enterprise-gateway.internal'));
      expect(config.apiVersion, equals('v2'));
      expect(config.networkAllowlist, equals(['github.com', 'pub.dev', '*']));

      final uri = config.buildControlPlaneUri('agents/agent-123');
      expect(uri.toString(), equals('https://custom-enterprise-gateway.internal/v2/agents/agent-123'));
    });

    test('Serializes and deserializes runtime JSON configuration', () {
      final json = {
        'api': {
          'controlPlaneBaseUrl': 'https://proxy.example.com',
          'dataPlaneBaseUrl': 'https://proxy.example.com',
          'apiVersion': 'v1beta',
          'memoryBankBaseUrl': 'https://memory.example.com',
          'networkAllowlist': ['*'],
          'requestTimeoutSeconds': 90,
          'pollingIntervalSeconds': 5,
        }
      };

      final config = AppConfig.fromJson(json);
      expect(config.controlPlaneBaseUrl, equals('https://proxy.example.com'));
      expect(config.requestTimeoutSeconds, equals(90));
      expect(config.pollingIntervalSeconds, equals(5));
    });
  });
}
