import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:google_fonts/google_fonts.dart';

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
          // fillColor: MaterialStateProperty.all(const Color(0xFF00E5FF)),
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

class _RepoReaderScreenState extends State<RepoReaderScreen> {
  String? folderPath;
  String result = '';
  bool isCloning = false;
  bool isLoading = false;
  double mergeProgress = 0.0; // Progress for merge operation

  // Hardcoded repository URL
  static const String repoUrl = "https://github.com/SahilJadhav12/mergingdemo.git";

  // Controller for folder name input
  final TextEditingController _folderNameController = TextEditingController();

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
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
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
      selectedSourceBranches.clear();
      destinationBranch = "main"; // Always reset to "main"
    });

    // Check Git availability
    final gitPath = await findGitExecutable();
    if (gitPath == null) {
      setState(() {
        result += 'Git executable not found. Please install Git.';
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
          result += 'Error: Folder "$folderName" already exists in the selected directory.\n';
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
          result += 'Clone failed: $cloneResult\n';
          isCloning = false;
        });
        return;
      }

      setState(() {
        result += 'Clone successful!\n$cloneResult\n';
        folderPath = targetPath;
        isCloning = false;
      });

      // Load branches after successful clone
      await loadBranches();

    } catch (e) {
      setState(() {
        result += 'Clone failed with error: $e\n';
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
      selectedSourceBranches.clear();
      destinationBranch = "main"; // Always reset to "main"
    });

    final gitDir = Directory(p.join(selectedDir, '.git'));
    if (!await gitDir.exists()) {
      setState(() {
        result += 'This folder is not a Git repository.';
      });
      return;
    }

    // Check Git availability
    final gitPath = await findGitExecutable();
    if (gitPath == null) {
      setState(() {
        result += 'Git executable not found. Please install Git.';
      });
      return;
    }

    setState(() {
      result += 'Git found at: $gitPath\n';
    });

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

    await loadBranches();
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

        result += 'Local branches: ${localBranches.join(', ')}\n';
        result += 'Remote branches: ${remoteBranches.join(', ')}\n';
        result += 'Widget branches: ${widgetBranches.join(', ')}\n';
        result += 'Feature branches: ${featureBranches.join(', ')}\n';

        // Clear invalid selections
        selectedSourceBranches.removeWhere((branch) => !allBranches.contains(branch));
        // Destination branch is always "main" - no need to validate

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        result += 'Error loading branches: $e\n';
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

  Future<void> mergeBranches() async {
    if (folderPath == null || selectedSourceBranches.isEmpty) {
      setState(() {
        result += '\nPlease select source branch(es).';
      });
      return;
    }

    if (selectedSourceBranches.contains(destinationBranch)) {
      setState(() {
        result += '\nSource and destination branches cannot be the same.';
      });
      return;
    }

    setState(() {
      result += '\n--- Merging Branches ---\n';
      result += 'Merging  [0m${selectedSourceBranches.join(', ')} into $destinationBranch\n';
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
            result += 'Merge of $sourceBranch failed. Please resolve conflicts manually.\n';
          });
          break; // Stop merging if one fails
        }
      }

      if (allMergesSuccessful) {
        setState(() {
          result += 'All merges completed successfully!\n';
          mergeProgress = 1.0;
        });
      }

    } catch (e) {
      setState(() {
        result += 'Merge failed with error: $e\n';
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
              // Removed count container
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Center the title horizontally
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Color(0xFFB388FF), Color(0xFF00E5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'CodeCrafter',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          fontSize: 22,
                          letterSpacing: 1.2,
                          shadows: [Shadow(color: Color(0xFFB388FF), blurRadius: 12)],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                  // Clone Section
                  FuturisticGlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create Flutter project', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFB388FF), fontFamily: 'Orbitron', letterSpacing: 1.1)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _folderNameController,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
                          decoration: const InputDecoration(
                            labelText: 'Folder Name (optional)',
                            labelStyle: TextStyle(color: Color(0xFFB388FF)),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (folderPath != null && !isCloning) ...[
                    // Merge Section
                    FuturisticGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row(
                          //   children: [
                          //     // const Text('Branch Selection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFB388FF), fontFamily: 'Orbitron', letterSpacing: 1.1)),
                          //     // const Spacer(),
                          //     ElevatedButton.icon(
                          //       onPressed: isLoading ? null : loadBranches,
                          //       icon: isLoading
                          //           ? const SizedBox(
                          //               width: 18,
                          //               height: 18,
                          //               child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB388FF)),
                          //             )
                          //           : const Icon(Icons.refresh, color: Colors.black),
                          //       label: const Text('Refresh', style: TextStyle(color: Colors.black, fontFamily: 'Orbitron')),
                          //       style: ElevatedButton.styleFrom(
                          //         backgroundColor: const Color(0xFFB388FF),
                          //         foregroundColor: Colors.black,
                          //         elevation: 10,
                          //         shadowColor: const Color(0xFFB388FF),
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          // const SizedBox(height: 12),
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
                            // if (selectedSourceBranches.isNotEmpty) ...[
                            //   FuturisticGlassPanel(
                            //     child: Column(
                            //       crossAxisAlignment: CrossAxisAlignment.start,
                            //       children: [
                            //         const Text(
                            //           'Selected branches:',
                            //           style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Orbitron', color: Color(0xFFB388FF)),
                            //         ),
                            //         const SizedBox(height: 4),
                            //         Text(
                            //           selectedSourceBranches.map((branch) => getDisplayName(branch)).join(', '),
                            //           style: const TextStyle(fontStyle: FontStyle.italic, fontFamily: 'Orbitron', color: Colors.white70),
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            //   const SizedBox(height: 12),
                            // ],
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  // Output Section
                  // FuturisticGlassPanel(
                  //   child: Container(
                  //     height: 300,
                  //     decoration: BoxDecoration(
                  //       color: Colors.black.withOpacity(0.18),
                  //       border: Border.all(color: Colors.white24),
                  //       borderRadius: BorderRadius.circular(8),
                  //       boxShadow: [
                  //         BoxShadow(color: const Color(0xFFB388FF).withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 4)),
                  //       ],
                  //     ),
                  //     child: SingleChildScrollView(
                  //       child: Padding(
                  //         padding: const EdgeInsets.all(8.0),
                  //         child: SelectableText(result, style: const TextStyle(color: Colors.white70, fontFamily: 'FiraMono', fontSize: 13)),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}