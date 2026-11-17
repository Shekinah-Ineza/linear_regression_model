import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Public Render service. Replace the host with your deployed service.
///
/// Android emulator calling an API on this computer: http://10.0.2.2:8000
/// iOS simulator calling an API on this computer: http://127.0.0.1:8000
const String apiBaseUrl = 'https://kiva-loan-amount.onrender.com';

void main() {
  runApp(const KivaApp());
}

class KivaApp extends StatelessWidget {
  const KivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiva loan amount',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const PredictPage(),
    );
  }
}

class InputSpec {
  const InputSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.kind,
  });

  final String key;
  final String label;
  final String hint;
  final String kind;
}

const List<InputSpec> inputFields = [
  InputSpec(key: 'country', label: 'Country', hint: 'Kenya', kind: 'text'),
  InputSpec(
    key: 'sector',
    label: 'Sector',
    hint: 'Agriculture',
    kind: 'text',
  ),
  InputSpec(
    key: 'activity',
    label: 'Activity',
    hint: 'Farming',
    kind: 'text',
  ),
  InputSpec(
    key: 'repayment_interval',
    label: 'Repayment interval',
    hint: 'monthly',
    kind: 'text',
  ),
  InputSpec(
    key: 'loan_theme_type',
    label: 'Loan theme type',
    hint: 'General',
    kind: 'text',
  ),
  InputSpec(
    key: 'term_in_months',
    label: 'Term in months',
    hint: '14',
    kind: 'int',
  ),
  InputSpec(
    key: 'borrower_count',
    label: 'Borrower count',
    hint: '1',
    kind: 'int',
  ),
  InputSpec(
    key: 'female_borrower_share',
    label: 'Female borrower share (0 to 1)',
    hint: '1',
    kind: 'double',
  ),
  InputSpec(
    key: 'mpi',
    label: 'Regional MPI (0 to 1)',
    hint: '0.06',
    kind: 'double',
  ),
  InputSpec(
    key: 'rural_pct',
    label: 'Rural population percent (0 to 100)',
    hint: '69',
    kind: 'double',
  ),
];

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final field in inputFields) field.key: TextEditingController(),
  };

  String _result = 'The predicted loan amount will appear here.';
  bool _loading = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextInputType _keyboard(String kind) {
    switch (kind) {
      case 'int':
        return TextInputType.number;
      case 'double':
        return const TextInputType.numberWithOptions(decimal: true);
      default:
        return TextInputType.text;
    }
  }

  dynamic _encode(InputSpec field) {
    final text = _controllers[field.key]!.text.trim();
    if (field.kind == 'int') {
      return int.tryParse(text) ?? text;
    }
    if (field.kind == 'double') {
      return double.tryParse(text) ?? text;
    }
    return text;
  }

  String _formatError(String body) {
    try {
      final decoded = jsonDecode(body);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is List) {
        return detail.map((item) {
          final location = item['loc'];
          final field = location is List && location.length > 1
              ? location.sublist(1).join('.')
              : 'request';
          return '$field: ${item['msg']}';
        }).join('\n');
      }
      if (detail is String) {
        return detail;
      }
    } catch (_) {
      // The body was not a FastAPI validation payload.
    }
    return body;
  }

  Future<void> _predict() async {
    for (final field in inputFields) {
      if (_controllers[field.key]!.text.trim().isEmpty) {
        setState(() {
          _result = '${field.label} is missing. Enter a value before predicting.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _result =
          'Requesting a prediction. A free Render service can take up to a minute to wake.';
    });

    final payload = {
      for (final field in inputFields) field.key: _encode(field),
    };

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final amount = decoded['predicted_loan_amount_usd'];
        setState(() {
          _result = 'Predicted loan amount: $amount USD';
        });
        return;
      }

      final body = response.body.trimLeft();
      if (body.startsWith('<')) {
        setState(() {
          _result =
              'The API did not return a prediction. If the Render free service is asleep, open $apiBaseUrl/docs, wait for Swagger to load, then press Predict again.';
        });
        return;
      }

      setState(() {
        _result = _formatError(response.body);
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _result =
            'The API did not answer within 90 seconds. On the Render free plan, open $apiBaseUrl/docs once to wake the service, then press Predict again.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = 'Could not reach the API at $apiBaseUrl. $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiva loan amount')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recommended loan amount for a Kiva field partner',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the borrower group. The predicted value is in US dollars.',
              ),
              const SizedBox(height: 16),
              for (final field in inputFields) ...[
                Text(
                  field.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _controllers[field.key],
                  keyboardType: _keyboard(field.kind),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: field.hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _loading ? null : _predict,
                  child: const Text('Predict'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Prediction',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_result),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
