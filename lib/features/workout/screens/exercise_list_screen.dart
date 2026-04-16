import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/models/exercise.dart';
import '../../shared/widgets/category_video_background.dart';
import 'logging_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final String initialCategory;
  final String? initialSubcategory;
  const ExerciseListScreen({
    super.key,
    required this.initialCategory,
    this.initialSubcategory,
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  late String _selectedCategory;
  String? _selectedSubcategory;
  String _searchQuery = '';
  final List<Exercise> _exercises = kExerciseList;
  final bool _loaded = true;
  final _searchController = TextEditingController();

  static const _categoryOrder = ['arms', 'back', 'chest', 'legs', 'abs', 'cardio', 'calisthenics', 'custom'];
  static const _categoryLabels = {
    'arms': 'Arms',
    'back': 'Back',
    'chest': 'Chest',
    'legs': 'Legs',
    'abs': 'Abs',
    'cardio': 'Cardio',
    'calisthenics': 'Calisthenics',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedSubcategory = widget.initialSubcategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> get _filtered {
    return _exercises.where((e) {
      final matchesCategory = e.category == _selectedCategory;
      final matchesSubcategory =
          _selectedSubcategory == null || e.subcategory == _selectedSubcategory;
      final matchesSearch = _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSubcategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final title = _selectedSubcategory != null
        ? (kSubcategoryLabels[_selectedSubcategory!] ?? _selectedSubcategory!)
        : (_categoryLabels[_selectedCategory] ?? _selectedCategory);
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: CategoryVideoBackground(
        category: _selectedCategory,
        child: Column(
        children: [
          // Category chips (only when not filtered by subcategory)
          if (_selectedSubcategory == null) SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categoryOrder.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categoryOrder[i];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(_categoryLabels[cat] ?? cat),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedCategory = cat;
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surface.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.accent : AppColors.divider,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface.withValues(alpha: 0.25),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),

          // Exercise list
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No exercises found.' : 'No results for "$_searchQuery".',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.divider, height: 1),
                        itemBuilder: (context, i) {
                          final ex = filtered[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            title: Text(ex.name,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoggingScreen(
                                  exerciseId: ex.id,
                                  exerciseName: ex.name,
                                  category: ex.category,
                                  trackingType: ex.trackingType,
                                  plateable: ex.plateable,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}
