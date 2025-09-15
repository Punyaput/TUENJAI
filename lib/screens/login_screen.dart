import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_button.dart';
import '../widgets/logo_widget.dart';
import '../widgets/background_circles.dart';
import './otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _acceptedTerms = false;
  String _selectedCountryCode = '+66';
  String _selectedCountryFlag = '🇹🇭';

  final List<Map<String, String>> _countries = [
    {'code': '+66', 'flag': '🇹🇭', 'name': 'Thailand'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+82', 'flag': '🇰🇷', 'name': 'South Korea'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
  ];

  bool get _isFormValid {
    return _phoneController.text.isNotEmpty && _acceptedTerms;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'เลือกประเทศ',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        country['name']!,
                        style: const TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: 16,
                        ),
                      ),
                      trailing: Text(
                        country['code']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                          _selectedCountryFlag = country['flag']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Background circles
            Positioned(
              top: -screenHeight * 0.08,
              left: -screenWidth * 0.34,
              child: const TopBackgroundCircles(),
            ),
            Positioned(
              bottom: -screenHeight * 0.1,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),

            // Scrollable main content
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.1),
                  const LogoWidget(),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: screenWidth * 0.11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E88F3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Phone input
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'หมายเลขโทรศัพท์',
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _showCountryPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_selectedCountryFlag,
                                        style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 4),
                                    Text(_selectedCountryCode,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'เช่น 0812345678',
                                  hintStyle: TextStyle(
                                      fontFamily: 'NotoLoopedThaiUI',
                                      color: Colors.grey[400]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF2E88F3), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Terms checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _acceptedTerms
                                ? const Color(0xFF2E88F3)
                                : Colors.white,
                            border: Border.all(
                                color: _acceptedTerms
                                    ? const Color(0xFF2E88F3)
                                    : const Color(0xFFD1D5DB),
                                width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _acceptedTerms
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontFamily: 'NotoLoopedThaiUI',
                                fontSize: screenWidth * 0.035,
                                color: const Color(0xFF374151),
                                height: 1.5),
                            children: [
                              const TextSpan(text: 'ฉันยอมรับ '),
                              TextSpan(
                                text: 'ข้อกำหนดการใช้งาน',
                                style: TextStyle(
                                    color: const Color(0xFF2E88F3),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFF2E88F3)),
                              ),
                              const TextSpan(text: ' และ '),
                              TextSpan(
                                text: 'นโยบายความเป็นส่วนตัว',
                                style: TextStyle(
                                    color: const Color(0xFF2E88F3),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFF2E88F3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.05),

                  CustomButton(
                  text: 'ดำเนินการต่อ',
                  isEnabled: _isFormValid,
                  onPressed: _isFormValid
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtpVerificationScreen(
                                phoneNumber: _phoneController.text,
                                countryCode: _selectedCountryCode,
                              ),
                            ),
                          );
                        }
                      : () {},
                ),

                  SizedBox(height: screenHeight * 0.2), // bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
