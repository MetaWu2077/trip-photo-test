import 'photo.dart';

class Album {
  final String id;
  final String title;
  final String destination;
  final String coverUrl;
  final DateTime date;
  final List<Photo> photos;

  const Album({
    required this.id,
    required this.title,
    required this.destination,
    required this.coverUrl,
    required this.date,
    required this.photos,
  });

  int get photoCount => photos.length;
}
