import 'package:flutter/material.dart';
import '../../../../core/config/model_descriptor.dart';
import '../../../../core/config/model_registry.dart';
import '../../../../core/theme/app_theme.dart';

/// Dynamic Model Selector Dropdown.
/// Eliminates hardcoded model identifiers, supports dynamic discovery,
/// custom model inputs, and enforces per-session lock state.
class ModelSelectorDropdown extends StatelessWidget {
  final ModelRegistry registry;
  final String? selectedModelId;
  final bool isLocked;
  final ValueChanged<String>? onModelSelected;
  final VoidCallback? onRefreshModels;

  const ModelSelectorDropdown({
    super.key,
    required this.registry,
    required this.selectedModelId,
    this.isLocked = false,
    this.onModelSelected,
    this.onRefreshModels,
  });

  @override
  Widget build(BuildContext context) {
    final models = registry.models;

    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        if (isLocked) {
          final currentModel = registry.getModel(selectedModelId ?? '') ??
              ModelDescriptor(
                id: selectedModelId ?? 'unknown',
                displayName: selectedModelId ?? 'Unknown Model',
                description: 'Locked Session Model',
              );

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppTheme.statusPlanning),
                const SizedBox(width: 6),
                Text(
                  currentModel.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 6),
                _buildBadge(currentModel),
              ],
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: models.any((m) => m.id == selectedModelId)
                        ? selectedModelId
                        : (models.isNotEmpty ? models.first.id : null),
                    dropdownColor: AppTheme.surfaceElevated,
                    hint: const Text('Select Agent Model', style: TextStyle(color: Colors.white38)),
                    selectedItemBuilder: (context) {
                      return models.map((model) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            model.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: [

                      ...models.map((model) {
                        return DropdownMenuItem<String>(
                          value: model.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  model.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildBadge(model),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (newId) {
                      if (newId != null && onModelSelected != null) {
                        onModelSelected!(newId);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (onRefreshModels != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Discover updated models from Gemini API',
                icon: registry.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                onPressed: registry.isLoading ? null : onRefreshModels,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBadge(ModelDescriptor model) {
    if (model.supportsReasoning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.statusPlanning.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Reasoning',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.statusPlanning,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (model.supportsFastCoding) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentCyan.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Fast Loop',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.accentCyan,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
