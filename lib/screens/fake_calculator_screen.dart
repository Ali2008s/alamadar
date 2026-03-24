import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';

class FakeCalculatorScreen extends StatefulWidget {
  const FakeCalculatorScreen({super.key});

  @override
  State<FakeCalculatorScreen> createState() => _FakeCalculatorScreenState();
}

class _FakeCalculatorScreenState extends State<FakeCalculatorScreen> {
  String _display = '0';
  String _expression = '';
  double? _firstOperand;
  String? _operator;
  bool _shouldClearDisplay = false;

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _display = '0';
        _expression = '';
        _firstOperand = null;
        _operator = null;
        _shouldClearDisplay = false;
      } else if (value == '+' || value == '-' || value == '×' || value == '÷') {
        if (_firstOperand == null) {
          _firstOperand = double.tryParse(_display);
          _operator = value;
          _expression = '$_display $value ';
          _shouldClearDisplay = true;
        } else {
          _calculateResult();
          _operator = value;
          _expression = '$_display $value ';
          _firstOperand = double.tryParse(_display);
          _shouldClearDisplay = true;
        }
      } else if (value == '=') {
        _calculateResult();
        _operator = null;
        _firstOperand = null;
        _expression = '';
        _shouldClearDisplay = true;
      } else {
        if (_display == '0' || _shouldClearDisplay) {
          _display = value;
          _shouldClearDisplay = false;
        } else {
          _display += value;
        }
      }
    });
  }

  void _calculateResult() {
    if (_firstOperand == null || _operator == null) return;
    double? secondOperand = double.tryParse(_display);
    if (secondOperand == null) return;

    double result = 0;
    switch (_operator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        if (secondOperand != 0) {
          result = _firstOperand! / secondOperand;
        } else {
          _display = 'خطأ';
          return;
        }
        break;
    }

    // Format result: remove decimal if integer
    if (result == result.toInt().toDouble()) {
      _display = result.toInt().toString();
    } else {
      _display = result.toStringAsFixed(2);
    }
  }

  Widget _buildButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.white.withOpacity(0.05),
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            elevation: 0,
          ),
          onPressed: () => _onButtonPressed(text),
          child: Text(
            text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression,
                    style: const TextStyle(color: Colors.white54, fontSize: 18),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildButton('C', textColor: Colors.redAccent),
              _buildButton('÷', color: AppColors.accentBlue.withOpacity(0.2)),
            ],
          ),
          Row(
            children: [
              _buildButton('7'),
              _buildButton('8'),
              _buildButton('9'),
              _buildButton('×', color: AppColors.accentBlue.withOpacity(0.2)),
            ],
          ),
          Row(
            children: [
              _buildButton('4'),
              _buildButton('5'),
              _buildButton('6'),
              _buildButton('-', color: AppColors.accentBlue.withOpacity(0.2)),
            ],
          ),
          Row(
            children: [
              _buildButton('1'),
              _buildButton('2'),
              _buildButton('3'),
              _buildButton('+', color: AppColors.accentBlue.withOpacity(0.2)),
            ],
          ),
          Row(
            children: [
              _buildButton('0'),
              _buildButton('.'),
              _buildButton(
                '=',
                color: AppColors.accentBlue,
                textColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
