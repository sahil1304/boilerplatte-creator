import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FuturisticGlassPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  const FuturisticGlassPanel({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
  });
  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0x44B388FF),
            const Color(0x220D001A),
            const Color(0x33A259FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          width: 2.5,
          color: const Color(0xFFB388FF).withOpacity(0.5),
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: panel,
      ),
    );
  }
}

// Enhanced SharedPreferences helper for patch files with better persistence
class PatchPreferencesHelper {
  static const String _savedPatchesKey = 'saved_patches_v2_';
  static const String _patchEntriesKey = 'patch_entries_v2_';
  static const String _lastProjectKey = 'last_project_path';

  // Save the last used project path
  static Future<void> saveLastProjectPath(String projectPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProjectKey, projectPath);
  }

  // Load the last used project path
  static Future<String?> getLastProjectPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastProjectKey);
  }

  // Save patch files metadata to SharedPreferences with validation
  static Future<void> savePatchFiles(String projectPath, List<SavedPatchFile> patchFiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _savedPatchesKey + _sanitizeProjectPath(projectPath);

      final List<Map<String, dynamic>> patchData = patchFiles.map((patch) => {
        'fileName': patch.fileName,
        'filePath': patch.filePath,
        'createdAt': patch.createdAt.millisecondsSinceEpoch,
        'entriesCount': patch.entriesCount,
        'flutterCommands': patch.flutterCommands, // Include Flutter commands
      }).toList();

      final jsonData = jsonEncode(patchData);
      await prefs.setString(key, jsonData);

      // Also save a backup timestamp
      await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      print('✅ Successfully saved ${patchFiles.length} patch files to SharedPreferences');
    } catch (e) {
      print('❌ Error saving patch files: $e');
      rethrow;
    }
  }

  // Load patch files metadata from SharedPreferences with validation
  static Future<List<SavedPatchFile>> loadPatchFiles(String projectPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _savedPatchesKey + _sanitizeProjectPath(projectPath);

      final String? patchDataJson = prefs.getString(key);
      if (patchDataJson == null || patchDataJson.isEmpty) {
        print('ℹ️ No patch files found in SharedPreferences for project: $projectPath');
        return [];
      }

      final List<dynamic> patchData = jsonDecode(patchDataJson);
      final patchFiles = patchData.map((data) {
        // Validate required fields
        if (data['fileName'] == null || data['filePath'] == null || data['createdAt'] == null) {
          print('⚠️ Invalid patch file data found, skipping: $data');
          return null;
        }

        return SavedPatchFile(
          fileName: data['fileName'].toString(),
          filePath: data['filePath'].toString(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
          entriesCount: data['entriesCount'] as int? ?? 0,
          flutterCommands: List<String>.from(data['flutterCommands'] ?? []), // Load Flutter commands
        );
      }).where((patch) => patch != null).cast<SavedPatchFile>().toList();

      print('✅ Successfully loaded ${patchFiles.length} patch files from SharedPreferences');
      return patchFiles;
    } catch (e) {
      print('❌ Error loading patch files from SharedPreferences: $e');
      return [];
    }
  }

  // Save patch entries to SharedPreferences with validation
  static Future<void> savePatchEntries(String projectPath, List<PatchFileEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _patchEntriesKey + _sanitizeProjectPath(projectPath);

      final List<Map<String, dynamic>> entriesData = entries.map((entry) => {
        'folderName': entry.folderName,
        'fileName': entry.fileName,
        'fileContent': entry.fileContent,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }).toList();

      final jsonData = jsonEncode(entriesData);
      await prefs.setString(key, jsonData);

      // Also save a backup timestamp
      await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      print('✅ Successfully saved ${entries.length} patch entries to SharedPreferences');
    } catch (e) {
      print('❌ Error saving patch entries: $e');
      rethrow;
    }
  }

  // Load patch entries from SharedPreferences with validation
  static Future<List<PatchFileEntry>> loadPatchEntries(String projectPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _patchEntriesKey + _sanitizeProjectPath(projectPath);

      final String? entriesDataJson = prefs.getString(key);
      if (entriesDataJson == null || entriesDataJson.isEmpty) {
        print('ℹ️ No patch entries found in SharedPreferences for project: $projectPath');
        return [];
      }

      final List<dynamic> entriesData = jsonDecode(entriesDataJson);
      final entries = entriesData.map((data) {
        // Validate required fields
        if (data['folderName'] == null || data['fileName'] == null || data['fileContent'] == null) {
          print('⚠️ Invalid patch entry data found, skipping: $data');
          return null;
        }

        return PatchFileEntry(
          folderName: data['folderName'].toString(),
          fileName: data['fileName'].toString(),
          fileContent: data['fileContent'].toString(),
        );
      }).where((entry) => entry != null).cast<PatchFileEntry>().toList();

      print('✅ Successfully loaded ${entries.length} patch entries from SharedPreferences');
      return entries;
    } catch (e) {
      print('❌ Error loading patch entries from SharedPreferences: $e');
      return [];
    }
  }

  // Remove patch file from SharedPreferences
  static Future<void> removePatchFile(String projectPath, String fileName) async {
    try {
      final patchFiles = await loadPatchFiles(projectPath);
      final updatedPatchFiles = patchFiles.where((patch) => patch.fileName != fileName).toList();
      await savePatchFiles(projectPath, updatedPatchFiles);
      print('✅ Successfully removed patch file: $fileName');
    } catch (e) {
      print('❌ Error removing patch file: $e');
      rethrow;
    }
  }

  // Clear patch entries for a project (but keep them until patch is created)
  static Future<void> clearPatchEntries(String projectPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _patchEntriesKey + _sanitizeProjectPath(projectPath);
      await prefs.remove(key);
      await prefs.remove('${key}_timestamp');
      print('✅ Successfully cleared patch entries for project: $projectPath');
    } catch (e) {
      print('❌ Error clearing patch entries: $e');
    }
  }

  // Get all project paths that have saved data
  static Future<List<String>> getAllProjectPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final Set<String> projectPaths = {};
      for (final key in keys) {
        if (key.startsWith(_savedPatchesKey)) {
          final projectPath = key.substring(_savedPatchesKey.length);
          projectPaths.add(_desanitizeProjectPath(projectPath));
        } else if (key.startsWith(_patchEntriesKey)) {
          final projectPath = key.substring(_patchEntriesKey.length);
          projectPaths.add(_desanitizeProjectPath(projectPath));
        }
      }

      return projectPaths.toList();
    } catch (e) {
      print('❌ Error getting all project paths: $e');
      return [];
    }
  }

  // Clean up preferences for non-existent projects
  static Future<void> cleanupPreferences() async {
    try {
      final projectPaths = await getAllProjectPaths();
      final prefs = await SharedPreferences.getInstance();
      int cleanedCount = 0;

      for (final projectPath in projectPaths) {
        if (!await Directory(projectPath).exists()) {
          final sanitizedPath = _sanitizeProjectPath(projectPath);
          await prefs.remove(_savedPatchesKey + sanitizedPath);
          await prefs.remove(_patchEntriesKey + sanitizedPath);
          await prefs.remove('${_savedPatchesKey}${sanitizedPath}_timestamp');
          await prefs.remove('${_patchEntriesKey}${sanitizedPath}_timestamp');
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        print('✅ Cleaned up preferences for $cleanedCount non-existent projects');
      }
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  // Backup all data to a JSON file
  static Future<String?> backupAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      final Map<String, dynamic> backup = {};
      for (final key in keys) {
        if (key.startsWith(_savedPatchesKey) || key.startsWith(_patchEntriesKey) || key == _lastProjectKey) {
          final value = prefs.get(key);
          backup[key] = value;
        }
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final backupFile = File(p.join(documentsDirectory.path, 'patch_backup_${DateTime.now().millisecondsSinceEpoch}.json'));

      await backupFile.writeAsString(jsonEncode(backup));
      print('✅ Backup created at: ${backupFile.path}');
      return backupFile.path;
    } catch (e) {
      print('❌ Error creating backup: $e');
      return null;
    }
  }

  // Debug: Print all stored data
  static Future<void> debugPrintAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) =>
      key.startsWith(_savedPatchesKey) ||
          key.startsWith(_patchEntriesKey) ||
          key == _lastProjectKey
      ).toList();

      print('\n🔍 DEBUG: All stored patch data:');
      print('─' * 50);

      for (final key in keys) {
        final value = prefs.get(key);
        print('Key: $key');
        print('Type: ${value.runtimeType}');
        if (value is String && value.length > 100) {
          print('Value: ${value.substring(0, 100)}...');
        } else {
          print('Value: $value');
        }
        print('─' * 30);
      }

      if (keys.isEmpty) {
        print('No patch data found in SharedPreferences');
      }

      print('🔍 DEBUG: End of data\n');
    } catch (e) {
      print('❌ Error during debug print: $e');
    }
  }

  // Sanitize project path for use as SharedPreferences key
  static String _sanitizeProjectPath(String path) {
    return path.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }

  // Reverse sanitization to get original project path
  static String _desanitizeProjectPath(String sanitizedPath) {
    return sanitizedPath.replaceAll('_', '/');
  }

  // Add this helper to get the fixed storage directory inside the main project
  static Future<String> getFixedStorageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final fixedDir = Directory(p.join(dir.path, 'app_data', 'patches'));
    if (!await fixedDir.exists()) {
      await fixedDir.create(recursive: true);
    }
    return fixedDir.path;
  }

  // In PatchPreferencesHelper, update save/load methods to use a normalized key (e.g., repo name or hash) instead of full project path
  static String _normalizeRepoIdentifier(String repoUrl) {
    // Use repo name or a hash of the URL for uniqueness
    return p.basenameWithoutExtension(Uri.parse(repoUrl).path);
  }
}

