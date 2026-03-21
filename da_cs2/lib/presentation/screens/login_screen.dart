import 'package:flutter/material.dart';
import '../../logic/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  bool isSignUp = false;
  bool _isLoading = false;

  // Text controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Xử lý đăng ký
  Future<void> _handleSignUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng điền đầy đủ thông tin", Colors.red);
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Mật khẩu không khớp", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        email: email,
        password: password,
        username: username,
      );
      _showMessage("Đăng ký thành công!", Colors.green);
      _clearFields();
      setState(() => isSignUp = false);
    } catch (e) {
      _showMessage("Lỗi đăng ký: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Xử lý đăng nhập
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập email và mật khẩu", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithPassword(email: email, password: password);
    } catch (e) {
      _showMessage("Sai email hoặc mật khẩu", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Hiển thị message
  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  /// Xóa dữ liệu input
  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _usernameController.clear();
    _confirmPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Tab buttons: Login / Sign Up
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTabButton(
                  "Login",
                  !isSignUp,
                  () => setState(() {
                    isSignUp = false;
                    _clearFields();
                  }),
                ),
                _buildTabButton(
                  "Sign Up",
                  isSignUp,
                  () => setState(() {
                    isSignUp = true;
                    _clearFields();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 60),
            // Input fields
            if (isSignUp) _buildInput("Username", _usernameController, false),
            _buildInput("Email", _emailController, false),
            _buildInput("Password", _passwordController, true),
            if (isSignUp)
              _buildInput("Confirm Password", _confirmPasswordController, true),
            const SizedBox(height: 30),
            // Submit button
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (isSignUp ? _handleSignUp : _handleLogin),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isSignUp ? "CREATE ACCOUNT" : "LOG IN"),
            ),
          ],
        ),
      ),
    );
  }

  /// Build tab button widget
  Widget _buildTabButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: active ? 28 : 18,
          fontWeight: FontWeight.bold,
          color: active ? Colors.black : Colors.grey,
        ),
      ),
    );
  }

  /// Build input field widget
  Widget _buildInput(
    String hint,
    TextEditingController controller,
    bool isPassword,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
