import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(buildScopedProviderMasterDetailsApp());
}

Widget buildScopedProviderMasterDetailsApp() {
  return ScopedProvider(
    provides: [
      Provide.create<WorkItemsRemoteDataSource>(WorkItemsRemoteDataSource.new),
      Provide.create<WorkItemsLocalDataSource>(WorkItemsLocalDataSource.new),
      Provide.create<WorkItemsRepository>(WorkItemsRepositoryImpl.new),
      Provide.create<GetWorkItemsUseCase>(GetWorkItemsUseCase.new),
      Provide.create<GetWorkItemDetailsUseCase>(GetWorkItemDetailsUseCase.new),
      Provide.create<ToggleWorkItemFavoriteUseCase>(
        ToggleWorkItemFavoriteUseCase.new,
      ),
      Provide.notifier<WorkItemsViewModel>(WorkItemsViewModel.new),
    ],
    child: const ScopedProviderMasterDetailsApp(),
  );
}

class ScopedProviderMasterDetailsApp extends StatelessWidget {
  const ScopedProviderMasterDetailsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScopedProvider Master/Details',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const WorkItemsPage(),
    );
  }
}

class WorkItemsPage extends StatelessWidget {
  const WorkItemsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WorkItemsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('ScopedProvider Master/Details')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final masterPane = _MasterListPane(viewModel: viewModel);
          final detailsPane = _DetailsPane(viewModel: viewModel);

          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                Expanded(child: masterPane),
                const VerticalDivider(width: 1),
                Expanded(child: detailsPane),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: masterPane),
              const Divider(height: 1),
              Expanded(child: detailsPane),
            ],
          );
        },
      ),
    );
  }
}

class _MasterListPane extends StatelessWidget {
  const _MasterListPane({required this.viewModel});

