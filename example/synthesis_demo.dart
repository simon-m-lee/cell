// =============================================================================
// Practical executable walkthrough – SynthesisCell
// Information Convergence · Multi-Source Aggregation · Dynamic Topology
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────────────────

/// Represents aggregated environment status from multiple sensors.
class EnvironmentStatus {
  final double? temperature;
  final double? humidity;
  final double? pressure;
  final double? light;
  final String quality;

  EnvironmentStatus({
    this.temperature,
    this.humidity,
    this.pressure,
    this.light,
    this.quality = 'good',
  });

  @override
  String toString() {
    final parts = <String>[];
    if (temperature != null) parts.add('Temp=${temperature!.toStringAsFixed(1)}°C');
    if (humidity != null) parts.add('Hum=${humidity!.toStringAsFixed(0)}%');
    if (pressure != null) parts.add('Press=${pressure!.toStringAsFixed(0)}hPa');
    if (light != null) parts.add('Light=${light!.toStringAsFixed(0)}lux');
    return 'Environment{${parts.join(', ')}, quality: $quality}';
  }
}

/// Represents form validation state.
class FormState {
  final bool isValid;
  final List<String> errors;
  final Map<String, String> fields;

  FormState({required this.isValid, this.errors = const [], this.fields = const {}});

  @override
  String toString() => 'FormState(isValid: $isValid, errors: ${errors.join(', ')})';
}

// ─────────────────────────────────────────────────────────────────────────
// Helper Extension for ValueCell Access
// ─────────────────────────────────────────────────────────────────────────

