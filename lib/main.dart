import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';

void main() {
  runApp(const GitRepoReaderApp());
}

class GitRepoReaderApp extends StatelessWidget {
  const GitRepoReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Repo Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RepoReaderScreen(),
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
      result += 'Merging ${selectedSourceBranches.join(', ')} into $destinationBranch\n';
      isLoading = true;
    });

    try {
      // First, fetch latest changes from remote
      await runGit(['fetch', 'origin'], folderPath!);

      // Checkout the destination branch
      var checkoutOutput = await runGit(['checkout', destinationBranch], folderPath!);
      setState(() {
        result += 'Checkout output: $checkoutOutput\n';
      });

      // Pull latest changes for destination branch if it's a local branch
      if (localBranches.contains(destinationBranch)) {
        var pullOutput = await runGit(['pull', 'origin', destinationBranch], folderPath!);
        setState(() {
          result += 'Pull output: $pullOutput\n';
        });
      }

      // Perform the merge for each selected source branch
      bool allMergesSuccessful = true;
      for (String sourceBranch in selectedSourceBranches) {
        setState(() {
          result += '\n--- Merging $sourceBranch ---\n';
        });

        var mergeOutput = await runGit(['merge', sourceBranch], folderPath!);
        setState(() {
          result += 'Merge output: $mergeOutput\n';
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
        });
      }

    } catch (e) {
      setState(() {
        result += 'Merge failed with error: $e\n';
      });
    }

    setState(() {
      isLoading = false;
    });

    // Refresh branches after merge
    await loadBranches();
  }

  Widget _buildBranchSection(String title, List<String> branches, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  title == 'List of widgets' ? Icons.widgets : Icons.star,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${branches.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: branches.isEmpty
                  ? Center(
                child: Text(
                  'No ${title.toLowerCase()} available',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: branches.length,
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  final displayName = getDisplayName(branch); // Use display name for UI
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    title: Text(
                      displayName, // Show clean display name
                      style: const TextStyle(fontSize: 14),
                    ),
                    value: selectedSourceBranches.contains(branch),
                    activeColor: color,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedSourceBranches.add(branch); // Store original name
                        } else {
                          selectedSourceBranches.remove(branch); // Remove original name
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boiler platte code automatic'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Clone Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Create Flutter project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _folderNameController,
                        decoration: const InputDecoration(
                          labelText: 'Folder Name (optional)',
                          hintText: 'Leave empty to use repository name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: isCloning ? null : cloneRepository,
                            icon: isCloning
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.cloud_download),
                            label: Text(isCloning ? 'Creating Project...' : 'Create Project'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (folderPath != null && !isCloning) ...[
                // Merge Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Branch Selection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: isLoading ? null : loadBranches,
                              icon: isLoading
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (isLoading) ...[
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 20),
                        ] else ...[
                          // Widget branches section
                          _buildBranchSection('List of widgets', widgetBranches, Colors.blue),

                          // Feature branches section
                          _buildBranchSection('List of features', featureBranches, Colors.green),

                          const SizedBox(height: 15),

                          // Selected branches summary
                          if (selectedSourceBranches.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Selected branches:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedSourceBranches.map((branch) => getDisplayName(branch)).join(', '), // Show display names in summary
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Action buttons
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: (selectedSourceBranches.isEmpty || isLoading)
                                    ? null
                                    : mergeBranches,
                                icon: isLoading
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Icon(Icons.merge_type),
                                label: const Text('Apply in project'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    selectedSourceBranches.clear();
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Selection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Output Section
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(result),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}