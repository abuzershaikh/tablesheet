import 'package:flutter/material.dart';
import '../../domain/entities/template_entity.dart';
import '../../data/templates/template_registry.dart';
import 'widgets/template_category_card.dart';
import 'widgets/template_card.dart';

class TemplatesScreen extends StatefulWidget {
  final void Function(SheetTemplate template) onUseTemplate;

  const TemplatesScreen({
    super.key,
    required this.onUseTemplate,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<TemplateCategory> get _categories => TemplateRegistry.allCategories;

  List<SheetTemplate> get _filteredTemplates {
    List<SheetTemplate> templates;

    if (_selectedCategoryId != null) {
      final cat = _categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => _categories.first,
      );
      templates = cat.templates;
    } else {
      templates = _categories.expand((c) => c.templates).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      templates = templates.where((t) {
        return t.name.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query);
      }).toList();
    }

    return templates;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Templates',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Ready-made spreadsheets for your business',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search templates...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close,
                            color: Colors.grey.shade400,
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category Chips (horizontal scroll)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length + 1, // +1 for "All"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildAllCategoryChip();
                }
                final category = _categories[index - 1];
                return TemplateCategoryCard(
                  category: category,
                  isSelected: _selectedCategoryId == category.id,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId =
                          _selectedCategoryId == category.id ? null : category.id;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  _selectedCategoryId != null
                      ? _categories
                          .firstWhere((c) => c.id == _selectedCategoryId,
                              orElse: () => _categories.first)
                          .name
                      : 'All Templates',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2879FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_filteredTemplates.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2879FF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Templates Grid
          Expanded(
            child: _filteredTemplates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No templates found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = _filteredTemplates[index];
                      return TemplateCard(
                        template: template,
                        onUse: () => widget.onUseTemplate(template),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCategoryChip() {
    final isAll = _selectedCategoryId == null;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: isAll
              ? const LinearGradient(
                  colors: [Color(0xFF2848D3), Color(0xFF2879FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isAll ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAll ? Colors.transparent : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isAll
              ? [
                  BoxShadow(
                    color: const Color(0xFF2848D3).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isAll
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFF2848D3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.apps,
                color: isAll ? Colors.white : const Color(0xFF2848D3),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isAll ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_categories.expand((c) => c.templates).length} templates',
              style: TextStyle(
                fontSize: 9,
                color: isAll
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
