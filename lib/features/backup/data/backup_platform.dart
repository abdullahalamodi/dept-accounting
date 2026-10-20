import 'package:flutter/foundation.dart';

bool get supportsExternalBackup => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => false,
  _ => true,
};
