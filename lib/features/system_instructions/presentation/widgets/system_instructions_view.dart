import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/system_instruction_repository.dart';
import '../../domain/entities/system_instruction_template.dart';

/// System Instructions View with template selection menu for re-using prompts
/// when launching new conversations or steering agent behavior.
class SystemInstructionsView extends StatefulWidget {
  final SystemInstructionRepository repository;
  final ValueChanged<SystemInstructionTemplate> onApplyTemplate;
  final String? activeTemplateId;

  const SystemInstructionsView({
    super.key,
    required this.repository,
    required this.onApplyTemplate,
    this.activeTemplateId,
  });

  @override
  State<SystemInstructionsView> createState() => _SystemInstructionsViewState();
}

class _SystemInstructionsViewState extends State<SystemInstructionsView> {
  String _selectedCategory = 'All';
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _selectedTemplateId = widget.activeTemplateId;
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final promptController = TextEditingController();
    final categoryController = TextEditingController(text: 'Custom');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.add_task, color: AppTheme.primaryBlue, size: 20),
            SizedBox(width: 8),
            Text('Create System Instruction Template', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField('Template Title', titleController),
                const SizedBox(height: 10),
                _buildField('Category', categoryController),
                const SizedBox(height: 10),
                _buildField('Description', descController),
                const SizedBox(height: 10),
                _buildField('System Prompt', promptController, maxLines: 5),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () {
              final title = titleController.text.trim();
              final prompt = promptController.text.trim();
              if (title.isNotEmpty && prompt.isNotEmpty) {
                final newTemplate = SystemInstructionTemplate(
                  id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  category: categoryController.text.trim(),
                  description: descController.text.trim(),
                  systemPrompt: prompt,
                  isCustom: true,
                  tags: ['Custom'],
                );
                widget.repository.addCustomTemplate(newTemplate);
                setState(() => _selectedTemplateId = newTemplate.id);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.terminalBlack,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.repository.getTemplates(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
    );

    final selectedTemplate = widget.repository.getById(_selectedTemplateId ?? '') ??
        (templates.isNotEmpty ? templates.first : null);

    final categories = ['All', 'Architecture', 'Security', 'Refactoring', 'Protocols', 'Infrastructure', 'Custom'];

    return Container(
      color: AppTheme.terminalBlack,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Categories
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'System Instructions Catalog',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 16),
              // Category chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: AppTheme.surfaceElevated,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Instruction', style: TextStyle(fontSize: 12)),
                onPressed: _showCreateDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two-pane view: Left = Template List, Right = Selected Template Preview & Prompt
          Expanded(
            child: Row(
              children: [
                // Template List
                SizedBox(
                  width: 320,
                  child: ListView.separated(
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = templates[idx];
                      final isSelected = item.id == selectedTemplate?.id;
                      return InkWell(
                        onTap: () => setState(() => _selectedTemplateId = item.id),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.surfaceElevated : AppTheme.terminalBlack,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryBlue : Colors.white12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                  ),
                                  if (item.isCustom)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentCyan.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('CUSTOM', style: TextStyle(fontSize: 8, color: AppTheme.accentCyan)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Selected Template Details & Prompt
                Expanded(
                  child: selectedTemplate == null
                      ? const Center(child: Text('Select an instruction template', style: TextStyle(color: Colors.white38)))
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedTemplate.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Category: ${selectedTemplate.category}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.statusSuccess,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Apply to Conversation'),
                                    onPressed: () {
                                      widget.onApplyTemplate(selectedTemplate);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.statusSuccess,
                                          content: Text('Applied "${selectedTemplate.title}" to active session.'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                selectedTemplate.description,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'System Prompt Directive:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.terminalBlack,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      selectedTemplate.systemPrompt,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Color(0xFFC9D1D9),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
