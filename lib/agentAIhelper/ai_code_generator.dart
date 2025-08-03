import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// AI Code Generator for Flutter/Dart code generation
class AICodeGenerator {
  static const String _defaultApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _defaultModel = 'gpt-3.5-turbo';
  
  final String? apiKey;
  final String apiUrl;
  final String model;
  final int maxTokens;
  final double temperature;

  AICodeGenerator({
    this.apiKey,
    this.apiUrl = _defaultApiUrl,
    this.model = _defaultModel,
    this.maxTokens = 2000,
    this.temperature = 0.7,
  });

  /// Generate code based on user prompt and context
  Future<CodeGenerationResult> generateCode({
    required String userPrompt,
    required String folderName,
    required String fileName,
    String? fileExtension,
    String? additionalContext,
    List<String>? existingCode,
  }) async {
    try {
      // Build the system prompt with context
      final systemPrompt = _buildSystemPrompt(
        folderName: folderName,
        fileName: fileName,
        fileExtension: fileExtension,
        additionalContext: additionalContext,
      );

      // Build the user prompt with context
      final enhancedUserPrompt = _buildUserPrompt(
        userPrompt: userPrompt,
        existingCode: existingCode,
      );

      // Make API request
      final response = await _makeApiRequest(
        systemPrompt: systemPrompt,
        userPrompt: enhancedUserPrompt,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final generatedCode = _extractCodeFromResponse(responseData);
        
        return CodeGenerationResult(
          success: true,
          code: generatedCode,
          model: model,
          tokensUsed: _extractTokensUsed(responseData),
        );
      } else {
        return CodeGenerationResult(
          success: false,
          error: 'API request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return CodeGenerationResult(
        success: false,
        error: 'Error generating code: $e',
      );
    }
  }

  /// Generate code with local fallback (no API required)
  Future<CodeGenerationResult> generateCodeLocal({
    required String userPrompt,
    required String folderName,
    required String fileName,
    String? fileExtension,
  }) async {
    try {
      // Simple template-based code generation
      final generatedCode = _generateCodeFromTemplate(
        userPrompt: userPrompt,
        folderName: folderName,
        fileName: fileName,
        fileExtension: fileExtension,
      );

      return CodeGenerationResult(
        success: true,
        code: generatedCode,
        model: 'local-template',
        tokensUsed: 0,
      );
    } catch (e) {
      return CodeGenerationResult(
        success: false,
        error: 'Error generating local code: $e',
      );
    }
  }

  /// Build system prompt with context
  String _buildSystemPrompt({
    required String folderName,
    required String fileName,
    String? fileExtension,
    String? additionalContext,
  }) {
    final extension = fileExtension ?? _getFileExtension(fileName);
    final isDartFile = extension == '.dart';
    
    String prompt = '''You are an expert Flutter/Dart developer. Generate clean, well-structured code based on the user's requirements.

Context:
- Folder: $folderName
- File: $fileName
- Extension: $extension
${additionalContext != null ? '- Additional Context: $additionalContext' : ''}

Requirements:
1. Generate only the code content, no explanations or markdown
2. Follow Flutter/Dart best practices and conventions
3. Use proper imports and dependencies
4. Include proper error handling where appropriate
5. Follow the folder structure provided
6. Use meaningful variable and function names
7. Include comments for complex logic
8. Ensure the code is production-ready

${isDartFile ? _getDartSpecificGuidelines() : _getGeneralGuidelines()}

Generate the complete code file content:''';

    return prompt;
  }

  /// Build user prompt with context
  String _buildUserPrompt({
    required String userPrompt,
    List<String>? existingCode,
  }) {
    String prompt = 'User Request: $userPrompt';
    
    if (existingCode != null && existingCode.isNotEmpty) {
      prompt += '\n\nExisting code to consider:\n${existingCode.join('\n')}';
    }
    
    return prompt;
  }

  /// Make API request to OpenAI or similar service
  Future<http.Response> _makeApiRequest({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    if (apiKey == null) {
      throw Exception('API key is required for remote code generation');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    return await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// Extract code from API response
  String _extractCodeFromResponse(Map<String, dynamic> responseData) {
    try {
      final choices = responseData['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        return message['content'] as String;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Extract tokens used from response
  int _extractTokensUsed(Map<String, dynamic> responseData) {
    try {
      final usage = responseData['usage'] as Map<String, dynamic>;
      return usage['total_tokens'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get file extension from filename
  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return '.${parts.last}';
    }
    return '.dart'; // Default to .dart
  }

  /// Get Dart-specific coding guidelines
  String _getDartSpecificGuidelines() {
    return '''
Dart/Flutter Specific Guidelines:
- Use proper Dart naming conventions (camelCase for variables/functions, PascalCase for classes)
- Include necessary Flutter imports (material.dart, etc.)
- Use const constructors where appropriate
- Follow Flutter widget structure patterns
- Use proper state management patterns
- Include proper null safety
- Use async/await for asynchronous operations
- Include proper error handling with try-catch blocks
- Use meaningful widget names and structure
- Follow Flutter's widget composition patterns
- Include proper documentation comments for public APIs
- Use proper Flutter theming and styling approaches''';
  }

  /// Get general coding guidelines
  String _getGeneralGuidelines() {
    return '''
General Coding Guidelines:
- Use clear and descriptive variable names
- Include proper error handling
- Follow the language's best practices
- Use proper indentation and formatting
- Include necessary imports
- Add comments for complex logic
- Ensure code is readable and maintainable
- Follow the project's coding standards''';
  }

  /// Generate code from local templates (fallback)
  String _generateCodeFromTemplate({
    required String userPrompt,
    required String folderName,
    required String fileName,
    String? fileExtension,
  }) {
    final extension = fileExtension ?? _getFileExtension(fileName);
    final isDartFile = extension == '.dart';
    
    if (isDartFile) {
      return _generateDartTemplate(
        userPrompt: userPrompt,
        folderName: folderName,
        fileName: fileName,
      );
    } else {
      return _generateGeneralTemplate(
        userPrompt: userPrompt,
        folderName: folderName,
        fileName: fileName,
        extension: extension,
      );
    }
  }

  /// Generate Dart-specific template
  String _generateDartTemplate({
    required String userPrompt,
    required String folderName,
    required String fileName,
  }) {
    final className = _generateClassName(fileName);
    final isWidget = userPrompt.toLowerCase().contains('widget') || 
                     userPrompt.toLowerCase().contains('ui') ||
                     userPrompt.toLowerCase().contains('screen') ||
                     userPrompt.toLowerCase().contains('page');
    
    if (isWidget) {
      return '''import 'package:flutter/material.dart';

/// $className - ${userPrompt.trim()}
class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$className'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to $className',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Generated from: ${userPrompt.trim()}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement button action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Button pressed!')),
                );
              },
              child: const Text('Action Button'),
            ),
          ],
        ),
      ),
    );
  }
}''';
    } else {
      return '''/// $className - ${userPrompt.trim()}
class $className {
  /// Constructor
  $className();

  /// Initialize the class
  Future<void> initialize() async {
    // TODO: Implement initialization logic
    print('$className initialized');
  }

  /// Main method to execute the functionality
  Future<void> execute() async {
    try {
      await initialize();
      // TODO: Implement main functionality based on: ${userPrompt.trim()}
      print('Executing $className functionality');
    } catch (e) {
      print('Error in $className: \$e');
      rethrow;
    }
  }

  /// Cleanup resources
  void dispose() {
    // TODO: Implement cleanup logic
    print('$className disposed');
  }
}''';
    }
  }

  /// Generate general template for non-Dart files
  String _generateGeneralTemplate({
    required String userPrompt,
    required String folderName,
    required String fileName,
    required String extension,
  }) {
    return '''// $fileName - ${userPrompt.trim()}
// Generated for folder: $folderName
// File extension: $extension

// TODO: Implement functionality based on user prompt:
// ${userPrompt.trim()}

// Add your code here based on the requirements above.
// This is a template file - replace with actual implementation.''';
  }

  /// Generate class name from file name
  String _generateClassName(String fileName) {
    final nameWithoutExtension = fileName.split('.').first;
    final words = nameWithoutExtension.split(RegExp(r'[_\-\s]'));
    return words.map((word) => word.isNotEmpty 
        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
        : '').join('');
  }

  /// Validate API key format
  bool isValidApiKey(String? key) {
    if (key == null || key.isEmpty) return false;
    // Basic validation for OpenAI API key format
    return key.startsWith('sk-') && key.length > 20;
  }

  /// Get available models
  List<String> getAvailableModels() {
    return [
      'gpt-3.5-turbo',
      'gpt-4',
      'gpt-4-turbo',
      'gpt-4o',
      'gpt-4o-mini',
    ];
  }
}

/// Result of code generation
class CodeGenerationResult {
  final bool success;
  final String? code;
  final String? error;
  final String? model;
  final int tokensUsed;

  CodeGenerationResult({
    required this.success,
    this.code,
    this.error,
    this.model,
    this.tokensUsed = 0,
  });

  @override
  String toString() {
    if (success) {
      return 'CodeGenerationResult(success: true, model: $model, tokensUsed: $tokensUsed)';
    } else {
      return 'CodeGenerationResult(success: false, error: $error)';
    }
  }
} 