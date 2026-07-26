import 'dart:io';

bool get isDesktop =>
    !identical(0, 0.0) && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