// Database helper class for patch files (keeping for future use)
class PatchDatabaseHelper {
  static final PatchDatabaseHelper _instance = PatchDatabaseHelper._internal();
  factory PatchDatabaseHelper() => _instance;
  PatchDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'patch_files.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patch_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_path TEXT NOT NULL,
        folder_name TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_patches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_path TEXT NOT NULL,
        patch_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        entries_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // Patch entries methods
  Future<int> insertPatchEntry(String projectPath, PatchFileEntry entry) async {
    final db = await database;
    return await db.insert('patch_entries', {
      'project_path': projectPath,
      'folder_name': entry.folderName,
      'file_name': entry.fileName,
      'file_content': entry.fileContent,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<PatchFileEntry>> getPatchEntries(String projectPath) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patch_entries',
      where: 'project_path = ?',
      whereArgs: [projectPath],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return PatchFileEntry(
        folderName: maps[i]['folder_name'],
        fileName: maps[i]['file_name'],
        fileContent: maps[i]['file_content'],
      );
    });
  }

  Future<void> deletePatchEntry(String projectPath, int index) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patch_entries',
      where: 'project_path = ?',
      whereArgs: [projectPath],
      orderBy: 'created_at ASC',
    );

    if (index < maps.length) {
      await db.delete(
        'patch_entries',
        where: 'id = ?',
        whereArgs: [maps[index]['id']],
      );
    }
  }

  Future<void> clearPatchEntries(String projectPath) async {
    final db = await database;
    await db.delete(
      'patch_entries',
      where: 'project_path = ?',
      whereArgs: [projectPath],
    );
  }

  // Saved patches methods
  Future<int> insertSavedPatch(String projectPath, SavedPatchFile patch) async {
    final db = await database;
    return await db.insert('saved_patches', {
      'project_path': projectPath,
      'patch_name': patch.fileName,
      'file_path': patch.filePath,
      'entries_count': patch.entriesCount,
      'created_at': patch.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<SavedPatchFile>> getSavedPatches(String projectPath) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saved_patches',
      where: 'project_path = ?',
      whereArgs: [projectPath],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return SavedPatchFile(
        fileName: maps[i]['patch_name'],
        filePath: maps[i]['file_path'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(maps[i]['created_at']),
        entriesCount: maps[i]['entries_count'],
      );
    });
  }

  Future<void> deleteSavedPatch(String projectPath, String fileName) async {
    final db = await database;
    await db.delete(
      'saved_patches',
      where: 'project_path = ? AND patch_name = ?',
      whereArgs: [projectPath, fileName],
    );
  }

  // Clean up old entries for non-existent projects
  Future<void> cleanupOldEntries() async {
    final db = await database;

    // Get all unique project paths
    final projectPaths = await db.rawQuery('''
      SELECT DISTINCT project_path FROM patch_entries
      UNION
      SELECT DISTINCT project_path FROM saved_patches
    ''');

    for (final pathMap in projectPaths) {
      final projectPath = pathMap['project_path'] as String;
      if (!await Directory(projectPath).exists()) {
        // Remove entries for non-existent projects
        await db.delete('patch_entries', where: 'project_path = ?', whereArgs: [projectPath]);
        await db.delete('saved_patches', where: 'project_path = ?', whereArgs: [projectPath]);
      }
    }
  }
}

// New class for patch file entry
class PatchFileEntry {
  String folderName;
  String fileName;
  String fileContent;

  PatchFileEntry({
    required this.folderName,
    required this.fileName,
    required this.fileContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'folderName': folderName,
      'fileName': fileName,
      'fileContent': fileContent,
    };
  }

  factory PatchFileEntry.fromJson(Map<String, dynamic> json) {
    return PatchFileEntry(
      folderName: json['folderName'] ?? '',
      fileName: json['fileName'] ?? '',
      fileContent: json['fileContent'] ?? '',
    );
  }
}

// Enhanced SavedPatchFile class with Flutter commands support
class SavedPatchFile {
  String fileName;
  String filePath;
  DateTime createdAt;
  int entriesCount;
  List<String> flutterCommands; // Flutter commands to execute after applying patch

  SavedPatchFile({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.entriesCount,
    this.flutterCommands = const [], // Default to empty list
  });

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'entriesCount': entriesCount,
      'flutterCommands': flutterCommands, // Include Flutter commands in JSON
    };
  }

  factory SavedPatchFile.fromJson(Map<String, dynamic> json) {
    return SavedPatchFile(
      fileName: json['fileName'] ?? '',
      filePath: json['filePath'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      entriesCount: json['entriesCount'] ?? 0,
      flutterCommands: List<String>.from(json['flutterCommands'] ?? []), // Load Flutter commands
    );
  }
}

void main() {
  runApp(const GitRepoReaderApp());
}

class GitRepoReaderApp extends StatelessWidget {
  const GitRepoReaderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Repo Reader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: const Color(0xFFB388FF),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFB388FF),
          secondary: const Color(0xFF00E5FF),
          background: Colors.transparent,
          surface: Colors.transparent,
        ),
        cardColor: const Color(0x220D001A),
        dialogBackgroundColor: const Color(0x330D001A),
        canvasColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x22B388FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB388FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFB388FF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB388FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 16),
            shadowColor: const Color(0xFFB388FF),
            elevation: 10,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          checkColor: MaterialStateProperty.all(Colors.black),
        ),
        textTheme: GoogleFonts.orbitronTextTheme(
          const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            bodySmall: TextStyle(color: Colors.white60),
            titleLarge: TextStyle(color: Color(0xFFB388FF), fontWeight: FontWeight.bold),
            titleMedium: TextStyle(color: Color(0xFFB388FF)),
          ),
        ),
        dividerColor: Colors.white24,
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF), shadows: [Shadow(color: Color(0xFFB388FF), blurRadius: 8)]),
      ),
      home: const RepoReaderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RepoReaderScreen extends StatefulWidget {
  const RepoReaderScreen({super.key});

  @override
  State<RepoReaderScreen> createState() => _RepoReaderScreenState();
}

class _RepoReaderScreenState extends State<RepoReaderScreen> with TickerProviderStateMixin {
  String? folderPath;
  String result = '';
  bool isCloning = false;
  bool isLoading = false;
  bool isCreatingPatch = false;
  double mergeProgress = 0.0; // Progress for merge operation

  // Current selected tab index for vertical sidebar
  int selectedTabIndex = 0;

  // Database helper instance
  final PatchDatabaseHelper _dbHelper = PatchDatabaseHelper();

  // Hardcoded repository URL
  static const String repoUrl = "https://github.com/SahilJadhav12/mergingdemo.git";

  // Controller for folder name input
  final TextEditingController _folderNameController = TextEditingController();

  // Controllers for patch file creation
  final TextEditingController _patchFolderController = TextEditingController();
  final TextEditingController _patchFileNameController = TextEditingController();
  final TextEditingController _patchFileContentController = TextEditingController();
  final TextEditingController _customPatchNameController = TextEditingController();
  final TextEditingController _flutterCommandController = TextEditingController(); // New controller for Flutter commands

  // List to store multiple patch file entries (now loaded from SharedPreferences)
  List<PatchFileEntry> patchEntries = [];

  // List to store saved patch files (now loaded from SharedPreferences)
  List<SavedPatchFile> savedPatchFiles = [];

  // List to store Flutter commands for the current patch
  List<String> flutterCommands = [];

  List<String> localBranches = [];
  List<String> remoteBranches = [];
  List<String> allBranches = []; // Combined list for merge operations

