import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../network/gemini_resilience_handler.dart';
import 'app_config.dart';
import 'model_descriptor.dart';

/// Dynamic Model Registry.
/// Eliminates hardcoded model identifiers so the client can discover, register,
/// and select new models without requiring an application rebuild.
/// Uses GeminiResilienceHandler to diagnose Permission Denied and network errors.
class ModelRegistry extends ChangeNotifier {
  final Map<String, ModelDescriptor> _models = {};
  bool _isLoading = false;
  String? _lastError;
  final GeminiResilienceHandler _resilienceHandler;

  ModelRegistry({
    List<ModelDescriptor>? initialModels,
    GeminiResilienceHandler? resilienceHandler,
  }) : _resilienceHandler = resilienceHandler ?? const GeminiResilienceHandler() {
    if (initialModels != null) {
      for (final model in initialModels) {
        _models[model.id] = model;
      }
    }
  }

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  List<ModelDescriptor> get models => _models.values.toList();
  bool get isEmpty => _models.isEmpty;

  /// Retrieves a model by its identifier.
  ModelDescriptor? getModel(String id) => _models[id];

  /// Returns true if a model with the given identifier is registered.
  bool containsModel(String id) => _models.containsKey(id);

  /// Registers or updates a model definition dynamically at runtime.
  void registerModel(ModelDescriptor model) {
    _models[model.id] = model;
    notifyListeners();
  }

  /// Bulk registers a list of models.
  void registerAll(Iterable<ModelDescriptor> models) {
    for (final model in models) {
      _models[model.id] = model;
    }
    notifyListeners();
  }

  /// Unregisters a model dynamically.
  void unregisterModel(String id) {
    if (_models.remove(id) != null) {
      notifyListeners();
    }
  }

  /// Populates models dynamically from runtime configuration JSON.
  void loadFromJsonList(List<dynamic> list) {
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final model = ModelDescriptor.fromJson(item);
        _models[model.id] = model;
      }
    }
    notifyListeners();
  }

  /// Queries the Gemini Models API dynamically at runtime to fetch the current
  /// catalog of available models without recompiling the app.
  /// Wrapped in GeminiResilienceHandler for exponential retry and permission diagnosis.
  Future<void> fetchModelsFromApi({
    required http.Client httpClient,
    required AppConfig appConfig,
    required String apiKey,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final uri = appConfig.buildControlPlaneUri('models', queryParameters: {'key': apiKey});
      final response = await _resilienceHandler.executeWithRetry(() => httpClient.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final modelsList = data['models'] as List<dynamic>? ?? [];
        for (final m in modelsList) {
          if (m is Map<String, dynamic>) {
            final descriptor = ModelDescriptor.fromGoogleApiModel(m);
            _models[descriptor.id] = descriptor;
          }
        }
      } else {
        _lastError = 'Failed to fetch models: HTTP ${response.statusCode}';
      }
    } on GeminiPermissionDeniedException catch (e) {
      _lastError = e.toString();
    } on GeminiApiException catch (e) {
      _lastError = e.toString();
    } catch (e) {
      _lastError = 'Exception while fetching models from API: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter models supporting complex reasoning (e.g., Argon, Pro, etc.)
  List<ModelDescriptor> getReasoningModels() {
    return _models.values.where((m) => m.supportsReasoning).toList();
  }

  /// Filter models supporting fast coding / iterative loops (e.g., Flash, etc.)
  List<ModelDescriptor> getFastCodingModels() {
    return _models.values.where((m) => m.supportsFastCoding).toList();
  }
}
