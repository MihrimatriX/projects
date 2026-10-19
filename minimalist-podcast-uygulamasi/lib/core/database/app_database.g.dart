// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FeedsTable extends Feeds with TableInfo<$FeedsTable, Feed> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, title, url, imageUrl, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feeds';
  @override
  VerificationContext validateIntegrity(Insertable<Feed> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Feed map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Feed(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $FeedsTable createAlias(String alias) {
    return $FeedsTable(attachedDatabase, alias);
  }
}

class Feed extends DataClass implements Insertable<Feed> {
  final String id;
  final String title;
  final String url;
  final String? imageUrl;
  final DateTime addedAt;
  const Feed(
      {required this.id,
      required this.title,
      required this.url,
      this.imageUrl,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FeedsCompanion toCompanion(bool nullToAbsent) {
    return FeedsCompanion(
      id: Value(id),
      title: Value(title),
      url: Value(url),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      addedAt: Value(addedAt),
    );
  }

  factory Feed.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Feed(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Feed copyWith(
          {String? id,
          String? title,
          String? url,
          Value<String?> imageUrl = const Value.absent(),
          DateTime? addedAt}) =>
      Feed(
        id: id ?? this.id,
        title: title ?? this.title,
        url: url ?? this.url,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        addedAt: addedAt ?? this.addedAt,
      );
  Feed copyWithCompanion(FeedsCompanion data) {
    return Feed(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Feed(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, url, imageUrl, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Feed &&
          other.id == this.id &&
          other.title == this.title &&
          other.url == this.url &&
          other.imageUrl == this.imageUrl &&
          other.addedAt == this.addedAt);
}

class FeedsCompanion extends UpdateCompanion<Feed> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> url;
  final Value<String?> imageUrl;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FeedsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedsCompanion.insert({
    required String id,
    required String title,
    required String url,
    this.imageUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        url = Value(url);
  static Insertable<Feed> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? url,
    Expression<String>? imageUrl,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (imageUrl != null) 'image_url': imageUrl,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? url,
      Value<String?>? imageUrl,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return FeedsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _audioUrlMeta =
      const VerificationMeta('audioUrl');
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
      'audio_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _feedIdMeta = const VerificationMeta('feedId');
  @override
  late final GeneratedColumn<String> feedId = GeneratedColumn<String>(
      'feed_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES feeds (id) ON DELETE CASCADE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishedMeta =
      const VerificationMeta('published');
  @override
  late final GeneratedColumn<DateTime> published = GeneratedColumn<DateTime>(
      'published', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chaptersJsonMeta =
      const VerificationMeta('chaptersJson');
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
      'chapters_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        audioUrl,
        feedId,
        title,
        description,
        published,
        durationMs,
        sortOrder,
        fetchedAt,
        localPath,
        chaptersJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(Insertable<Episode> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audio_url')) {
      context.handle(_audioUrlMeta,
          audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta));
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('feed_id')) {
      context.handle(_feedIdMeta,
          feedId.isAcceptableOrUnknown(data['feed_id']!, _feedIdMeta));
    } else if (isInserting) {
      context.missing(_feedIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('published')) {
      context.handle(_publishedMeta,
          published.isAcceptableOrUnknown(data['published']!, _publishedMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
          _chaptersJsonMeta,
          chaptersJson.isAcceptableOrUnknown(
              data['chapters_json']!, _chaptersJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {audioUrl};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      audioUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_url'])!,
      feedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feed_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      published: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}published']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      chaptersJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapters_json']),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final String audioUrl;
  final String feedId;
  final String title;
  final String? description;
  final DateTime? published;
  final int? durationMs;
  final int sortOrder;
  final DateTime fetchedAt;
  final String? localPath;
  final String? chaptersJson;
  const Episode(
      {required this.audioUrl,
      required this.feedId,
      required this.title,
      this.description,
      this.published,
      this.durationMs,
      required this.sortOrder,
      required this.fetchedAt,
      this.localPath,
      this.chaptersJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audio_url'] = Variable<String>(audioUrl);
    map['feed_id'] = Variable<String>(feedId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || published != null) {
      map['published'] = Variable<DateTime>(published);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || chaptersJson != null) {
      map['chapters_json'] = Variable<String>(chaptersJson);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      audioUrl: Value(audioUrl),
      feedId: Value(feedId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      published: published == null && nullToAbsent
          ? const Value.absent()
          : Value(published),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      sortOrder: Value(sortOrder),
      fetchedAt: Value(fetchedAt),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      chaptersJson: chaptersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(chaptersJson),
    );
  }

  factory Episode.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      feedId: serializer.fromJson<String>(json['feedId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      published: serializer.fromJson<DateTime?>(json['published']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      chaptersJson: serializer.fromJson<String?>(json['chaptersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'audioUrl': serializer.toJson<String>(audioUrl),
      'feedId': serializer.toJson<String>(feedId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'published': serializer.toJson<DateTime?>(published),
      'durationMs': serializer.toJson<int?>(durationMs),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'localPath': serializer.toJson<String?>(localPath),
      'chaptersJson': serializer.toJson<String?>(chaptersJson),
    };
  }

  Episode copyWith(
          {String? audioUrl,
          String? feedId,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<DateTime?> published = const Value.absent(),
          Value<int?> durationMs = const Value.absent(),
          int? sortOrder,
          DateTime? fetchedAt,
          Value<String?> localPath = const Value.absent(),
          Value<String?> chaptersJson = const Value.absent()}) =>
      Episode(
        audioUrl: audioUrl ?? this.audioUrl,
        feedId: feedId ?? this.feedId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        published: published.present ? published.value : this.published,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        sortOrder: sortOrder ?? this.sortOrder,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        localPath: localPath.present ? localPath.value : this.localPath,
        chaptersJson:
            chaptersJson.present ? chaptersJson.value : this.chaptersJson,
      );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      feedId: data.feedId.present ? data.feedId.value : this.feedId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      published: data.published.present ? data.published.value : this.published,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      chaptersJson: data.chaptersJson.present
          ? data.chaptersJson.value
          : this.chaptersJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('audioUrl: $audioUrl, ')
          ..write('feedId: $feedId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('published: $published, ')
          ..write('durationMs: $durationMs, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('localPath: $localPath, ')
          ..write('chaptersJson: $chaptersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(audioUrl, feedId, title, description,
      published, durationMs, sortOrder, fetchedAt, localPath, chaptersJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.audioUrl == this.audioUrl &&
          other.feedId == this.feedId &&
          other.title == this.title &&
          other.description == this.description &&
          other.published == this.published &&
          other.durationMs == this.durationMs &&
          other.sortOrder == this.sortOrder &&
          other.fetchedAt == this.fetchedAt &&
          other.localPath == this.localPath &&
          other.chaptersJson == this.chaptersJson);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<String> audioUrl;
  final Value<String> feedId;
  final Value<String> title;
  final Value<String?> description;
  final Value<DateTime?> published;
  final Value<int?> durationMs;
  final Value<int> sortOrder;
  final Value<DateTime> fetchedAt;
  final Value<String?> localPath;
  final Value<String?> chaptersJson;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.audioUrl = const Value.absent(),
    this.feedId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.published = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.localPath = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required String audioUrl,
    required String feedId,
    required String title,
    this.description = const Value.absent(),
    this.published = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int sortOrder,
    required DateTime fetchedAt,
    this.localPath = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : audioUrl = Value(audioUrl),
        feedId = Value(feedId),
        title = Value(title),
        sortOrder = Value(sortOrder),
        fetchedAt = Value(fetchedAt);
  static Insertable<Episode> custom({
    Expression<String>? audioUrl,
    Expression<String>? feedId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? published,
    Expression<int>? durationMs,
    Expression<int>? sortOrder,
    Expression<DateTime>? fetchedAt,
    Expression<String>? localPath,
    Expression<String>? chaptersJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (audioUrl != null) 'audio_url': audioUrl,
      if (feedId != null) 'feed_id': feedId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (published != null) 'published': published,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (localPath != null) 'local_path': localPath,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith(
      {Value<String>? audioUrl,
      Value<String>? feedId,
      Value<String>? title,
      Value<String?>? description,
      Value<DateTime?>? published,
      Value<int?>? durationMs,
      Value<int>? sortOrder,
      Value<DateTime>? fetchedAt,
      Value<String?>? localPath,
      Value<String?>? chaptersJson,
      Value<int>? rowid}) {
    return EpisodesCompanion(
      audioUrl: audioUrl ?? this.audioUrl,
      feedId: feedId ?? this.feedId,
      title: title ?? this.title,
      description: description ?? this.description,
      published: published ?? this.published,
      durationMs: durationMs ?? this.durationMs,
      sortOrder: sortOrder ?? this.sortOrder,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      localPath: localPath ?? this.localPath,
      chaptersJson: chaptersJson ?? this.chaptersJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (feedId.present) {
      map['feed_id'] = Variable<String>(feedId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (published.present) {
      map['published'] = Variable<DateTime>(published.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('audioUrl: $audioUrl, ')
          ..write('feedId: $feedId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('published: $published, ')
          ..write('durationMs: $durationMs, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('localPath: $localPath, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackPositionsTableTable extends PlaybackPositionsTable
    with TableInfo<$PlaybackPositionsTableTable, PlaybackPositionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackPositionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _audioUrlMeta =
      const VerificationMeta('audioUrl');
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
      'audio_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMsMeta =
      const VerificationMeta('positionMs');
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
      'position_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedMeta =
      const VerificationMeta('completed');
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
      'completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [audioUrl, positionMs, completed, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_positions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlaybackPositionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('audio_url')) {
      context.handle(_audioUrlMeta,
          audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta));
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
          _positionMsMeta,
          positionMs.isAcceptableOrUnknown(
              data['position_ms']!, _positionMsMeta));
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(_completedMeta,
          completed.isAcceptableOrUnknown(data['completed']!, _completedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {audioUrl};
  @override
  PlaybackPositionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackPositionsTableData(
      audioUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_url'])!,
      positionMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ms'])!,
      completed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}completed'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaybackPositionsTableTable createAlias(String alias) {
    return $PlaybackPositionsTableTable(attachedDatabase, alias);
  }
}

class PlaybackPositionsTableData extends DataClass
    implements Insertable<PlaybackPositionsTableData> {
  final String audioUrl;
  final int positionMs;
  final bool completed;
  final DateTime updatedAt;
  const PlaybackPositionsTableData(
      {required this.audioUrl,
      required this.positionMs,
      required this.completed,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['audio_url'] = Variable<String>(audioUrl);
    map['position_ms'] = Variable<int>(positionMs);
    map['completed'] = Variable<bool>(completed);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackPositionsTableCompanion toCompanion(bool nullToAbsent) {
    return PlaybackPositionsTableCompanion(
      audioUrl: Value(audioUrl),
      positionMs: Value(positionMs),
      completed: Value(completed),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackPositionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackPositionsTableData(
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      completed: serializer.fromJson<bool>(json['completed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'audioUrl': serializer.toJson<String>(audioUrl),
      'positionMs': serializer.toJson<int>(positionMs),
      'completed': serializer.toJson<bool>(completed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackPositionsTableData copyWith(
          {String? audioUrl,
          int? positionMs,
          bool? completed,
          DateTime? updatedAt}) =>
      PlaybackPositionsTableData(
        audioUrl: audioUrl ?? this.audioUrl,
        positionMs: positionMs ?? this.positionMs,
        completed: completed ?? this.completed,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlaybackPositionsTableData copyWithCompanion(
      PlaybackPositionsTableCompanion data) {
    return PlaybackPositionsTableData(
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      positionMs:
          data.positionMs.present ? data.positionMs.value : this.positionMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPositionsTableData(')
          ..write('audioUrl: $audioUrl, ')
          ..write('positionMs: $positionMs, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(audioUrl, positionMs, completed, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackPositionsTableData &&
          other.audioUrl == this.audioUrl &&
          other.positionMs == this.positionMs &&
          other.completed == this.completed &&
          other.updatedAt == this.updatedAt);
}

class PlaybackPositionsTableCompanion
    extends UpdateCompanion<PlaybackPositionsTableData> {
  final Value<String> audioUrl;
  final Value<int> positionMs;
  final Value<bool> completed;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackPositionsTableCompanion({
    this.audioUrl = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackPositionsTableCompanion.insert({
    required String audioUrl,
    required int positionMs,
    this.completed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : audioUrl = Value(audioUrl),
        positionMs = Value(positionMs);
  static Insertable<PlaybackPositionsTableData> custom({
    Expression<String>? audioUrl,
    Expression<int>? positionMs,
    Expression<bool>? completed,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (audioUrl != null) 'audio_url': audioUrl,
      if (positionMs != null) 'position_ms': positionMs,
      if (completed != null) 'completed': completed,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackPositionsTableCompanion copyWith(
      {Value<String>? audioUrl,
      Value<int>? positionMs,
      Value<bool>? completed,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PlaybackPositionsTableCompanion(
      audioUrl: audioUrl ?? this.audioUrl,
      positionMs: positionMs ?? this.positionMs,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPositionsTableCompanion(')
          ..write('audioUrl: $audioUrl, ')
          ..write('positionMs: $positionMs, ')
          ..write('completed: $completed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayQueueTableTable extends PlayQueueTable
    with TableInfo<$PlayQueueTableTable, PlayQueueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _audioUrlMeta =
      const VerificationMeta('audioUrl');
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
      'audio_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _episodeTitleMeta =
      const VerificationMeta('episodeTitle');
  @override
  late final GeneratedColumn<String> episodeTitle = GeneratedColumn<String>(
      'episode_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _podcastTitleMeta =
      const VerificationMeta('podcastTitle');
  @override
  late final GeneratedColumn<String> podcastTitle = GeneratedColumn<String>(
      'podcast_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _feedIdMeta = const VerificationMeta('feedId');
  @override
  late final GeneratedColumn<String> feedId = GeneratedColumn<String>(
      'feed_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _chaptersJsonMeta =
      const VerificationMeta('chaptersJson');
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
      'chapters_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        audioUrl,
        episodeTitle,
        podcastTitle,
        feedId,
        durationMs,
        localPath,
        chaptersJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_queue_table';
  @override
  VerificationContext validateIntegrity(Insertable<PlayQueueTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('audio_url')) {
      context.handle(_audioUrlMeta,
          audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta));
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('episode_title')) {
      context.handle(
          _episodeTitleMeta,
          episodeTitle.isAcceptableOrUnknown(
              data['episode_title']!, _episodeTitleMeta));
    } else if (isInserting) {
      context.missing(_episodeTitleMeta);
    }
    if (data.containsKey('podcast_title')) {
      context.handle(
          _podcastTitleMeta,
          podcastTitle.isAcceptableOrUnknown(
              data['podcast_title']!, _podcastTitleMeta));
    } else if (isInserting) {
      context.missing(_podcastTitleMeta);
    }
    if (data.containsKey('feed_id')) {
      context.handle(_feedIdMeta,
          feedId.isAcceptableOrUnknown(data['feed_id']!, _feedIdMeta));
    } else if (isInserting) {
      context.missing(_feedIdMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
          _chaptersJsonMeta,
          chaptersJson.isAcceptableOrUnknown(
              data['chapters_json']!, _chaptersJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayQueueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayQueueTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      audioUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_url'])!,
      episodeTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}episode_title'])!,
      podcastTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}podcast_title'])!,
      feedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feed_id'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      chaptersJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapters_json']),
    );
  }

  @override
  $PlayQueueTableTable createAlias(String alias) {
    return $PlayQueueTableTable(attachedDatabase, alias);
  }
}

class PlayQueueTableData extends DataClass
    implements Insertable<PlayQueueTableData> {
  final int id;
  final String audioUrl;
  final String episodeTitle;
  final String podcastTitle;
  final String feedId;
  final int? durationMs;
  final String? localPath;
  final String? chaptersJson;
  const PlayQueueTableData(
      {required this.id,
      required this.audioUrl,
      required this.episodeTitle,
      required this.podcastTitle,
      required this.feedId,
      this.durationMs,
      this.localPath,
      this.chaptersJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['audio_url'] = Variable<String>(audioUrl);
    map['episode_title'] = Variable<String>(episodeTitle);
    map['podcast_title'] = Variable<String>(podcastTitle);
    map['feed_id'] = Variable<String>(feedId);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || chaptersJson != null) {
      map['chapters_json'] = Variable<String>(chaptersJson);
    }
    return map;
  }

  PlayQueueTableCompanion toCompanion(bool nullToAbsent) {
    return PlayQueueTableCompanion(
      id: Value(id),
      audioUrl: Value(audioUrl),
      episodeTitle: Value(episodeTitle),
      podcastTitle: Value(podcastTitle),
      feedId: Value(feedId),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      chaptersJson: chaptersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(chaptersJson),
    );
  }

  factory PlayQueueTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayQueueTableData(
      id: serializer.fromJson<int>(json['id']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      episodeTitle: serializer.fromJson<String>(json['episodeTitle']),
      podcastTitle: serializer.fromJson<String>(json['podcastTitle']),
      feedId: serializer.fromJson<String>(json['feedId']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      chaptersJson: serializer.fromJson<String?>(json['chaptersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'episodeTitle': serializer.toJson<String>(episodeTitle),
      'podcastTitle': serializer.toJson<String>(podcastTitle),
      'feedId': serializer.toJson<String>(feedId),
      'durationMs': serializer.toJson<int?>(durationMs),
      'localPath': serializer.toJson<String?>(localPath),
      'chaptersJson': serializer.toJson<String?>(chaptersJson),
    };
  }

  PlayQueueTableData copyWith(
          {int? id,
          String? audioUrl,
          String? episodeTitle,
          String? podcastTitle,
          String? feedId,
          Value<int?> durationMs = const Value.absent(),
          Value<String?> localPath = const Value.absent(),
          Value<String?> chaptersJson = const Value.absent()}) =>
      PlayQueueTableData(
        id: id ?? this.id,
        audioUrl: audioUrl ?? this.audioUrl,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        podcastTitle: podcastTitle ?? this.podcastTitle,
        feedId: feedId ?? this.feedId,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        localPath: localPath.present ? localPath.value : this.localPath,
        chaptersJson:
            chaptersJson.present ? chaptersJson.value : this.chaptersJson,
      );
  PlayQueueTableData copyWithCompanion(PlayQueueTableCompanion data) {
    return PlayQueueTableData(
      id: data.id.present ? data.id.value : this.id,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      episodeTitle: data.episodeTitle.present
          ? data.episodeTitle.value
          : this.episodeTitle,
      podcastTitle: data.podcastTitle.present
          ? data.podcastTitle.value
          : this.podcastTitle,
      feedId: data.feedId.present ? data.feedId.value : this.feedId,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      chaptersJson: data.chaptersJson.present
          ? data.chaptersJson.value
          : this.chaptersJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayQueueTableData(')
          ..write('id: $id, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('podcastTitle: $podcastTitle, ')
          ..write('feedId: $feedId, ')
          ..write('durationMs: $durationMs, ')
          ..write('localPath: $localPath, ')
          ..write('chaptersJson: $chaptersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, audioUrl, episodeTitle, podcastTitle,
      feedId, durationMs, localPath, chaptersJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayQueueTableData &&
          other.id == this.id &&
          other.audioUrl == this.audioUrl &&
          other.episodeTitle == this.episodeTitle &&
          other.podcastTitle == this.podcastTitle &&
          other.feedId == this.feedId &&
          other.durationMs == this.durationMs &&
          other.localPath == this.localPath &&
          other.chaptersJson == this.chaptersJson);
}

class PlayQueueTableCompanion extends UpdateCompanion<PlayQueueTableData> {
  final Value<int> id;
  final Value<String> audioUrl;
  final Value<String> episodeTitle;
  final Value<String> podcastTitle;
  final Value<String> feedId;
  final Value<int?> durationMs;
  final Value<String?> localPath;
  final Value<String?> chaptersJson;
  const PlayQueueTableCompanion({
    this.id = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.podcastTitle = const Value.absent(),
    this.feedId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.localPath = const Value.absent(),
    this.chaptersJson = const Value.absent(),
  });
  PlayQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String audioUrl,
    required String episodeTitle,
    required String podcastTitle,
    required String feedId,
    this.durationMs = const Value.absent(),
    this.localPath = const Value.absent(),
    this.chaptersJson = const Value.absent(),
  })  : audioUrl = Value(audioUrl),
        episodeTitle = Value(episodeTitle),
        podcastTitle = Value(podcastTitle),
        feedId = Value(feedId);
  static Insertable<PlayQueueTableData> custom({
    Expression<int>? id,
    Expression<String>? audioUrl,
    Expression<String>? episodeTitle,
    Expression<String>? podcastTitle,
    Expression<String>? feedId,
    Expression<int>? durationMs,
    Expression<String>? localPath,
    Expression<String>? chaptersJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (podcastTitle != null) 'podcast_title': podcastTitle,
      if (feedId != null) 'feed_id': feedId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (localPath != null) 'local_path': localPath,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
    });
  }

  PlayQueueTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? audioUrl,
      Value<String>? episodeTitle,
      Value<String>? podcastTitle,
      Value<String>? feedId,
      Value<int?>? durationMs,
      Value<String?>? localPath,
      Value<String?>? chaptersJson}) {
    return PlayQueueTableCompanion(
      id: id ?? this.id,
      audioUrl: audioUrl ?? this.audioUrl,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      feedId: feedId ?? this.feedId,
      durationMs: durationMs ?? this.durationMs,
      localPath: localPath ?? this.localPath,
      chaptersJson: chaptersJson ?? this.chaptersJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (episodeTitle.present) {
      map['episode_title'] = Variable<String>(episodeTitle.value);
    }
    if (podcastTitle.present) {
      map['podcast_title'] = Variable<String>(podcastTitle.value);
    }
    if (feedId.present) {
      map['feed_id'] = Variable<String>(feedId.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('podcastTitle: $podcastTitle, ')
          ..write('feedId: $feedId, ')
          ..write('durationMs: $durationMs, ')
          ..write('localPath: $localPath, ')
          ..write('chaptersJson: $chaptersJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FeedsTable feeds = $FeedsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $PlaybackPositionsTableTable playbackPositionsTable =
      $PlaybackPositionsTableTable(this);
  late final $PlayQueueTableTable playQueueTable = $PlayQueueTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [feeds, episodes, playbackPositionsTable, playQueueTable];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('feeds',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('episodes', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$FeedsTableCreateCompanionBuilder = FeedsCompanion Function({
  required String id,
  required String title,
  required String url,
  Value<String?> imageUrl,
  Value<DateTime> addedAt,
  Value<int> rowid,
});
typedef $$FeedsTableUpdateCompanionBuilder = FeedsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> url,
  Value<String?> imageUrl,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$FeedsTableReferences
    extends BaseReferences<_$AppDatabase, $FeedsTable, Feed> {
  $$FeedsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.episodes,
          aliasName: $_aliasNameGenerator(db.feeds.id, db.episodes.feedId));

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager($_db, $_db.episodes)
        .filter((f) => f.feedId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FeedsTableFilterComposer extends Composer<_$AppDatabase, $FeedsTable> {
  $$FeedsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> episodesRefs(
      Expression<bool> Function($$EpisodesTableFilterComposer f) f) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.episodes,
        getReferencedColumn: (t) => t.feedId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EpisodesTableFilterComposer(
              $db: $db,
              $table: $db.episodes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FeedsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedsTable> {
  $$FeedsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$FeedsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedsTable> {
  $$FeedsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  Expression<T> episodesRefs<T extends Object>(
      Expression<T> Function($$EpisodesTableAnnotationComposer a) f) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.episodes,
        getReferencedColumn: (t) => t.feedId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EpisodesTableAnnotationComposer(
              $db: $db,
              $table: $db.episodes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FeedsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedsTable,
    Feed,
    $$FeedsTableFilterComposer,
    $$FeedsTableOrderingComposer,
    $$FeedsTableAnnotationComposer,
    $$FeedsTableCreateCompanionBuilder,
    $$FeedsTableUpdateCompanionBuilder,
    (Feed, $$FeedsTableReferences),
    Feed,
    PrefetchHooks Function({bool episodesRefs})> {
  $$FeedsTableTableManager(_$AppDatabase db, $FeedsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> url = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedsCompanion(
            id: id,
            title: title,
            url: url,
            imageUrl: imageUrl,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String url,
            Value<String?> imageUrl = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedsCompanion.insert(
            id: id,
            title: title,
            url: url,
            imageUrl: imageUrl,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$FeedsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedData<Feed, $FeedsTable, Episode>(
                        currentTable: table,
                        referencedTable:
                            $$FeedsTableReferences._episodesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FeedsTableReferences(db, table, p0).episodesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.feedId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FeedsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedsTable,
    Feed,
    $$FeedsTableFilterComposer,
    $$FeedsTableOrderingComposer,
    $$FeedsTableAnnotationComposer,
    $$FeedsTableCreateCompanionBuilder,
    $$FeedsTableUpdateCompanionBuilder,
    (Feed, $$FeedsTableReferences),
    Feed,
    PrefetchHooks Function({bool episodesRefs})>;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  required String audioUrl,
  required String feedId,
  required String title,
  Value<String?> description,
  Value<DateTime?> published,
  Value<int?> durationMs,
  required int sortOrder,
  required DateTime fetchedAt,
  Value<String?> localPath,
  Value<String?> chaptersJson,
  Value<int> rowid,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<String> audioUrl,
  Value<String> feedId,
  Value<String> title,
  Value<String?> description,
  Value<DateTime?> published,
  Value<int?> durationMs,
  Value<int> sortOrder,
  Value<DateTime> fetchedAt,
  Value<String?> localPath,
  Value<String?> chaptersJson,
  Value<int> rowid,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, Episode> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FeedsTable _feedIdTable(_$AppDatabase db) => db.feeds
      .createAlias($_aliasNameGenerator(db.episodes.feedId, db.feeds.id));

  $$FeedsTableProcessedTableManager get feedId {
    final $_column = $_itemColumn<String>('feed_id')!;

    final manager = $$FeedsTableTableManager($_db, $_db.feeds)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_feedIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get published => $composableBuilder(
      column: $table.published, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson, builder: (column) => ColumnFilters(column));

  $$FeedsTableFilterComposer get feedId {
    final $$FeedsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.feedId,
        referencedTable: $db.feeds,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FeedsTableFilterComposer(
              $db: $db,
              $table: $db.feeds,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get published => $composableBuilder(
      column: $table.published, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson,
      builder: (column) => ColumnOrderings(column));

  $$FeedsTableOrderingComposer get feedId {
    final $$FeedsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.feedId,
        referencedTable: $db.feeds,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FeedsTableOrderingComposer(
              $db: $db,
              $table: $db.feeds,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get published =>
      $composableBuilder(column: $table.published, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson, builder: (column) => column);

  $$FeedsTableAnnotationComposer get feedId {
    final $$FeedsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.feedId,
        referencedTable: $db.feeds,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FeedsTableAnnotationComposer(
              $db: $db,
              $table: $db.feeds,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EpisodesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EpisodesTable,
    Episode,
    $$EpisodesTableFilterComposer,
    $$EpisodesTableOrderingComposer,
    $$EpisodesTableAnnotationComposer,
    $$EpisodesTableCreateCompanionBuilder,
    $$EpisodesTableUpdateCompanionBuilder,
    (Episode, $$EpisodesTableReferences),
    Episode,
    PrefetchHooks Function({bool feedId})> {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> audioUrl = const Value.absent(),
            Value<String> feedId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime?> published = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> chaptersJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodesCompanion(
            audioUrl: audioUrl,
            feedId: feedId,
            title: title,
            description: description,
            published: published,
            durationMs: durationMs,
            sortOrder: sortOrder,
            fetchedAt: fetchedAt,
            localPath: localPath,
            chaptersJson: chaptersJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String audioUrl,
            required String feedId,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<DateTime?> published = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            required int sortOrder,
            required DateTime fetchedAt,
            Value<String?> localPath = const Value.absent(),
            Value<String?> chaptersJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodesCompanion.insert(
            audioUrl: audioUrl,
            feedId: feedId,
            title: title,
            description: description,
            published: published,
            durationMs: durationMs,
            sortOrder: sortOrder,
            fetchedAt: fetchedAt,
            localPath: localPath,
            chaptersJson: chaptersJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$EpisodesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({feedId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (feedId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.feedId,
                    referencedTable: $$EpisodesTableReferences._feedIdTable(db),
                    referencedColumn:
                        $$EpisodesTableReferences._feedIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$EpisodesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EpisodesTable,
    Episode,
    $$EpisodesTableFilterComposer,
    $$EpisodesTableOrderingComposer,
    $$EpisodesTableAnnotationComposer,
    $$EpisodesTableCreateCompanionBuilder,
    $$EpisodesTableUpdateCompanionBuilder,
    (Episode, $$EpisodesTableReferences),
    Episode,
    PrefetchHooks Function({bool feedId})>;
typedef $$PlaybackPositionsTableTableCreateCompanionBuilder
    = PlaybackPositionsTableCompanion Function({
  required String audioUrl,
  required int positionMs,
  Value<bool> completed,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$PlaybackPositionsTableTableUpdateCompanionBuilder
    = PlaybackPositionsTableCompanion Function({
  Value<String> audioUrl,
  Value<int> positionMs,
  Value<bool> completed,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PlaybackPositionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaybackPositionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackPositionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackPositionsTableTable> {
  $$PlaybackPositionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackPositionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackPositionsTableTable,
    PlaybackPositionsTableData,
    $$PlaybackPositionsTableTableFilterComposer,
    $$PlaybackPositionsTableTableOrderingComposer,
    $$PlaybackPositionsTableTableAnnotationComposer,
    $$PlaybackPositionsTableTableCreateCompanionBuilder,
    $$PlaybackPositionsTableTableUpdateCompanionBuilder,
    (
      PlaybackPositionsTableData,
      BaseReferences<_$AppDatabase, $PlaybackPositionsTableTable,
          PlaybackPositionsTableData>
    ),
    PlaybackPositionsTableData,
    PrefetchHooks Function()> {
  $$PlaybackPositionsTableTableTableManager(
      _$AppDatabase db, $PlaybackPositionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackPositionsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackPositionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackPositionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> audioUrl = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
            Value<bool> completed = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackPositionsTableCompanion(
            audioUrl: audioUrl,
            positionMs: positionMs,
            completed: completed,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String audioUrl,
            required int positionMs,
            Value<bool> completed = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaybackPositionsTableCompanion.insert(
            audioUrl: audioUrl,
            positionMs: positionMs,
            completed: completed,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackPositionsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PlaybackPositionsTableTable,
        PlaybackPositionsTableData,
        $$PlaybackPositionsTableTableFilterComposer,
        $$PlaybackPositionsTableTableOrderingComposer,
        $$PlaybackPositionsTableTableAnnotationComposer,
        $$PlaybackPositionsTableTableCreateCompanionBuilder,
        $$PlaybackPositionsTableTableUpdateCompanionBuilder,
        (
          PlaybackPositionsTableData,
          BaseReferences<_$AppDatabase, $PlaybackPositionsTableTable,
              PlaybackPositionsTableData>
        ),
        PlaybackPositionsTableData,
        PrefetchHooks Function()>;
typedef $$PlayQueueTableTableCreateCompanionBuilder = PlayQueueTableCompanion
    Function({
  Value<int> id,
  required String audioUrl,
  required String episodeTitle,
  required String podcastTitle,
  required String feedId,
  Value<int?> durationMs,
  Value<String?> localPath,
  Value<String?> chaptersJson,
});
typedef $$PlayQueueTableTableUpdateCompanionBuilder = PlayQueueTableCompanion
    Function({
  Value<int> id,
  Value<String> audioUrl,
  Value<String> episodeTitle,
  Value<String> podcastTitle,
  Value<String> feedId,
  Value<int?> durationMs,
  Value<String?> localPath,
  Value<String?> chaptersJson,
});

class $$PlayQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlayQueueTableTable> {
  $$PlayQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get episodeTitle => $composableBuilder(
      column: $table.episodeTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get podcastTitle => $composableBuilder(
      column: $table.podcastTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get feedId => $composableBuilder(
      column: $table.feedId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson, builder: (column) => ColumnFilters(column));
}

class $$PlayQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayQueueTableTable> {
  $$PlayQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioUrl => $composableBuilder(
      column: $table.audioUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get episodeTitle => $composableBuilder(
      column: $table.episodeTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get podcastTitle => $composableBuilder(
      column: $table.podcastTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get feedId => $composableBuilder(
      column: $table.feedId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson,
      builder: (column) => ColumnOrderings(column));
}

class $$PlayQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayQueueTableTable> {
  $$PlayQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get episodeTitle => $composableBuilder(
      column: $table.episodeTitle, builder: (column) => column);

  GeneratedColumn<String> get podcastTitle => $composableBuilder(
      column: $table.podcastTitle, builder: (column) => column);

  GeneratedColumn<String> get feedId =>
      $composableBuilder(column: $table.feedId, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
      column: $table.chaptersJson, builder: (column) => column);
}

class $$PlayQueueTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayQueueTableTable,
    PlayQueueTableData,
    $$PlayQueueTableTableFilterComposer,
    $$PlayQueueTableTableOrderingComposer,
    $$PlayQueueTableTableAnnotationComposer,
    $$PlayQueueTableTableCreateCompanionBuilder,
    $$PlayQueueTableTableUpdateCompanionBuilder,
    (
      PlayQueueTableData,
      BaseReferences<_$AppDatabase, $PlayQueueTableTable, PlayQueueTableData>
    ),
    PlayQueueTableData,
    PrefetchHooks Function()> {
  $$PlayQueueTableTableTableManager(
      _$AppDatabase db, $PlayQueueTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> audioUrl = const Value.absent(),
            Value<String> episodeTitle = const Value.absent(),
            Value<String> podcastTitle = const Value.absent(),
            Value<String> feedId = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> chaptersJson = const Value.absent(),
          }) =>
              PlayQueueTableCompanion(
            id: id,
            audioUrl: audioUrl,
            episodeTitle: episodeTitle,
            podcastTitle: podcastTitle,
            feedId: feedId,
            durationMs: durationMs,
            localPath: localPath,
            chaptersJson: chaptersJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String audioUrl,
            required String episodeTitle,
            required String podcastTitle,
            required String feedId,
            Value<int?> durationMs = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> chaptersJson = const Value.absent(),
          }) =>
              PlayQueueTableCompanion.insert(
            id: id,
            audioUrl: audioUrl,
            episodeTitle: episodeTitle,
            podcastTitle: podcastTitle,
            feedId: feedId,
            durationMs: durationMs,
            localPath: localPath,
            chaptersJson: chaptersJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayQueueTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayQueueTableTable,
    PlayQueueTableData,
    $$PlayQueueTableTableFilterComposer,
    $$PlayQueueTableTableOrderingComposer,
    $$PlayQueueTableTableAnnotationComposer,
    $$PlayQueueTableTableCreateCompanionBuilder,
    $$PlayQueueTableTableUpdateCompanionBuilder,
    (
      PlayQueueTableData,
      BaseReferences<_$AppDatabase, $PlayQueueTableTable, PlayQueueTableData>
    ),
    PlayQueueTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FeedsTableTableManager get feeds =>
      $$FeedsTableTableManager(_db, _db.feeds);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$PlaybackPositionsTableTableTableManager get playbackPositionsTable =>
      $$PlaybackPositionsTableTableTableManager(
          _db, _db.playbackPositionsTable);
  $$PlayQueueTableTableTableManager get playQueueTable =>
      $$PlayQueueTableTableTableManager(_db, _db.playQueueTable);
}