  // New categorized branch lists
  List<String> widgetBranches = [];
  List<String> featureBranches = [];

  // For merge operations
  Set<String> selectedSourceBranches = <String>{};
  String destinationBranch = "main"; // Always set to "main"

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      result += 'Initializing app...\n';
    });

    try {
      // Initialize database
      await _dbHelper.database;

      // Clean up old entries
      await _dbHelper.cleanupOldEntries();
      await PatchPreferencesHelper.cleanupPreferences();

      // Try to restore last project
      final lastProject = await PatchPreferencesHelper.getLastProjectPath();
      if (lastProject != null && await Directory(lastProject).exists()) {
        setState(() {
          folderPath = lastProject;
          result += 'Restored last project: $lastProject\n';
        });

        // Load data for the restored project
        await _loadProjectData();
      }

      setState(() {
        result += 'App initialized successfully!\n';
      });

      // Debug: Print all stored data
      await PatchPreferencesHelper.debugPrintAllData();

    } catch (e) {
      setState(() {
        result += 'Error during initialization: $e\n';
      });
    }
  }

  Future<void> _loadProjectData() async {
    if (folderPath == null) return;

    try {
      await loadBranches();
      await loadSavedPatchFiles();
      await _loadPatchEntriesFromPreferences();
    } catch (e) {
      setState(() {
        result += 'Error loading project data: $e\n';
      });
    }
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _patchFolderController.dispose();
    _patchFileNameController.dispose();
    _patchFileContentController.dispose();
    _customPatchNameController.dispose();
    _flutterCommandController.dispose();
    super.dispose();
  }

  // Load patch entries from SharedPreferences when project is selected
  Future<void> _loadPatchEntriesFromPreferences() async {
    if (folderPath == null) return;

    try {
      final entries = await PatchPreferencesHelper.loadPatchEntries(folderPath!);
      setState(() {
        patchEntries = entries;
      });

      if (entries.isNotEmpty) {
        setState(() {
          result += '✅ Loaded ${entries.length} patch entries from persistent storage.\n';
        });
      }
    } catch (e) {
      setState(() {
        result += '❌ Error loading patch entries from persistent storage: $e\n';
      });
    }
  }

  // Save patch entry to SharedPreferences
  Future<void> _savePatchEntryToPreferences() async {
    if (folderPath == null) return;

    try {
      await PatchPreferencesHelper.savePatchEntries(folderPath!, patchEntries);
    } catch (e) {
      setState(() {
        result += '❌ Error saving patch entries to persistent storage: $e\n';
      });
    }
  }

  // Helper function to get display name (without prefixes)
  String getDisplayName(String branchName) {
    return branchName
        .replaceAll('origin/widget-', '')
        .replaceAll('origin/widget_', '')
        .replaceAll('origin/feature-', '')
        .replaceAll('widget-', '')
        .replaceAll('widget_', '')
        .replaceAll('feature-', '');
  }

  // Find Git executable in common locations
  Future<String?> findGitExecutable() async {
    final possiblePaths = [
      '/usr/bin/git',
      '/usr/local/bin/git',
      '/opt/homebrew/bin/git',
    ];

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists()) {
        return path;
      }
    }

    // Try using 'which' command
    try {
      final result = await Process.run('which', ['git']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      print('Error finding git with which: $e');
    }

    return null;
  }

  // Helper method to parse Flutter commands from patch file content
  List<String> _parseFlutterCommandsFromPatchContent(String content) {
    final List<String> commands = [];
    final lines = content.split('\n');

    print('🔍 Parsing Flutter commands from patch content...');
    print('Content preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...');

    for (final line in lines) {
      if (line.startsWith('# Commands: ')) {
        final commandsStr = line.substring('# Commands: '.length);
        print('🔍 Found commands line: $commandsStr');

        // Parse commands like "flutter pub get, flutter build" into individual commands
        final commandParts = commandsStr.split(', ');
        for (final part in commandParts) {
          if (part.startsWith('flutter ')) {
            // Remove 'flutter ' prefix to get just the command
            final command = part.substring('flutter '.length);
            commands.add(command);
            print('🔍 Parsed command: $command');
          }
        }
        break; // Found the commands line, no need to continue
      }
    }

    print('🔍 Total commands parsed: ${commands.length}');
    return commands;
  }

  // Helper method to compare two lists of Flutter commands
  bool _areFlutterCommandsEqual(List<String> commands1, List<String> commands2) {
    if (commands1.length != commands2.length) return false;
    for (int i = 0; i < commands1.length; i++) {
      if (commands1[i] != commands2[i]) return false;
    }
    return true;
  }

  // Method to refresh saved patches and re-parse Flutter commands from content
  Future<void> refreshSavedPatches() async {
    setState(() {
      result += '\n--- Refreshing Saved Patch Files ---\n';
    });

    try {
      final repoKey = PatchPreferencesHelper._normalizeRepoIdentifier(repoUrl);
      final patchesBasePath = await PatchPreferencesHelper.getFixedStorageDir();
      final patchesDir = Directory(patchesBasePath);

      if (await patchesDir.exists()) {
        final patchFiles = await patchesDir.list()
            .where((entity) => entity is File && entity.path.endsWith('.patch'))
            .cast<File>()
            .toList();

        List<SavedPatchFile> refreshedPatches = [];

        for (final patchFile in patchFiles) {
          final fileName = p.basename(patchFile.path);
          final stat = await patchFile.stat();
          final content = await patchFile.readAsString();
          final entriesCount = 'diff --git'.allMatches(content).length;
          final flutterCommands = _parseFlutterCommandsFromPatchContent(content);

          final refreshedPatch = SavedPatchFile(
            fileName: fileName,
            filePath: patchFile.path,
            createdAt: stat.modified,
            entriesCount: entriesCount,
            flutterCommands: flutterCommands,
          );

          refreshedPatches.add(refreshedPatch);
          setState(() {
            result += '✅ Refreshed ${fileName}: ${flutterCommands.length} Flutter commands\n';
          });
        }

        // Save refreshed patches to SharedPreferences
        await PatchPreferencesHelper.savePatchFiles(repoKey, refreshedPatches);

        setState(() {
          savedPatchFiles = refreshedPatches;
          result += '✅ All patches refreshed and saved to persistent storage.\n';
        });
      }
    } catch (e) {
      setState(() {
        result += '❌ Error refreshing saved patch files: $e\n';
      });
    }
  }

  // Enhanced method to load saved patch files with better persistence
  Future<void> loadSavedPatchFiles() async {
    setState(() {
      savedPatchFiles.clear();
      result += '\n--- Loading Saved Patch Files ---\n';
    });

    try {
      // Use the fixed storage directory for patch files
      final patchesBasePath = await PatchPreferencesHelper.getFixedStorageDir();
      final patchesDir = Directory(patchesBasePath);
      List<SavedPatchFile> validPatches = [];
      bool prefsNeedUpdate = false;

      // Load from SharedPreferences with enhanced validation using normalized repo identifier
      final repoKey = PatchPreferencesHelper._normalizeRepoIdentifier(repoUrl);
      List<SavedPatchFile> prefsPatches = await PatchPreferencesHelper.loadPatchFiles(repoKey);

      // Verify files still exist and update metadata
      for (final patch in prefsPatches) {
        final file = File(patch.filePath);
        if (await file.exists()) {
          // File exists, verify metadata is still accurate
          final stat = await file.stat();
          final content = await file.readAsString();
          final entriesCount = 'diff --git'.allMatches(content).length;

          // Parse Flutter commands from the patch file content to ensure they're up to date
          final flutterCommands = _parseFlutterCommandsFromPatchContent(content);
          print('🔍 Existing patch ${patch.fileName} has ${patch.flutterCommands.length} stored commands and ${flutterCommands.length} parsed commands');

          // Update if metadata has changed or Flutter commands are different
          if (patch.entriesCount != entriesCount ||
              patch.createdAt != stat.modified ||
              !_areFlutterCommandsEqual(patch.flutterCommands, flutterCommands)) {
            validPatches.add(SavedPatchFile(
              fileName: patch.fileName,
              filePath: patch.filePath,
              createdAt: stat.modified,
              entriesCount: entriesCount,
              flutterCommands: flutterCommands, // Use parsed commands from file content
            ));
            prefsNeedUpdate = true;
          } else {
            validPatches.add(patch);
          }
        } else {
          // File no longer exists, remove from preferences later
          prefsNeedUpdate = true;
        }
      }

      // Scan the fixed patches directory for any new files not in preferences
      if (await patchesDir.exists()) {
        final patchFiles = await patchesDir.list()
            .where((entity) => entity is File && entity.path.endsWith('.patch'))
            .cast<File>()
            .toList();

        for (final patchFile in patchFiles) {
          final fileName = p.basename(patchFile.path);

          // Check if this file is already in our preferences
          final existsInPrefs = validPatches.any((patch) => patch.fileName == fileName);

          if (!existsInPrefs) {
            // Add new file to preferences and parse Flutter commands from content
            final stat = await patchFile.stat();
            final content = await patchFile.readAsString();
            final entriesCount = 'diff --git'.allMatches(content).length;

            // Parse Flutter commands from the patch file content
            final flutterCommands = _parseFlutterCommandsFromPatchContent(content);
            print('🔍 Loaded ${flutterCommands.length} Flutter commands for file: $fileName');

            final newPatch = SavedPatchFile(
              fileName: fileName,
              filePath: patchFile.path,
              createdAt: stat.modified,
              entriesCount: entriesCount,
              flutterCommands: flutterCommands, // Parse commands from file content
            );

            validPatches.add(newPatch);
            prefsNeedUpdate = true;
          }
        }
      }

      // Update SharedPreferences if needed
      if (prefsNeedUpdate) {
        await PatchPreferencesHelper.savePatchFiles(repoKey, validPatches);
      }

      // Sort by creation date (newest first)
      validPatches.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        savedPatchFiles = validPatches;
        result += '✅ Loaded ${savedPatchFiles.length} saved patch files from persistent storage + fixed directory.\n';
      });

    } catch (e) {
      setState(() {
        result += '❌ Error loading saved patch files: $e\n';
      });
    }
  }

  // FIXED: Modified method to apply a saved patch file with proper Flutter commands execution
  Future<void> applySavedPatch(SavedPatchFile patchFile) async {
    if (folderPath == null) return;

    setState(() {
      result += '\n--- Applying Patch File ---\n';
      result += 'Applying: ${patchFile.fileName}\n';
      result += 'Flutter commands to execute: ${patchFile.flutterCommands.length}\n';
      if (patchFile.flutterCommands.isNotEmpty) {
        result += 'Commands: ${patchFile.flutterCommands.map((cmd) => 'flutter $cmd').join(', ')}\n';
      }
      isLoading = true;
    });

    try {
      // Apply the patch file
      final applyResult = await runGit(['apply', patchFile.filePath], folderPath!);

      setState(() {
        if (applyResult.contains('Error:')) {
          result += '❌ Failed to apply patch: $applyResult\n';
        } else {
          result += '✅ Patch applied successfully!\n';
          result += 'Applied ${patchFile.entriesCount} file(s) to the project.\n';
        }
      });

      // FIXED: Execute Flutter commands if patch was applied successfully and commands exist
      if (!applyResult.contains('Error:') && patchFile.flutterCommands.isNotEmpty) {
        setState(() {
          result += '\n--- Executing Flutter Commands ---\n';
          result += 'Found ${patchFile.flutterCommands.length} Flutter command(s) to execute:\n';
        });

        // Check if Flutter is available first
        final flutterPath = await findFlutterExecutable();
        if (flutterPath == null) {
          setState(() {
            result += '⚠️ Flutter not found. Skipping Flutter commands.\n';
            result += 'Commands that would have been executed:\n';
            for (int i = 0; i < patchFile.flutterCommands.length; i++) {
              result += '  ${i + 1}. flutter ${patchFile.flutterCommands[i]}\n';
            }
            result += 'Please install Flutter and run these commands manually.\n';
          });
        } else {
          setState(() {
            result += '✅ Flutter found at: $flutterPath\n';
          });

          // Execute each Flutter command sequentially
          for (int i = 0; i < patchFile.flutterCommands.length; i++) {
            final command = patchFile.flutterCommands[i];
            setState(() {
              result += '\n[${i + 1}/${patchFile.flutterCommands.length}] Running: flutter $command\n';
            });

            try {
              final flutterResult = await runFlutterCommand(command, folderPath!);
              setState(() {
                if (flutterResult.contains('Error:')) {
                  result += '❌ Command failed: $flutterResult\n';
                } else {
                  result += '✅ Command completed successfully\n';
                  // Only show first few lines of output to avoid clutter
                  final outputLines = flutterResult.split('\n');
                  final limitedOutput = outputLines.take(3).join('\n');
                  if (outputLines.length > 3) {
                    result += '$limitedOutput\n... (output truncated)\n';
                  } else {
                    result += '$limitedOutput\n';
                  }
                }
              });
            } catch (e) {
              setState(() {
                result += '❌ Error running Flutter command: $e\n';
              });
            }
          }

          setState(() {
            result += '\n✅ All Flutter commands completed!\n';
            result += '🎉 Patch applied successfully with ${patchFile.flutterCommands.length} Flutter command(s) executed!\n';
          });
        }
      } else if (patchFile.flutterCommands.isEmpty) {
        setState(() {
          result += '📝 No Flutter commands associated with this patch.\n';
        });
      }

    } catch (e) {
      setState(() {
        result += '❌ Error applying patch: $e\n';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Enhanced method to delete a saved patch file
  Future<void> deleteSavedPatch(SavedPatchFile patchFile) async {
    try {
      // Delete from file system
      final file = File(patchFile.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from SharedPreferences using the normalized repo key
      final repoKey = PatchPreferencesHelper._normalizeRepoIdentifier(repoUrl);
      await PatchPreferencesHelper.removePatchFile(repoKey, patchFile.fileName);

      setState(() {
        savedPatchFiles.remove(patchFile);
        result += '✅ Deleted patch file: ${patchFile.fileName}\n';
      });

    } catch (e) {
      setState(() {
        result += '❌ Error deleting patch file: $e\n';
      });
    }
  }

  // Enhanced method to add patch entry with immediate persistence
  Future<void> _addPatchEntry() async {
    if (_patchFolderController.text.trim().isEmpty ||
        _patchFileNameController.text.trim().isEmpty ||
        _patchFileContentController.text.trim().isEmpty) {
      setState(() {
        result += '\n⚠️ Please fill in all patch file fields.\n';
      });
      return;
    }

    final entry = PatchFileEntry(
      folderName: _patchFolderController.text.trim(),
      fileName: _patchFileNameController.text.trim(),
      fileContent: _patchFileContentController.text.trim(),
    );

    setState(() {
      patchEntries.add(entry);

      // Clear the input fields
      _patchFolderController.clear();
      _patchFileNameController.clear();
      _patchFileContentController.clear();

      result += '✅ Added patch entry: ${entry.folderName}/${entry.fileName}\n';
    });

    // Immediately save to SharedPreferences for persistence
    await _savePatchEntryToPreferences();
  }

  // Method to add Flutter command
  Future<void> _addFlutterCommand() async {
    if (_flutterCommandController.text.trim().isEmpty) {
      setState(() {
        result += '\n⚠️ Please enter a Flutter command.\n';
      });
      return;
    }

    final command = _flutterCommandController.text.trim();

    setState(() {
      flutterCommands.add(command);
      _flutterCommandController.clear();
      result += '✅ Added Flutter command: flutter $command\n';
    });
  }

  // Method to remove Flutter command
  Future<void> _removeFlutterCommand(int index) async {
    if (index < flutterCommands.length) {
      final removed = flutterCommands[index];

      setState(() {
        flutterCommands.removeAt(index);
        result += '✅ Removed Flutter command: flutter $removed\n';
      });
    }
  }

  // FIXED: Enhanced method to create patch file with proper Flutter commands integration
  Future<void> createPatchFile() async {
    if (patchEntries.isEmpty) {
      setState(() {
        result += '\n⚠️ No patch entries to create. Please add at least one entry.\n';
      });
      return;
    }

    setState(() {
      isCreatingPatch = true;
      result += '\n--- Creating Patch File with Flutter Commands ---\n';
      result += 'Repository: $repoUrl\n';
      result += 'Patch entries: ${patchEntries.length}\n';
      result += 'Flutter commands: ${flutterCommands.length}\n';
    });

    try {
      // Use the fixed storage directory for patch files
      final patchesBasePath = await PatchPreferencesHelper.getFixedStorageDir();
      final patchesDir = Directory(patchesBasePath);
      if (!await patchesDir.exists()) {
        await patchesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final customName = _customPatchNameController.text.trim();
      final patchFileName = customName.endsWith('.patch') ? customName : '$customName.patch';
      final patchFilePath = p.join(patchesDir.path, patchFileName);

      setState(() {
        result += 'Creating patch file: $patchFileName\n';
      });

      StringBuffer patchContent = StringBuffer();

      // Add header information about the source
      patchContent.writeln('# Patch created from GitHub repository');
      patchContent.writeln('# Repository: $repoUrl');
      patchContent.writeln('# Created: ${DateTime.now().toIso8601String()}');
      patchContent.writeln('# Entries: ${patchEntries.length}');
      if (flutterCommands.isNotEmpty) {
        patchContent.writeln('# Flutter Commands: ${flutterCommands.length}');
        patchContent.writeln('# Commands: ${flutterCommands.map((cmd) => 'flutter $cmd').join(', ')}');
      }
      patchContent.writeln('');

      for (int i = 0; i < patchEntries.length; i++) {
        final entry = patchEntries[i];

        // Ensure file name has proper extension if not provided
        String fileName = entry.fileName;
        if (!fileName.contains('.')) {
          fileName += '.dart'; // Default to .dart if no extension
        }

        // Create proper file path
        String fullFilePath = '${entry.folderName}/$fileName';

        // Normalize line endings and ensure content ends with newline
        String normalizedContent = entry.fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (!normalizedContent.endsWith('\n')) {
          normalizedContent += '\n';
        }

        // Split into lines and count total lines (including empty lines)
        final lines = normalizedContent.split('\n');
        // Remove the last empty line if it was added by split after the trailing newline
        if (lines.isNotEmpty && lines.last.isEmpty) {
          lines.removeLast();
        }
        final totalLines = lines.length;

        patchContent.writeln('diff --git a/$fullFilePath b/$fullFilePath');
        patchContent.writeln('new file mode 100644');
        patchContent.writeln('index 0000000..${_generateFileHash(normalizedContent)}');
        patchContent.writeln('--- /dev/null');
        patchContent.writeln('+++ b/$fullFilePath');
        patchContent.writeln('@@ -0,0 +1,$totalLines @@');

        // Add file content with + prefix - include ALL lines
        for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          patchContent.writeln('+${lines[lineIndex]}');
        }

        // Add separator between entries if there are multiple
        if (i < patchEntries.length - 1) {
          patchContent.writeln('');
        }
      }

      // Write patch file to disk in the fixed directory
      final patchFile = File(patchFilePath);
      await patchFile.writeAsString(patchContent.toString());

      // FIXED: Create SavedPatchFile object with Flutter commands properly included
      final savedPatch = SavedPatchFile(
        fileName: patchFileName,
        filePath: patchFilePath,
        createdAt: DateTime.now(),
        entriesCount: patchEntries.length,
        flutterCommands: List<String>.from(flutterCommands), // Create a copy of the commands list
      );

      // Save to SharedPreferences using a normalized key
      final repoKey = PatchPreferencesHelper._normalizeRepoIdentifier(repoUrl);
      final currentPatches = await PatchPreferencesHelper.loadPatchFiles(repoKey);
      currentPatches.add(savedPatch);
      await PatchPreferencesHelper.savePatchFiles(repoKey, currentPatches);

      // Also save the patch content directly to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('patch_content_$timestamp', patchContent.toString());
      await prefs.setString('patch_metadata_$timestamp', jsonEncode(savedPatch.toJson()));

      setState(() {
        result += '✅ Patch file created successfully from GitHub repository!\n';
        result += 'Location: app_data/patches/${patchFileName}\n';
        result += 'Entries included: ${patchEntries.length}\n';
        if (flutterCommands.isNotEmpty) {
          result += 'Flutter commands included: ${flutterCommands.length}\n';
          result += 'Commands: ${flutterCommands.map((cmd) => 'flutter $cmd').join(', ')}\n';
        }
        result += 'Saved to SharedPreferences for persistence\n';
        result += 'Source: $repoUrl\n';
        result += 'To apply: git apply app_data/patches/${patchFileName}\n';
        isCreatingPatch = false;
      });

      // Reload saved patch files to include the new one
      await loadSavedPatchFiles();

      // Show success message
      setState(() {
        result += '💡 Patch entries are preserved for reuse. Use "Clear All" if you want to start fresh.\n';
        result += '🔄 Patch with Flutter commands is safely stored and will execute automatically when applied.\n';
      });

    } catch (e) {
      setState(() {
        result += '❌ Error creating patch file from GitHub repository: $e\n';
        isCreatingPatch = false;
      });
    }
  }

  // Helper method to generate a simple hash for the file
  String _generateFileHash(String content) {
    // Generate a more realistic looking hash (7 characters, alphanumeric)
    final hash = content.hashCode.abs();
    return hash.toRadixString(16).padLeft(7, '0').substring(0, 7);
  }

  // Check if patch file name already exists
  bool _isPatchNameDuplicate(String patchName) {
    if (patchName.trim().isEmpty) return false;

    final normalizedName = patchName.trim().toLowerCase();
    return savedPatchFiles.any((patch) =>
    patch.fileName.toLowerCase() == normalizedName ||
        patch.fileName.toLowerCase() == '$normalizedName.patch'
    );
  }

  // Validate patch creation form
  bool _isPatchFormValid() {
    final hasEntries = patchEntries.isNotEmpty;
    final hasValidName = _customPatchNameController.text.trim().isNotEmpty;
    final isNameUnique = !_isPatchNameDuplicate(_customPatchNameController.text.trim());
    final hasRequiredFields = _patchFolderController.text.trim().isNotEmpty ||
        _patchFileNameController.text.trim().isNotEmpty ||
        _patchFileContentController.text.trim().isNotEmpty;

    return hasEntries && hasValidName && isNameUnique && !hasRequiredFields;
  }

  // Build validation status widget
  Widget _buildValidationStatus() {
    final hasEntries = patchEntries.isNotEmpty;
    final hasValidName = _customPatchNameController.text.trim().isNotEmpty;
    final isNameUnique = !_isPatchNameDuplicate(_customPatchNameController.text.trim());
    final hasRequiredFields = _patchFolderController.text.trim().isNotEmpty ||
        _patchFileNameController.text.trim().isNotEmpty ||
        _patchFileContentController.text.trim().isNotEmpty;
    final hasFlutterCommands = flutterCommands.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationItem(
          'Patch entries added',
          hasEntries,
          '${patchEntries.length} entry(ies)',
        ),
        _buildValidationItem(
          'Custom patch name provided',
          hasValidName,
          _customPatchNameController.text.trim().isNotEmpty
              ? '"${_customPatchNameController.text.trim()}"'
              : 'No name provided',
        ),
        if (hasValidName)
          _buildValidationItem(
            'Patch name is unique',
            isNameUnique,
            isNameUnique ? 'Name available' : 'Name already exists',
          ),
        _buildValidationItem(
          'No pending form fields',
          !hasRequiredFields,
          hasRequiredFields
              ? 'Please complete or clear form fields'
              : 'Form fields are clear',
        ),
        _buildValidationItem(
          'Flutter commands (optional)',
          true, // Always valid since it's optional
          '${flutterCommands.length} command(s) added',
        ),
      ],
    );
  }

  Widget _buildValidationItem(String label, bool isValid, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? const Color(0xFF4CAF50) : Colors.red,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $status',
              style: TextStyle(
                color: isValid ? Colors.white70 : Colors.red,
                fontSize: 12,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced method to remove patch entry with immediate persistence
  Future<void> _removePatchEntry(int index) async {
    if (index < patchEntries.length) {
      final removed = patchEntries[index];

      setState(() {
        patchEntries.removeAt(index);
        result += '✅ Removed patch entry: ${removed.folderName}/${removed.fileName}\n';
      });

      // Immediately update SharedPreferences
      await _savePatchEntryToPreferences();
    }
  }

  Future<void> cloneRepository() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir == null) return;

    setState(() {
      isCloning = true;
      result = 'Cloning repository from: $repoUrl\n';
      localBranches = [];
      remoteBranches = [];
      allBranches = [];
      widgetBranches = [];
      featureBranches = [];
      savedPatchFiles = [];
      patchEntries = [];
      flutterCommands = []; // Clear Flutter commands too
      selectedSourceBranches.clear();
      destinationBranch = "main"; // Always reset to "main"
    });

    // Check Git availability
    final gitPath = await findGitExecutable();
    if (gitPath == null) {
      setState(() {
        result += '❌ Git executable not found. Please install Git.';
        isCloning = false;
      });
      return;
    }

    try {
      // Determine folder name
      String folderName = _folderNameController.text.trim();
      if (folderName.isEmpty) {
        // Extract folder name from URL
        final uri = Uri.parse(repoUrl);
        folderName = p.basenameWithoutExtension(uri.path);
      }

      final targetPath = p.join(selectedDir, folderName);

      // Check if folder already exists
      final targetDir = Directory(targetPath);
      if (await targetDir.exists()) {
        setState(() {
          result += '❌ Error: Folder "$folderName" already exists in the selected directory.\n';
          isCloning = false;
        });
        return;
      }

      setState(() {
        result += 'Cloning to: $targetPath\n';
      });

      // Clone the repository
      final cloneResult = await runGit(['clone', repoUrl, targetPath], selectedDir);

      if (cloneResult.contains('Error:')) {
        setState(() {
          result += '❌ Clone failed: $cloneResult\n';
          isCloning = false;
        });
        return;
      }

      setState(() {
        result += '✅ Clone successful!\n$cloneResult\n';
        folderPath = targetPath;
        isCloning = false;
      });

      // Save as last used project
      await PatchPreferencesHelper.saveLastProjectPath(targetPath);

      // Load branches, patch files, and patch entries after successful clone
      await _loadProjectData();

    } catch (e) {
      setState(() {
        result += '❌ Clone failed with error: $e\n';
        isCloning = false;
      });
    }
  }

  Future<void> pickFolderAndReadRepo() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();

    if (selectedDir == null) return;

    setState(() {
      folderPath = selectedDir;
      result = 'Selected Folder: $selectedDir\n';
      localBranches = [];
      remoteBranches = [];
      allBranches = [];
      widgetBranches = [];
      featureBranches = [];
      savedPatchFiles = [];
      patchEntries = [];
      flutterCommands = []; // Clear Flutter commands too
      selectedSourceBranches.clear();
      destinationBranch = "main"; // Always reset to "main"
    });

    final gitDir = Directory(p.join(selectedDir, '.git'));
    if (!await gitDir.exists()) {
      setState(() {
        result += '❌ This folder is not a Git repository.';
      });
      return;
    }

    // Check Git availability
    final gitPath = await findGitExecutable();
    if (gitPath == null) {
      setState(() {
        result += '❌ Git executable not found. Please install Git.';
      });
      return;
    }

    setState(() {
      result += '✅ Git found at: $gitPath\n';
    });

    // Save as last used project
    await PatchPreferencesHelper.saveLastProjectPath(selectedDir);

    final configFile = File(p.join(gitDir.path, 'config'));
    if (await configFile.exists()) {
      final configContent = await configFile.readAsString();
      setState(() {
        result += '\n--- .git/config ---\n$configContent';
      });
    }

    final readmeFile = File(p.join(selectedDir, 'README.md'));
    if (await readmeFile.exists()) {
      final readmeContent = await readmeFile.readAsString();
      setState(() {
        result += '\n--- README.md ---\n$readmeContent';
      });
    }

    await _loadProjectData();
  }

  Future<void> loadBranches() async {
    if (folderPath == null) return;

    setState(() {
      result += '\n--- Loading Branches ---\n';
      isLoading = true;
    });

    try {
      // First, fetch all branches from remote
      await runGit(['fetch', '--all'], folderPath!);

      // Load local branches
      var localResult = await runGit(['branch', '--list'], folderPath!);
      print('Local Branches Raw Output:\n$localResult');

      // Load remote branches
      var remoteResult = await runGit(['branch', '-r', '--list'], folderPath!);
      print('Remote Branches Raw Output:\n$remoteResult');

      // Load all branches (including remote tracking)
      var allBranchesResult = await runGit(['branch', '-a', '--list'], folderPath!);
      print('All Branches Raw Output:\n$allBranchesResult');

      setState(() {
        // Process local branches
        localBranches = localResult
            .split('\n')
            .map((line) => line.replaceAll('*', '').trim())
            .where((line) => line.isNotEmpty && !line.startsWith('remotes/'))
            .toList();

        // Process remote branches
        remoteBranches = remoteResult
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.contains('->'))
            .map((line) => line.replaceAll('origin/', ''))
            .toList();

        // Create combined list for merge operations
        allBranches = [...localBranches];
        for (String remoteBranch in remoteBranches) {
          if (!allBranches.contains(remoteBranch)) {
            allBranches.add('origin/$remoteBranch');
          }
        }

        // Categorize branches into widgets and features
        widgetBranches = allBranches
            .where((branch) =>
        branch.startsWith('origin/widget-') ||
            branch.startsWith('origin/widget_') ||
            branch.startsWith('widget-') ||
            branch.startsWith('widget_'))
            .toList();

        featureBranches = allBranches
            .where((branch) =>
        branch.startsWith('origin/feature-') ||
            branch.startsWith('feature-'))
            .toList();

        result += '✅ Local branches: ${localBranches.join(', ')}\n';
        result += '✅ Remote branches: ${remoteBranches.join(', ')}\n';
        result += '✅ Widget branches: ${widgetBranches.join(', ')}\n';
        result += '✅ Feature branches: ${featureBranches.join(', ')}\n';

        // Clear invalid selections
        selectedSourceBranches.removeWhere((branch) => !allBranches.contains(branch));
        // Destination branch is always "main" - no need to validate

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        result += '❌ Error loading branches: $e\n';
        isLoading = false;
      });
    }
  }

  Future<String> runGit(List<String> args, String workingDir) async {
    try {
      // First try to find git
      final gitPath = await findGitExecutable();
      if (gitPath == null) {
        return 'Error: Git executable not found';
      }

      print('Running git command: $gitPath ${args.join(' ')}');
      print('Working directory: $workingDir');

      final result = await Process.run(
        gitPath,
        args,
        workingDirectory: workingDir,
        runInShell: true,
      );

      print('Git command exit code: ${result.exitCode}');
      print('Git command stdout: ${result.stdout}');
      print('Git command stderr: ${result.stderr}');

      if (result.exitCode != 0) {
        return 'Error: ${result.stderr}';
      }

      return result.stdout.toString();
    } catch (e) {
      print('Git command failed: $e');
      return 'Error: $e';
    }
  }

  // Method to run Flutter commands
  Future<String> runFlutterCommand(String command, String workingDir) async {
    try {
      // Find Flutter executable
      final flutterPath = await findFlutterExecutable();
      if (flutterPath == null) {
        return 'Error: Flutter executable not found';
      }

      // Split the command into arguments
      final args = command.split(' ').where((arg) => arg.isNotEmpty).toList();

      print('Running Flutter command: $flutterPath ${args.join(' ')}');
      print('Working directory: $workingDir');

      final result = await Process.run(
        flutterPath,
        args,
        workingDirectory: workingDir,
        runInShell: true,
      );

      print('Flutter command exit code: ${result.exitCode}');
      print('Flutter command stdout: ${result.stdout}');
      print('Flutter command stderr: ${result.stderr}');

      if (result.exitCode != 0) {
        return 'Error: ${result.stderr}';
      }

      return result.stdout.toString();
    } catch (e) {
      print('Flutter command failed: $e');
      return 'Error: $e';
    }
  }

  // Find Flutter executable in common locations
  Future<String?> findFlutterExecutable() async {
    final possiblePaths = [
      '/usr/local/bin/flutter',
      '/opt/homebrew/bin/flutter',
      '/snap/bin/flutter',
      'flutter', // Try PATH
    ];

    for (final path in possiblePaths) {
      try {
        final result = await Process.run('which', [path]);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      } catch (e) {
        // Continue to next path
      }
    }

    // Try using 'which' command directly
    try {
      final result = await Process.run('which', ['flutter']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      print('Error finding flutter with which: $e');
    }

    return null;
  }

  Future<void> mergeBranches() async {
    if (folderPath == null || selectedSourceBranches.isEmpty) {
      setState(() {
        result += '\n⚠️ Please select source branch(es).';
      });
      return;
    }

    if (selectedSourceBranches.contains(destinationBranch)) {
      setState(() {
        result += '\n⚠️ Source and destination branches cannot be the same.';
      });
      return;
    }

    setState(() {
      result += '\n--- Merging Branches ---\n';
      result += 'Merging ${selectedSourceBranches.join(', ')} into $destinationBranch\n';
      isLoading = true;
      mergeProgress = 0.0;
    });

    try {
      final int totalSteps = 3 + selectedSourceBranches.length; // fetch, checkout, pull, merges
      int currentStep = 0;

      // 1. Fetch latest changes from remote
      await runGit(['fetch', 'origin'], folderPath!);
      currentStep++;
      setState(() {
        mergeProgress = currentStep / totalSteps;
      });

      // 2. Checkout the destination branch
      var checkoutOutput = await runGit(['checkout', destinationBranch], folderPath!);
      setState(() {
        result += 'Checkout output: $checkoutOutput\n';
      });
      currentStep++;
      setState(() {
        mergeProgress = currentStep / totalSteps;
      });

      // 3. Pull latest changes for destination branch if it's a local branch
      if (localBranches.contains(destinationBranch)) {
        var pullOutput = await runGit(['pull', 'origin', destinationBranch], folderPath!);
        setState(() {
          result += 'Pull output: $pullOutput\n';
        });
      }
      currentStep++;
      setState(() {
        mergeProgress = currentStep / totalSteps;
      });

      // 4. Perform the merge for each selected source branch
      bool allMergesSuccessful = true;
      for (String sourceBranch in selectedSourceBranches) {
        setState(() {
          result += '\n--- Merging $sourceBranch ---\n';
        });

        var mergeOutput = await runGit(['merge', sourceBranch], folderPath!);
        setState(() {
          result += 'Merge output: $mergeOutput\n';
        });

        currentStep++;
        setState(() {
          mergeProgress = currentStep / totalSteps;
        });

        if (mergeOutput.contains('Error:')) {
          allMergesSuccessful = false;
          setState(() {
            result += '❌ Merge of $sourceBranch failed. Please resolve conflicts manually.\n';
          });
          break; // Stop merging if one fails
        }
      }

      if (allMergesSuccessful) {
        setState(() {
          result += '✅ All merges completed successfully!\n';
          mergeProgress = 1.0;
        });
      }

    } catch (e) {
      setState(() {
        result += '❌ Merge failed with error: $e\n';
      });
    }

    setState(() {
      isLoading = false;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() { mergeProgress = 0.0; });
      });
    });

    // Refresh branches after merge
    await loadBranches();
  }

  Widget _buildBranchSection(String title, List<String> branches, Color color) {
    return FuturisticGlassPanel(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == 'List of widgets' ? Icons.widgets : Icons.star,
                color: color,
                size: 22,
                shadows: [
                  Shadow(color: color.withOpacity(0.7), blurRadius: 12, offset: const Offset(0, 0)),
                ],
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Orbitron',
                  shadows: [
                    Shadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              border: Border.all(color: color.withOpacity(0.18)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: branches.isEmpty
                ? Center(
              child: Text(
                'No ${title.toLowerCase()} available',
                style: TextStyle(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Orbitron',
                ),
              ),
            )
                : ListView.builder(
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                final displayName = getDisplayName(branch);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  tileColor: Colors.transparent,
                  title: Text(
                    displayName,
                    style: const TextStyle(fontSize: 15, color: Colors.white, fontFamily: 'Orbitron'),
                  ),
                  value: selectedSourceBranches.contains(branch),
                  activeColor: color,
                  checkColor: Colors.black,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedSourceBranches.add(branch);
                      } else {
                        selectedSourceBranches.remove(branch);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatchEntriesList() {
    if (patchEntries.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No patch entries added yet',
            style: TextStyle(
              color: Colors.white54,
              fontStyle: FontStyle.italic,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      );
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: patchEntries.length,
        itemBuilder: (context, index) {
          final entry = patchEntries[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.description, color: Color(0xFFFF6B35), size: 20),
            title: Text(
              '${entry.folderName}/${entry.fileName}',
              style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontSize: 14),
            ),
            subtitle: Text(
              '${entry.fileContent.length} characters',
              style: const TextStyle(color: Colors.white54, fontFamily: 'Orbitron', fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              onPressed: () => _removePatchEntry(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedPatchFilesList() {
    if (savedPatchFiles.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No saved patch files found',
            style: TextStyle(
              color: Colors.white54,
              fontStyle: FontStyle.italic,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      );
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: savedPatchFiles.length,
        itemBuilder: (context, index) {
          final patchFile = savedPatchFiles[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.file_present, color: Color(0xFF4CAF50), size: 20),
            title: Text(
              patchFile.fileName,
              style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${patchFile.entriesCount} entries',
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Orbitron', fontSize: 12),
                ),
                Text(
                  'Created: ${patchFile.createdAt.day}/${patchFile.createdAt.month}/${patchFile.createdAt.year}',
                  style: const TextStyle(color: Colors.white38, fontFamily: 'Orbitron', fontSize: 11),
                ),
                if (patchFile.flutterCommands.isNotEmpty)
                  Text(
                    '${patchFile.flutterCommands.length} Flutter command(s)',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'Orbitron', fontSize: 11),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Color(0xFF4CAF50), size: 18),
                  onPressed: isLoading ? null : () => applySavedPatch(patchFile),
                  tooltip: 'Apply Patch',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => deleteSavedPatch(patchFile),
                  tooltip: 'Delete Patch',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // UPDATED: Enhanced Flutter commands list with better display of commands
  Widget _buildFlutterCommandsList() {
    if (flutterCommands.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No Flutter commands added yet',
            style: TextStyle(
              color: Colors.white54,
              fontStyle: FontStyle.italic,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: flutterCommands.length,
        itemBuilder: (context, index) {
          final command = flutterCommands[index];
          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'flutter $command',
              style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontSize: 14),
            ),
            subtitle: Text(
              'Will execute when patch is applied',
              style: const TextStyle(color: Colors.white54, fontFamily: 'Orbitron', fontSize: 10),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              onPressed: () => _removeFlutterCommand(index),
              tooltip: 'Remove Command',
            ),
          );
        },
      ),
    );
  }

  // Helper method to get common Flutter command suggestions
  List<String> getCommonFlutterCommands() {
    return [
      'pub get',
      'pub upgrade',
      'clean',
      'build apk',
      'build ios',
      'build web',
      'run',
      'test',
      'analyze',
      'format .',
      'pub outdated',
      'doctor',
    ];
  }

  // Method to add a common Flutter command
  void _addCommonFlutterCommand(String command) {
    setState(() {
      flutterCommands.add(command);
      result += '✅ Added common Flutter command: flutter $command\n';
    });
  }

  // Build vertical sidebar navigation
  Widget _buildVerticalSidebar() {
    final List<SidebarItem> sidebarItems = [
      SidebarItem(
        icon: Icons.folder_open,
        label: 'Project',
        color: const Color(0xFFB388FF),
        index: 0,
      ),
      SidebarItem(
        icon: Icons.build_circle,
        label: 'Custom Feature',
        color: const Color(0xFFFF6B35),
        index: 1,
      ),
      SidebarItem(
        icon: Icons.merge_type,
        label: 'Merge & Patches',
        color: const Color(0xFF4CAF50),
        index: 2,
      ),
    ];

    return Container(
      width: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x44B388FF),
            const Color(0x220D001A),
            const Color(0x33A259FF),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: const Color(0xFFB388FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Sidebar Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFFB388FF), Color(0xFF00E5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: const Icon(
                        Icons.code,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CodeCrafter',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'PERSISTENT',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: sidebarItems.length,
                  itemBuilder: (context, index) {
                    final item = sidebarItems[index];
                    final isSelected = selectedTabIndex == item.index;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: item.color.withOpacity(0.5), width: 1)
                            : null,
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Icon(
                          item.icon,
                          color: isSelected ? item.color : Colors.white70,
                          size: 24,
                          shadows: isSelected ? [
                            Shadow(
                              color: item.color.withOpacity(0.7),
                              blurRadius: 8,
                              offset: const Offset(0, 0),
                            ),
                          ] : null,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontFamily: 'Orbitron',
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            shadows: isSelected ? [
                              Shadow(
                                color: item.color.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ] : null,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            selectedTabIndex = item.index;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              // Project Status Indicator (if project is loaded)
              if (folderPath != null) ...[
                const Divider(color: Colors.white24, height: 1),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF4CAF50),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Project Loaded',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontFamily: 'Orbitron',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.basename(folderPath!),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Orbitron',
                          fontSize: 10,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A0A2E),
              Color(0xFF16213E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Left Sidebar
            _buildVerticalSidebar(),

            // Main Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Main Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: FuturisticGlassPanel(
                          child: _buildTabContent(),
                        ),
                      ),
                    ),

                    // Result output section
                    if (result.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      FuturisticGlassPanel(
                        height: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Output',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00E5FF),
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      result = '';
                                    });
                                  },
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                  tooltip: 'Clear Output',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    result,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build tab content based on selected tab
  Widget _buildTabContent() {
    switch (selectedTabIndex) {
      case 0:
        return _buildProjectTab();
      case 1:
        return _buildCustomFeatureTab();
      case 2:
        return _buildMergeAndPatchesTab();
      default:
        return _buildProjectTab();
    }
  }

  // Tab 1: Project Management
  Widget _buildProjectTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_open, color: Color(0xFFB388FF), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Project Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB388FF),
                fontFamily: 'Orbitron',
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _folderNameController,
          style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
          decoration: const InputDecoration(
            labelText: 'Folder Name (optional)',
            labelStyle: TextStyle(color: Color(0xFFB388FF)),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            ElevatedButton.icon(
              onPressed: isCloning ? null : cloneRepository,
              icon: isCloning
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB388FF)),
              )
                  : const Icon(Icons.cloud_download, color: Colors.black),
              label: Text(isCloning ? 'Creating Project...' : 'Create Project', style: const TextStyle(color: Colors.black, fontFamily: 'Orbitron')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB388FF),
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: const Color(0xFFB388FF),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: pickFolderAndReadRepo,
              icon: const Icon(Icons.folder_open, color: Colors.black),
              label: const Text('Select Existing Project', style: TextStyle(color: Colors.black, fontFamily: 'Orbitron')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),

        if (folderPath != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF4CAF50)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Successfully Loaded',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Path: ${p.basename(folderPath!)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Full path: $folderPath',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Tab 2: Custom Feature Creator
  Widget _buildCustomFeatureTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.build_circle, color: Color(0xFFFF6B35), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Create Custom Feature',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
                fontFamily: 'Orbitron',
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                'AUTO-SAVE',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom Patch Name Input
        TextField(
          controller: _customPatchNameController,
          style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
          decoration: InputDecoration(
            labelText: 'Custom Patch File Name',
            labelStyle: const TextStyle(color: Color(0xFFFF6B35)),
            hintText: 'e.g., my_custom_feature',
            hintStyle: const TextStyle(color: Colors.white38),
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2),
            ),
            suffixIcon: _customPatchNameController.text.trim().isNotEmpty
                ? Icon(
              _isPatchNameDuplicate(_customPatchNameController.text.trim())
                  ? Icons.error
                  : Icons.check_circle,
              color: _isPatchNameDuplicate(_customPatchNameController.text.trim())
                  ? Colors.red
                  : const Color(0xFF4CAF50),
            )
                : null,
            helperText: _customPatchNameController.text.trim().isNotEmpty
                ? _isPatchNameDuplicate(_customPatchNameController.text.trim())
                ? '❌ This name already exists'
                : '✅ Name is available'
                : null,
            helperStyle: TextStyle(
              color: _customPatchNameController.text.trim().isNotEmpty
                  ? _isPatchNameDuplicate(_customPatchNameController.text.trim())
                  ? Colors.red
                  : const Color(0xFF4CAF50)
                  : Colors.white54,
              fontSize: 12,
              fontFamily: 'Orbitron',
            ),
          ),
          onChanged: (value) {
            setState(() {
              // Trigger rebuild to update validation UI
            });
          },
        ),
        const SizedBox(height: 20),

        // Patch entry form
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _patchFolderController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  labelStyle: TextStyle(color: Color(0xFFFF6B35)),
                  hintText: 'e.g., lib/widgets',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _patchFileNameController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
                decoration: const InputDecoration(
                  labelText: 'File Name',
                  labelStyle: TextStyle(color: Color(0xFFFF6B35)),
                  hintText: 'e.g., custom_widget.dart',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _patchFileContentController,
          style: const TextStyle(color: Colors.white, fontFamily: 'FiraMono', fontSize: 13),
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'File Content',
            labelStyle: TextStyle(color: Color(0xFFFF6B35)),
            hintText: 'Enter your code here...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2),
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _addPatchEntry,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Add Entry',
                style: TextStyle(color: Colors.black, fontFamily: 'Orbitron'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: const Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(width: 12),
            if (patchEntries.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: (isCreatingPatch || !_isPatchFormValid()) ? null : createPatchFile,
                icon: isCreatingPatch
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
                    : const Icon(Icons.file_download, color: Colors.black),
                label: Text(
                  isCreatingPatch ? 'Creating...' : 'Create Patch',
                  style: const TextStyle(color: Colors.black, fontFamily: 'Orbitron'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPatchFormValid()
                      ? const Color(0xFF4CAF50)
                      : Colors.grey,
                  foregroundColor: Colors.black,
                  elevation: _isPatchFormValid() ? 10 : 0,
                  shadowColor: _isPatchFormValid()
                      ? const Color(0xFF4CAF50)
                      : Colors.transparent,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  // Clear from SharedPreferences but keep for potential reuse
                  if (folderPath != null) {
                    await PatchPreferencesHelper.clearPatchEntries(folderPath!);
                  }
                  setState(() {
                    patchEntries.clear();
                    flutterCommands.clear(); // Clear Flutter commands too
                    _customPatchNameController.clear();
                    result += '✅ Cleared all patch entries, Flutter commands, and custom name from persistent storage.\n';
                  });
                },
                icon: const Icon(Icons.clear_all, color: Colors.black),
                label: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.black, fontFamily: 'Orbitron'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.black,
                  elevation: 10,
                  shadowColor: const Color(0xFFF44336),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Validation Status
        if (patchEntries.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border.all(
                color: _isPatchFormValid()
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF6B35),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPatchFormValid() ? Icons.check_circle : Icons.info,
                      color: _isPatchFormValid()
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF6B35),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Validation Status',
                      style: TextStyle(
                        color: _isPatchFormValid()
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF6B35),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildValidationStatus(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Display current patch entries
        Row(
          children: [
            const Icon(Icons.list_alt, color: Color(0xFFFF6B35), size: 20),
            const SizedBox(width: 8),
            Text(
              'Patch Entries (${patchEntries.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
                fontFamily: 'Orbitron',
              ),
            ),
            const Spacer(),
            if (folderPath != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFF4CAF50), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Auto-saved & Persistent',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontFamily: 'Orbitron',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildPatchEntriesList(),
        const SizedBox(height: 20),

        // Flutter Commands Section
        Row(
          children: [
            const Icon(Icons.play_circle_outline, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Flutter Commands (${flutterCommands.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                fontFamily: 'Orbitron',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Auto-execute',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontFamily: 'Orbitron',
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Flutter Command Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _flutterCommandController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
                decoration: const InputDecoration(
                  labelText: 'Flutter Command',
                  labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                  hintText: 'e.g., pub get, build apk, run',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addFlutterCommand,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Add Command',
                style: TextStyle(color: Colors.black, fontFamily: 'Orbitron'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                elevation: 10,
                shadowColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Common Flutter Commands Suggestions
        if (flutterCommands.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Common Flutter Commands',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: getCommonFlutterCommands().map((command) {
                    return InkWell(
                      onTap: () => _addCommonFlutterCommand(command),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          command,
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 10,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Flutter Commands List
        _buildFlutterCommandsList(),
      ],
    );
  }

  // Tab 3: Merge and Patches
  Widget _buildMergeAndPatchesTab() {
    if (folderPath == null || isCloning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Please select or create a project first',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'Orbitron',
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.merge_type, color: Color(0xFF4CAF50), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Merge & Patches',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                fontFamily: 'Orbitron',
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Merge Section
        if (isLoading && mergeProgress > 0.0) ...[
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 260,
                  child: LinearProgressIndicator(
                    value: mergeProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB388FF)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(mergeProgress * 100).toInt()}% ${mergeProgress < 1.0 ? 'completing' : 'completed'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else if (isLoading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 20),
        ] else ...[
          _buildBranchSection('List of widgets', widgetBranches, const Color(0xFF7C4DFF)),
          _buildBranchSection('List of features', featureBranches, const Color(0xFF00E5FF)),
          const SizedBox(height: 18),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: (selectedSourceBranches.isEmpty || isLoading)
                    ? null
                    : mergeBranches,
                icon: isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB388FF)),
                )
                    : const Icon(Icons.merge_type, color: Colors.black),
                label: const Text('Apply in project', style: TextStyle(color: Colors.black, fontFamily: 'Orbitron')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB388FF),
                  foregroundColor: Colors.black,
                  elevation: 10,
                  shadowColor: const Color(0xFFB388FF),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedSourceBranches.clear();
                  });
                },
                icon: const Icon(Icons.clear, color: Colors.black),
                label: const Text('Clear Selection', style: TextStyle(color: Colors.black, fontFamily: 'Orbitron')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  elevation: 10,
                  shadowColor: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),

        // Saved Patch Files Section
        Row(
          children: [
            const Icon(Icons.file_present, color: Color(0xFF4CAF50), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Saved Patch Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                fontFamily: 'Orbitron',
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '${savedPatchFiles.length} FILES',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Info about Flutter commands
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.1),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 Patches with Flutter commands will automatically execute them when applied. Use the Refresh button if commands are not showing.',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSavedPatchFilesList(),
      ],
    );
  }
}

// Helper class for sidebar items
class SidebarItem {
  final IconData icon;
  final String label;
  final Color color;
  final int index;

  SidebarItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.index,
  });
}