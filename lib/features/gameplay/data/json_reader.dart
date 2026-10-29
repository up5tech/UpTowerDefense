import 'dart:convert';

import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Typed, path-aware reading of authored content.
///
/// Every failure throws [ContentFormatException] naming the field, which is what
/// makes content mistakes readable in a test failure or a debug build.
abstract final class JsonReader {
  /// Parses [source] and requires a JSON object at the root.
  static Map<String, Object?> decodeObject(String source) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException catch (error) {
      throw ContentFormatException('file is not valid JSON: ${error.message}');
    }

    if (raw is! Map<String, Object?>) {
      throw const ContentFormatException('the root must be a JSON object');
    }
    return raw;
  }

  static Map<String, Object?> requireObject(Object? value, String path) {
    if (value is! Map<String, Object?>) {
      throw ContentFormatException('$path must be an object');
    }
    return value;
  }

  static List<Object?> requireList(Object? value, String path) {
    if (value is! List<Object?>) {
      throw ContentFormatException('$path must be a list');
    }
    return value;
  }

  static String requireString(
    Map<String, Object?> json,
    String key, {
    String? parent,
  }) {
    final value = json[key];
    final path = _path(parent, key);
    if (value is! String || value.trim().isEmpty) {
      throw ContentFormatException('$path must be a non-empty string');
    }
    return value;
  }

  static double requireNumber(
    Map<String, Object?> json,
    String key, {
    String? parent,
  }) {
    final value = json[key];
    final path = _path(parent, key);
    if (value is! num) {
      throw ContentFormatException('$path must be a number');
    }
    return value.toDouble();
  }

  static int requireInt(
    Map<String, Object?> json,
    String key, {
    String? parent,
  }) {
    final value = json[key];
    final path = _path(parent, key);
    if (value is! int) {
      throw ContentFormatException('$path must be an integer');
    }
    return value;
  }

  /// Reads an optional number, treating an absent key as [fallback].
  static double optionalNumber(
    Map<String, Object?> json,
    String key, {
    String? parent,
    double fallback = 0,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    final path = _path(parent, key);
    if (value is! num) {
      throw ContentFormatException('$path must be a number');
    }
    return value.toDouble();
  }

  /// Reads an optional boolean, falling back when absent or null.
  ///
  /// Mode flags (`endless`) default off so every older content file keeps
  /// loading unchanged; a present-but-non-boolean value is a content mistake
  /// and is reported, never coerced.
  static bool optionalBool(
    Map<String, Object?> json,
    String key, {
    String? parent,
    bool fallback = false,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is! bool) {
      throw ContentFormatException('${_path(parent, key)} must be a boolean');
    }
    return value;
  }

  /// Reads a `#RRGGBB` or `#AARRGGBB` colour into an ARGB integer.
  ///
  /// Shared by enemies and towers so both content files accept the same colour
  /// syntax and report the same mistakes.
  static int requireColor(
    Map<String, Object?> json,
    String key, {
    String? parent,
  }) {
    final value = requireString(json, key, parent: parent);
    final path = _path(parent, key);
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6 && hex.length != 8) {
      throw ContentFormatException('$path must be #RRGGBB or #AARRGGBB');
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      throw ContentFormatException('$path is not a hexadecimal colour');
    }
    return hex.length == 6 ? 0xFF000000 | parsed : parsed;
  }

  /// Reads a `[x, y]` pair.
  static List<double> requirePoint(Object? value, String path) {
    if (value is! List<Object?> || value.length != 2) {
      throw ContentFormatException('$path must be a [x, y] pair');
    }
    final x = value[0];
    final y = value[1];
    if (x is! num || y is! num) {
      throw ContentFormatException('$path must contain two numbers');
    }
    return [x.toDouble(), y.toDouble()];
  }

  /// Reads a `[x, y]` pair as a domain point.
  static WorldPoint requireWorldPoint(Object? value, String path) {
    final point = requirePoint(value, path);
    return WorldPoint(point[0], point[1]);
  }

  static String _path(String? parent, String key) {
    return parent == null ? key : '$parent.$key';
  }
}
