import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

final baseColor = Color(0x121212);

final darkTheme = ThemeData(
  colorScheme: ColorScheme(
    surface: Color(0xFF09101D),
    error: Colors.red[800] ?? Colors.red,
    primary: Colors.blue[600] ?? Colors.blue,
    secondary: Colors.blueGrey[600] ?? Colors.blueGrey,
    primaryVariant: Colors.blue[800] ?? Colors.blue,
    secondaryVariant: Colors.blueGrey[800] ?? Colors.blueGrey,
    background: Colors.blue[600] ?? Colors.blue,
    brightness: Brightness.dark,
    onBackground: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    onError: Colors.white,
  ),
  canvasColor: const Color(0xFF1B212C),
  dialogBackgroundColor: const Color(0xFF131B27),
  cardTheme: CardTheme(
    shadowColor: Colors.white,
    color: const Color(0xFF131B27),
    elevation: 2,
  ),
  primarySwatch: Colors.blue,
  primaryColor: Colors.lightBlue[800],
  brightness: Brightness.dark,
  backgroundColor: const Color(0xFF1B212C),
  scaffoldBackgroundColor: const Color(0xFF09101D),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.blue[300],
    foregroundColor: Colors.white,
  ),
  visualDensity: VisualDensity.adaptivePlatformDensity,
  dividerTheme: DividerThemeData(
    space: 0,
    endIndent: 0,
    indent: 0,
    color: Colors.lightBlue[800],
  ),
  dataTableTheme: DataTableThemeData(
    headingTextStyle: TextStyle(
      color: Colors.blue[300],
      fontWeight: FontWeight.bold,
    ),
  ),
  bottomAppBarColor: const Color(0xFF1B212C),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF1B212C),
  ),
);

final lightColorScheme = ColorScheme(
  surface: Colors.white,
  error: Colors.red[200] ?? Colors.red,
  primary: Colors.blue[600] ?? Colors.blue,
  secondary: Colors.blueGrey[600] ?? Colors.blueGrey,
  primaryVariant: Colors.blue[800] ?? Colors.blue,
  secondaryVariant: Colors.blueGrey[800] ?? Colors.blueGrey,
  background: Colors.blue,
  brightness: Brightness.light,
  onBackground: Color(0xFF121212),
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onSurface: Colors.white,
  onError: Colors.white,
);

final lightTheme = ThemeData(
  colorScheme: lightColorScheme,
  brightness: Brightness.light,
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  dividerTheme: DividerThemeData(
    space: 0,
    endIndent: 0,
    indent: 0,
    color: Colors.lightBlue[800],
  ),
  dataTableTheme: DataTableThemeData(
    headingTextStyle: TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    ),
  ),
);
