class PodcastFeed {
  const PodcastFeed({
    required this.id,
    required this.title,
    required this.url,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String url;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory PodcastFeed.fromJson(Map<String, dynamic> json) {
    return PodcastFeed(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  PodcastFeed copyWith({String? title, String? url, String? imageUrl}) {
    return PodcastFeed(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