  final WorkItemsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingMaster) {
      return const Center(
        child: CircularProgressIndicator(key: Key('master_loading')),
      );
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Text(
          viewModel.errorMessage!,
          key: const Key('master_error'),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (viewModel.items.isEmpty) {
      return const Center(child: Text('No work items found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: viewModel.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = viewModel.items[index];
        return ListTile(
          key: Key('master_${item.id}'),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          selected: item.id == viewModel.selectedId,
          trailing: Icon(
            item.isFavorite ? Icons.star : Icons.star_border,
            color: item.isFavorite ? Colors.amber.shade700 : null,
          ),
          onTap: () => context.read<WorkItemsViewModel>().select(item.id),
        );
      },
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.viewModel});

  final WorkItemsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingDetails) {
      return const Center(
        child: CircularProgressIndicator(key: Key('detail_loading')),
      );
    }

    final details = viewModel.selectedDetails;
    if (details == null) {
      return const Center(
        child: Text(
          'Select an item to load details.',
          key: Key('empty_details'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.title,
            key: const Key('detail_title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(details.description, key: const Key('detail_description')),
          const SizedBox(height: 12),
          Text('Owner: ${details.owner}', key: const Key('detail_owner')),
          const SizedBox(height: 4),
          Text('Status: ${details.status}', key: const Key('detail_status')),
          const SizedBox(height: 4),
          Text(
            'Favorite: ${details.isFavorite ? 'Yes' : 'No'}',
            key: const Key('detail_favorite_state'),
          ),
          const Spacer(),
          FilledButton.icon(
            key: const Key('toggle_favorite_button'),
            onPressed: () =>
                context.read<WorkItemsViewModel>().toggleFavorite(),
            icon: Icon(details.isFavorite ? Icons.star : Icons.star_border),
            label: Text(
              details.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class WorkItemSummary {
  const WorkItemSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isFavorite;

  WorkItemSummary copyWith({
    String? id,
    String? title,
    String? subtitle,
    bool? isFavorite,
  }) {
    return WorkItemSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

@immutable
class WorkItemDetails {
  const WorkItemDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    required this.status,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final String description;
  final String owner;
  final String status;
  final bool isFavorite;

  WorkItemDetails copyWith({
    String? id,
    String? title,
    String? description,
    String? owner,
    String? status,
    bool? isFavorite,
  }) {
    return WorkItemDetails(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class WorkItemsLocalDataSource {
  final Set<String> _favoriteIds = <String>{'item-02'};
  final Map<String, WorkItemDetails> _detailsCache =
      <String, WorkItemDetails>{};

  bool isFavorite(String id) => _favoriteIds.contains(id);

  bool toggleFavorite(String id) {
    if (_favoriteIds.remove(id)) {
      return false;
    }
    _favoriteIds.add(id);
    return true;
  }

  WorkItemDetails? getCachedDetails(String id) => _detailsCache[id];

  void cacheDetails(WorkItemDetails details) {
    _detailsCache[details.id] = details;
  }

  void syncFavoriteInCache({required String id, required bool isFavorite}) {
    final details = _detailsCache[id];
    if (details == null) {
      return;
    }
    _detailsCache[id] = details.copyWith(isFavorite: isFavorite);
  }
}

class WorkItemsRemoteDataSource {
  static const List<_RemoteWorkItem> _seed = [
    _RemoteWorkItem(
      id: 'item-01',
      title: 'Build ScopedProvider sample',
      subtitle: 'Demonstrate constructor-based injection',
      description:
          'Create a production-like sample with ViewModel, use cases, repository, and data sources.',
      owner: 'Silas',
      status: 'In progress',
    ),
    _RemoteWorkItem(
      id: 'item-02',
      title: 'Write widget tests',
      subtitle: 'Protect master/details flow',
      description:
          'Cover loading, selecting a master item, and toggling favorites in details.',
      owner: 'QA Team',
      status: 'Planned',
    ),
    _RemoteWorkItem(
      id: 'item-03',
      title: 'Investigate flaky tests',
      subtitle: 'Stabilize CI pipeline',
      description:
          'Inspect intermittent logs and isolate the race condition in integration runs.',
      owner: 'Platform Team',
      status: 'Investigating',
    ),
  ];

  Future<List<_RemoteWorkItem>> fetchMasterItems() async {
    return _seed;
  }

  Future<_RemoteWorkItem> fetchDetails(String id) async {
    return _seed.firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Unknown item id: $id'),
    );
  }
}

abstract class WorkItemsRepository {
  Future<List<WorkItemSummary>> getMasterItems();

  Future<WorkItemDetails> getDetails(String id);

  Future<bool> toggleFavorite(String id);
}

class WorkItemsRepositoryImpl implements WorkItemsRepository {
  WorkItemsRepositoryImpl({
    required WorkItemsLocalDataSource localDataSource,
    required WorkItemsRemoteDataSource remoteDataSource,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource;

  final WorkItemsLocalDataSource _localDataSource;
  final WorkItemsRemoteDataSource _remoteDataSource;

  @override
  Future<List<WorkItemSummary>> getMasterItems() async {
    final remoteItems = await _remoteDataSource.fetchMasterItems();
    return remoteItems
        .map(
          (item) => WorkItemSummary(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            isFavorite: _localDataSource.isFavorite(item.id),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<WorkItemDetails> getDetails(String id) async {
    final cachedDetails = _localDataSource.getCachedDetails(id);
    if (cachedDetails != null) {
      return cachedDetails;
    }

    final remoteDetails = await _remoteDataSource.fetchDetails(id);
    final details = WorkItemDetails(
      id: remoteDetails.id,
      title: remoteDetails.title,
      description: remoteDetails.description,
      owner: remoteDetails.owner,
      status: remoteDetails.status,
      isFavorite: _localDataSource.isFavorite(remoteDetails.id),
    );

    _localDataSource.cacheDetails(details);
    return details;
  }

  @override
  Future<bool> toggleFavorite(String id) async {
    final isFavorite = _localDataSource.toggleFavorite(id);
    _localDataSource.syncFavoriteInCache(id: id, isFavorite: isFavorite);
    return isFavorite;
  }
}

class GetWorkItemsUseCase {
  GetWorkItemsUseCase(this._repository);

  final WorkItemsRepository _repository;

  Future<List<WorkItemSummary>> call() {
    return _repository.getMasterItems();
  }
}

class GetWorkItemDetailsUseCase {
  GetWorkItemDetailsUseCase({required WorkItemsRepository repository})
    : _repository = repository;

  final WorkItemsRepository _repository;

  Future<WorkItemDetails> call(String id) {
    return _repository.getDetails(id);
  }
}

class ToggleWorkItemFavoriteUseCase {
  ToggleWorkItemFavoriteUseCase(WorkItemsRepository repository)
    : _repository = repository;

  final WorkItemsRepository _repository;

  Future<bool> call(String id) {
    return _repository.toggleFavorite(id);
  }
}

class WorkItemsViewModel with ChangeNotifier, DiagnosticableTreeMixin {
  WorkItemsViewModel({
    required GetWorkItemsUseCase getWorkItemsUseCase,
    required GetWorkItemDetailsUseCase getWorkItemDetailsUseCase,
    required ToggleWorkItemFavoriteUseCase toggleWorkItemFavoriteUseCase,
  }) : _getWorkItemsUseCase = getWorkItemsUseCase,
       _getWorkItemDetailsUseCase = getWorkItemDetailsUseCase,
       _toggleWorkItemFavoriteUseCase = toggleWorkItemFavoriteUseCase {
    unawaited(_bootstrap());
  }

  final GetWorkItemsUseCase _getWorkItemsUseCase;
  final GetWorkItemDetailsUseCase _getWorkItemDetailsUseCase;
  final ToggleWorkItemFavoriteUseCase _toggleWorkItemFavoriteUseCase;

  List<WorkItemSummary> _items = const [];
  String? _selectedId;
  WorkItemDetails? _selectedDetails;
  bool _isLoadingMaster = false;
  bool _isLoadingDetails = false;
  String? _errorMessage;

  List<WorkItemSummary> get items => _items;
  String? get selectedId => _selectedId;
  WorkItemDetails? get selectedDetails => _selectedDetails;
  bool get isLoadingMaster => _isLoadingMaster;
  bool get isLoadingDetails => _isLoadingDetails;
  String? get errorMessage => _errorMessage;

  Future<void> _bootstrap() async {
    await loadMaster();
  }

  Future<void> loadMaster() async {
    _isLoadingMaster = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _getWorkItemsUseCase();
      if (_items.isEmpty) {
        _selectedId = null;
        _selectedDetails = null;
      } else {
        _selectedId ??= _items.first.id;
        await _loadDetailsForSelected();
      }
    } catch (error) {
      _errorMessage = 'Failed to load master list: $error';
    } finally {
      _isLoadingMaster = false;
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    if (_selectedId == id) {
      return;
    }
    _selectedId = id;
    _selectedDetails = null;
    notifyListeners();
    await _loadDetailsForSelected();
  }

  Future<void> toggleFavorite() async {
    final selectedId = _selectedId;
    if (selectedId == null) {
      return;
    }

    try {
      final isFavorite = await _toggleWorkItemFavoriteUseCase(selectedId);
      _items = [
        for (final item in _items)
          item.id == selectedId ? item.copyWith(isFavorite: isFavorite) : item,
      ];

      final details = _selectedDetails;
      if (details != null && details.id == selectedId) {
        _selectedDetails = details.copyWith(isFavorite: isFavorite);
      }
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to toggle favorite: $error';
      notifyListeners();
    }
  }

  Future<void> _loadDetailsForSelected() async {
    final selectedId = _selectedId;
    if (selectedId == null) {
      return;
    }

    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedDetails = await _getWorkItemDetailsUseCase(selectedId);
    } catch (error) {
      _errorMessage = 'Failed to load details: $error';
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        IterableProperty<WorkItemSummary>('items', _items, ifEmpty: '<empty>'),
      )
      ..add(StringProperty('selectedId', _selectedId, defaultValue: null))
      ..add(
        FlagProperty(
          'isLoadingMaster',
          value: _isLoadingMaster,
          ifTrue: 'loading master',
          defaultValue: false,
        ),
      )
      ..add(
        FlagProperty(
          'isLoadingDetails',
          value: _isLoadingDetails,
          ifTrue: 'loading details',
          defaultValue: false,
        ),
      )
      ..add(StringProperty('errorMessage', _errorMessage, defaultValue: null));
  }
}

@immutable
class _RemoteWorkItem {
  const _RemoteWorkItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.owner,
    required this.status,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String owner;
  final String status;
}
