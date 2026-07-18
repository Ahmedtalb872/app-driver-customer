import '../datasources/destinations_remote_datasource.dart';
import '../models/destination_suggestion.dart';

/// Backs the admin dispatch screen's autocomplete - a single free-text
/// search across places, districts, and neighborhoods (search_destinations,
/// 20260717000035_destination_search.sql), unlike [PlacesRepository.search]
/// which only searches places.
class DestinationSearchRepository {
  DestinationSearchRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  Future<List<DestinationSuggestion>> search({
    required String query,
    int limit = 15,
  }) async {
    final rows = await _dataSource.searchDestinations(
      query: query,
      limit: limit,
    );
    return rows.map(DestinationSuggestion.fromJson).toList();
  }
}
