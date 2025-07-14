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

  List<String> localBranches = [];
  List<String> remoteBranches = [];
  List<String> allBranches = []; // Combined list for merge operations

  // For branch creation
  String? selectedLocalBranch;
  String? selectedRemoteBranch;
  String newBranchName = '';

  // For merge operations - changed to support multiple source branches
  Set<String> selectedSourceBranches = <String>{};
  String? destinationBranch;

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

  Future<void> pickFolderAndReadRepo() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();

    if (selectedDir == null) return;

    setState(() {
      folderPath = selectedDir;
      result = 'Selected Folder: $selectedDir\n';
      localBranches = [];
      remoteBranches = [];
      allBranches = [];
      selectedSourceBranches.clear();
      destinationBranch = null;
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
    });

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

      result += 'Local branches: ${localBranches.join(', ')}\n';
      result += 'Remote branches: ${remoteBranches.join(', ')}\n';
      result += 'All branches for merge: ${allBranches.join(', ')}\n';

      // Clear invalid selections
      selectedSourceBranches.removeWhere((branch) => !allBranches.contains(branch));
      if (destinationBranch != null && !allBranches.contains(destinationBranch!)) {
        destinationBranch = null;
      }
    });
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

  Future<void> createNewBranch() async {
    if (folderPath == null || newBranchName.trim().isEmpty) return;

    String fromBranch = selectedLocalBranch ?? selectedRemoteBranch ?? '';

    if (fromBranch.isEmpty) {
      setState(() {
        result += '\nPlease select a base branch.';
      });
      return;
    }

    setState(() {
      result += '\n--- Creating Branch ---\n';
    });

    // If it's a remote branch, we need to track it
    if (selectedRemoteBranch != null) {
      // First, fetch the latest from remote
      await runGit(['fetch', 'origin'], folderPath!);

      // Create a new branch tracking the remote branch
      final output = await runGit(['checkout', '-b', newBranchName, 'origin/$selectedRemoteBranch'], folderPath!);
      setState(() {
        result += output;
      });
    } else {
      // Checkout the base branch first
      await runGit(['checkout', fromBranch], folderPath!);

      // Then create new branch
      final output = await runGit(['checkout', '-b', newBranchName], folderPath!);
      setState(() {
        result += output;
      });
    }

    setState(() {
      newBranchName = '';
    });

    await loadBranches();
  }

  Future<void> mergeBranches() async {
    if (folderPath == null || selectedSourceBranches.isEmpty || destinationBranch == null) {
      setState(() {
        result += '\nPlease select source branch(es) and destination branch.';
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
    });

    try {
      // First, fetch latest changes from remote
      await runGit(['fetch', 'origin'], folderPath!);

      // Checkout the destination branch
      var checkoutOutput = await runGit(['checkout', destinationBranch!], folderPath!);
      setState(() {
        result += 'Checkout output: $checkoutOutput\n';
      });

      // Pull latest changes for destination branch if it's a local branch
      if (localBranches.contains(destinationBranch)) {
        var pullOutput = await runGit(['pull', 'origin', destinationBranch!], folderPath!);
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

    // Refresh branches after merge
    await loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Repo Reader with Merge (macOS)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickFolderAndReadRepo,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Git Repo Folder'),
            ),
            const SizedBox(height: 20),
            if (folderPath != null) ...[

              // Merge Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Branch Merge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // Source branches with checkboxes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Source Branches:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ListView.builder(
                                    itemCount: allBranches.length,
                                    itemBuilder: (context, index) {
                                      final branch = allBranches[index];
                                      return CheckboxListTile(
                                        dense: true,
                                        title: Text(branch),
                                        value: selectedSourceBranches.contains(branch),
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
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.arrow_forward, size: 32),
                          const SizedBox(width: 20),

                          // Destination branch dropdown
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Destination Branch:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Select Destination'),
                                  value: destinationBranch,
                                  items: allBranches.map((branch) {
                                    return DropdownMenuItem(
                                      value: branch,
                                      child: Text(branch),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      destinationBranch = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Selected branches summary
                      if (selectedSourceBranches.isNotEmpty) ...[
                        Text(
                          'Selected: ${selectedSourceBranches.join(', ')} → ${destinationBranch ?? 'None'}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Action buttons
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: mergeBranches,
                            icon: const Icon(Icons.merge_type),
                            label: const Text('Merge Selected Branches'),
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
                                destinationBranch = null;
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
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}