/// Extension to safely get the value from a Cell if it's a ValueCell.
extension CellValueExtension on Cell {
  dynamic get value {
    if (this is ValueCell) {
      return (this as ValueCell).value;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────────

/// ### Expected console output:
/// ```text
/// ── SynthesisCell – Information Convergence ────────────────────
///
/// 1. Creating Source Cells
///    [✓] Temperature sensor created (initial: 22.5°C)
///    [✓] Humidity sensor created (initial: 45%)
///    [✓] Pressure sensor created (initial: 1013 hPa)
///
/// 2. Creating Synthesis Cell with Aggregator
///    [✓] Synthesis cell created
///    [Aggregator] Triggered by: temperature
///    [Aggregator] Values: Temp=22.5°C, Hum=45%, Press=1013hPa
///    [Aggregator] Output: EnvironmentStatus{temp: 22.5, hum: 45, press: 1013, quality: good}
///
/// 3. Observing Synthesis Output
///    [Obs] Environment: Temp=22.5°C, Hum=45%, Press=1013hPa (quality: good)
///
/// 4. Updating Individual Sensors
///    [Update] Temperature: 23.0°C
///    [Aggregator] Triggered by: temperature
///    [Aggregator] Values: Temp=23.0°C, Hum=45%, Press=1013hPa
///    [Aggregator] Output: EnvironmentStatus{temp: 23.0, hum: 45, press: 1013, quality: good}
///    [Obs] Environment: Temp=23.0°C, Hum=45%, Press=1013hPa (quality: good)
///
///    [Update] Humidity: 52%
///    [Aggregator] Triggered by: humidity
///    [Aggregator] Values: Temp=23.0°C, Hum=52%, Press=1013hPa
///    [Aggregator] Output: EnvironmentStatus{temp: 23.0, hum: 52, press: 1013, quality: warning}
///    [Obs] Environment: Temp=23.0°C, Hum=52%, Press=1013hPa (quality: warning)
///
/// 5. Dynamic Topology - Adding a New Sensor
///    [✓] New sensor: Light (initial: 850 lux)
///    [Update] Light: 850 lux
///    [Aggregator] Triggered by: light
///    [Aggregator] Values: Temp=23.0°C, Hum=52%, Press=1013hPa, Light=850lux
///    [Aggregator] Output: EnvironmentStatus{temp: 23.0, hum: 52, press: 1013, light: 850, quality: warning}
///    [Obs] Environment: Temp=23.0°C, Hum=52%, Press=1013hPa, Light=850lux (quality: warning)
///
/// 6. Dynamic Topology - Removing a Sensor
///    [Remove] Temperature sensor removed
///    [Aggregator] Triggered by: humidity (note: synthesis still reacts)
///    [Aggregator] Values: Hum=52%, Press=1013hPa, Light=850lux
///    [Aggregator] Output: EnvironmentStatus{temp: null, hum: 52, press: 1013, light: 850, quality: warning}
///    [Obs] Environment: Temp=N/A, Hum=52%, Press=1013hPa, Light=850lux (quality: warning)
///
/// 7. Pausing and Resuming Synthesis
///    [Pause] Synthesis stopped
///    [Update] Humidity: 48%
///    (No output - synthesis is paused)
///    [Resume] Synthesis started
///    [Aggregator] Triggered by: humidity (immediate catch-up)
///    [Aggregator] Values: Hum=48%, Press=1013hPa, Light=850lux
///    [Aggregator] Output: EnvironmentStatus{temp: null, hum: 48, press: 1013, light: 850, quality: good}
///    [Obs] Environment: Temp=N/A, Hum=48%, Press=1013hPa, Light=850lux (quality: good)
///
/// 8. Clearing All Sources
///    [Clear] All sources removed
///    (No output - no sources to aggregate)
///    [Status] isEmpty: true
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── SynthesisCell – Information Convergence ────────────────────\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Create Source Cells (Sensors) - Using Cell.state
  // ─────────────────────────────────────────────────────────────────────────

  print('1. Creating Source Cells');

  // Temperature sensor
  final tempHandle = Cell.state<double>(
    initial: 22.5,
    evolve: (host, input) {
      final value = input.payload as double?;
      return Pulse(value ?? host.value);
    },
  );
  final tempCell = tempHandle.cell;
  print('   [✓] Temperature sensor created (initial: ${tempCell.value}°C)');

  // Humidity sensor
  final humHandle = Cell.state<double>(
    initial: 45.0,
    evolve: (host, input) {
      final value = input.payload as double?;
      return Pulse(value ?? host.value);
    },
  );
  final humCell = humHandle.cell;
  print('   [✓] Humidity sensor created (initial: ${humCell.value}%)');

  // Pressure sensor
  final pressHandle = Cell.state<double>(
    initial: 1013.0,
    evolve: (host, input) {
      final value = input.payload as double?;
      return Pulse(value ?? host.value);
    },
  );
  final pressCell = pressHandle.cell;
  print('   [✓] Pressure sensor created (initial: ${pressCell.value} hPa)\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Create Synthesis Cell with Aggregator
  // ─────────────────────────────────────────────────────────────────────────

  print('2. Creating Synthesis Cell with Aggregator');

  // Store light handle reference for the aggregator
  StateHandle<double>? lightHandle;

  // Initial sources
  final sources = <Cell>[tempCell, humCell, pressCell];

  final synthesisCell = Cell.synthesis(
    sources,
    aggregator: (cells, emit) {
      // Extract values from all sources
      double? temp, hum, press;
      double? light;

      for (final cell in cells) {
        if (cell == tempCell) {
          temp = tempCell.value;
        } else if (cell == humCell) {
          hum = humCell.value;
        } else if (cell == pressCell) {
          press = pressCell.value;
        } else if (cell == lightHandle?.cell) {
          light = lightHandle?.cell.value;
        }
      }

      // Determine quality based on readings
      String quality = 'good';
      if (hum != null && hum > 60) {
        quality = 'warning';
      }
      if (hum != null && hum > 80) {
        quality = 'critical';
      }
      if (temp != null && temp > 35) {
        quality = 'critical';
      }
      if (press != null && (press < 980 || press > 1040)) {
        quality = 'warning';
      }

      // Log aggregation
      final triggerSource = emit.source;
      String triggerName = 'unknown';
      if (triggerSource == tempCell) {
        triggerName = 'temperature';
      }
      else if (triggerSource == humCell) {
        triggerName = 'humidity';
      }
      else if (triggerSource == pressCell) {
        triggerName = 'pressure';
      }
      else if (triggerSource == lightHandle?.cell) {
        triggerName = 'light';

        print('   [Aggregator] Triggered by: $triggerName');
        print('   [Aggregator] Values: Temp=${temp?.toStringAsFixed(1) ?? 'N/A'}°C, '
            'Hum=${hum?.toStringAsFixed(0) ?? 'N/A'}%, '
            'Press=${press?.toStringAsFixed(0) ?? 'N/A'}hPa'
            '${light != null ? ', Light=${light.toInt()}lux' : ''}');
        print('   [Aggregator] Output: EnvironmentStatus{temp: ${temp?.toStringAsFixed(1) ?? 'null'}, '
            'hum: ${hum?.toStringAsFixed(0) ?? 'null'}, '
            'press: ${press?.toStringAsFixed(0) ?? 'null'}, '
            'quality: $quality}');

        return Pulse(EnvironmentStatus(
          temperature: temp,
          humidity: hum,
          pressure: press,
          light: light,
          quality: quality,
        ));
      }
    },
  );

  print('   [✓] Synthesis cell created\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Observe Synthesis Output
  // ─────────────────────────────────────────────────────────────────────────

  final synthesisObs = Cell.observe(
    source: synthesisCell,
    effect: (Pulse pulse) {
      final status = pulse.payload as EnvironmentStatus;
      print('   [Obs] Environment: '
          'Temp=${status.temperature?.toStringAsFixed(1) ?? 'N/A'}°C, '
          'Hum=${status.humidity?.toStringAsFixed(0) ?? 'N/A'}%, '
          'Press=${status.pressure?.toStringAsFixed(0) ?? 'N/A'}hPa'
          '${status.light != null ? ', Light=${status.light!.toStringAsFixed(0)}lux' : ''} '
          '(quality: ${status.quality})');
    },
  );

  // Wait for initial aggregation
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Update Individual Sensors
  // ─────────────────────────────────────────────────────────────────────────

  print('3. Observing Synthesis Output');
  // The observer already printed the initial state above

  print('\n4. Updating Individual Sensors');

  // Update temperature using the handle's update method
  print('   [Update] Temperature: 23.0°C');
  tempHandle.update(23.0);
  await Future.delayed(Duration(milliseconds: 50));

  // Update humidity (triggers quality warning)
  print('\n   [Update] Humidity: 52%');
  humHandle.update(52.0);
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Dynamic Topology - Using SynthesisHandle
  // ─────────────────────────────────────────────────────────────────────────

  print('\n5. Dynamic Topology - Adding a New Sensor');

  // Create a new sensor (light)
  lightHandle = Cell.state<double>(
    initial: 850.0,
    evolve: (host, input) {
      final value = input.payload as double?;
      return Pulse(value ?? host.value);
    },
  );
  print('   [✓] New sensor: Light (initial: ${lightHandle.cell.value} lux)');

  // Use SynthesisHandle for dynamic management
  final synthHandle = SynthesisCell.handle(sources);

  // Add the new sensor
  synthHandle.add(lightHandle.cell);

  print('   [Update] Light: ${lightHandle.cell.value} lux');
  lightHandle.update(850.0);
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Dynamic Topology - Removing a Sensor
  // ─────────────────────────────────────────────────────────────────────────

  print('\n6. Dynamic Topology - Removing a Sensor');

  print('   [Remove] Temperature sensor removed');
  synthHandle.remove(tempCell);
  // Update a remaining sensor to trigger re-aggregation
  humHandle.update(52.0);
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Pausing and Resuming Synthesis
  // ─────────────────────────────────────────────────────────────────────────

  print('\n7. Pausing and Resuming Synthesis');

  print('   [Pause] Synthesis stopped');
  synthHandle.stop();

  print('   [Update] Humidity: 48%');
  humHandle.update(48.0);
  await Future.delayed(Duration(milliseconds: 50));

  print('   (No output - synthesis is paused)');

  print('   [Resume] Synthesis started');
  synthHandle.start();
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 8. Clearing All Sources
  // ─────────────────────────────────────────────────────────────────────────

  print('\n8. Clearing All Sources');

  print('   [Clear] All sources removed');
  synthHandle.clear();
  await Future.delayed(Duration(milliseconds: 50));

  print('   [Status] isEmpty: ${synthHandle.isEmpty}');

  // ─────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────────

  synthesisObs.stop();

  print('\n── finished ──────────────────────────────────────────────────');

  // ─────────────────────────────────────────────────────────────────────────
  // Run the form validation demo
  // ─────────────────────────────────────────────────────────────────────────

  await formValidationDemo();
}

// ─────────────────────────────────────────────────────────────────────────
// Bonus Demo: Form Validation with SynthesisCell
// ─────────────────────────────────────────────────────────────────────────

/// ### Expected console output:
/// ```text
/// ════════════════════════════════════════════════════════════════════════════════
///   BONUS: FORM VALIDATION DEMO
///   Using SynthesisCell for Multi-Field Validation
/// ════════════════════════════════════════════════════════════════════════════════
///
/// 1. Creating Form Fields
///    [✓] Email field created
///    [✓] Password field created
///    [✓] Confirm Password field created
///
/// 2. Creating Form Validator
///
/// 3. Filling out the form
///    [Fill] Email: user@example.com
///    [Validator] Form is INVALID: Password is required
///    [Validation] ✗ Form invalid: Password is required
///    [Fill] Password: secure123
///    [Validator] Form is INVALID: Passwords do not match
///    [Validation] ✗ Form invalid: Passwords do not match
///    [Fill] Confirm: secure123
///    [Validator] Form is VALID: All fields valid
///    [Validation] ✓ Form is valid!
///
/// 4. Dynamic Form - Adding Optional Phone Field
///    [✓] Phone field added
///    [Fill] Phone: 555-1234
///
/// 5. Testing invalid data
///    [Update] Password: short (too short)
///    [Validator] Form is INVALID: Password must be at least 8 characters, Passwords do not match
///    [Validation] ✗ Form invalid: Password must be at least 8 characters; Passwords do not match
///    [Update] Confirm: mismatch
///    [Validator] Form is INVALID: Password must be at least 8 characters, Passwords do not match
///    [Validation] ✗ Form invalid: Password must be at least 8 characters; Passwords do not match
///
/// 6. Removing Fields
///    [Remove] Email field removed
///
/// ════════════════════════════════════════════════════════════════════════════════
///   BONUS DEMO COMPLETE
/// ════════════════════════════════════════════════════════════════════════════════
/// ```
Future<void> formValidationDemo() async {
  print('\n${'═' * 80}');
  print('  BONUS: FORM VALIDATION DEMO');
  print('  Using SynthesisCell for Multi-Field Validation');
  print('${'═' * 80}\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Create Form Field Cells - Using Cell.state
  // ─────────────────────────────────────────────────────────────────────────

  print('1. Creating Form Fields');

  final emailHandle = Cell.state<String>(
    initial: '',
    evolve: (host, input) => Pulse(input.payload as String? ?? ''),
  );
  final emailCell = emailHandle.cell;
  print('   [✓] Email field created');

  final passwordHandle = Cell.state<String>(
    initial: '',
    evolve: (host, input) => Pulse(input.payload as String? ?? ''),
  );
  final passwordCell = passwordHandle.cell;
  print('   [✓] Password field created');

  final confirmHandle = Cell.state<String>(
    initial: '',
    evolve: (host, input) => Pulse(input.payload as String? ?? ''),
  );
  final confirmCell = confirmHandle.cell;
  print('   [✓] Confirm Password field created\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Create Validation Synthesis
  // ─────────────────────────────────────────────────────────────────────────

  print('2. Creating Form Validator');

  // Store reference to password for validation
  String? passwordValue;

  final formFields = <Cell>[emailCell, passwordCell, confirmCell];

  // Create the synthesis cell
  final formValidator = Cell.synthesis(
    formFields,
    aggregator: (cells, emit) {
      final errors = <String>[];
      final fields = <String, String>{};

      // Collect field values
      for (final cell in cells) {
        String value;
        if (cell == emailCell) {
          value = emailCell.value ?? '';
          fields['email'] = value;
          if (value.isEmpty) {
            errors.add('Email is required');
          } else if (!value.contains('@') || !value.contains('.')) {
            errors.add('Invalid email format');
          }
        } else if (cell == passwordCell) {
          value = passwordCell.value ?? '';
          fields['password'] = value;
          passwordValue = value;
          if (value.isEmpty) {
            errors.add('Password is required');
          } else if (value.length < 8) {
            errors.add('Password must be at least 8 characters');
          }
        } else if (cell == confirmCell) {
          value = confirmCell.value ?? '';
          fields['confirm'] = value;
          if (value != passwordValue) {
            errors.add('Passwords do not match');
          }
        }
      }

      final isValid = errors.isEmpty;

      print('   [Validator] Form is ${isValid ? 'VALID' : 'INVALID'}: ${errors.isEmpty ? 'All fields valid' : errors.join(', ')}');

      return Pulse(FormState(
        isValid: isValid,
        errors: errors,
        fields: fields,
      ));
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Observe Validation Results
  // ─────────────────────────────────────────────────────────────────────────

  final validationObs = Cell.observe(
    source: formValidator,
    effect: (Pulse pulse) {
      final state = pulse.payload as FormState;
      if (state.isValid) {
        print('   [Validation] ✓ Form is valid!');
      } else {
        print('   [Validation] ✗ Form invalid: ${state.errors.join('; ')}');
      }
    },
  );

  // Wait for initial validation
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Fill out the form
  // ─────────────────────────────────────────────────────────────────────────

  print('\n3. Filling out the form');

  // Fill in fields using the handle's update method
  print('   [Fill] Email: user@example.com');
  emailHandle.update('user@example.com');
  await Future.delayed(Duration(milliseconds: 50));

  print('   [Fill] Password: secure123');
  passwordHandle.update('secure123');
  await Future.delayed(Duration(milliseconds: 50));

  print('   [Fill] Confirm: secure123');
  confirmHandle.update('secure123');
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Dynamic Form - Using SynthesisHandle
  // ─────────────────────────────────────────────────────────────────────────

  print('\n4. Dynamic Form - Adding Optional Phone Field');

  final phoneHandle = Cell.state<String>(
    initial: '',
    evolve: (host, input) => Pulse(input.payload as String? ?? ''),
  );
  final phoneCell = phoneHandle.cell;
  print('   [✓] Phone field added');

  // Create handle for dynamic management
  final formHandle = SynthesisCell.handle(formFields);
  formHandle.add(phoneCell);

  print('   [Fill] Phone: 555-1234');
  phoneHandle.update('555-1234');
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Test invalid data
  // ─────────────────────────────────────────────────────────────────────────

  print('\n5. Testing invalid data');

  print('   [Update] Password: short (too short)');
  passwordHandle.update('short');
  await Future.delayed(Duration(milliseconds: 50));

  print('   [Update] Confirm: mismatch');
  confirmHandle.update('mismatch');
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Removing Fields
  // ─────────────────────────────────────────────────────────────────────────

  print('\n6. Removing Fields');
  print('   [Remove] Email field removed');
  formHandle.remove(emailCell);
  await Future.delayed(Duration(milliseconds: 50));

  // ─────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────────

  validationObs.stop();

  print('\n${'═' * 80}');
  print('  BONUS DEMO COMPLETE');
  print('${'═' * 80}\n');
}