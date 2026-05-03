class Photo {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String title;
  final String location;
  final DateTime takenAt;

  const Photo({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.title,
    required this.location,
    required this.takenAt,
  });
}
