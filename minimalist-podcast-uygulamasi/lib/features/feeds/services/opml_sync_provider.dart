import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'opml_sync_service.dart';

final opmlSyncServiceProvider = Provider((ref) => OpmlSyncService());
