// Trang đăng nhập
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isSignUp = false;

  // Controllers để lấy dữ liệu từ các ô nhập
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- HÀM XỬ LÝ ĐĂNG KÝ (SIGN UP) ---
  Future<void> _handleSignUp() async {
    try {
      // 1. Đăng ký tài khoản Auth với Supabase
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = res.user?.id;

      if (userId != null) {
        // 2. Lưu thông tin bổ sung vào bảng profiles
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'balance': 0,
        });

        _showMessage("Đăng ký thành công!", Colors.green);
      }
    } catch (e) {
      _showMessage("Lỗi: $e", Colors.red);
    }
  }

  // --- HÀM XỬ LÝ ĐĂNG NHẬP (LOGIN) ---
  Future<void> _handleLogin() async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      _showMessage("Sai thông tin đăng nhập", Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tabButton(
                  "Login",
                  !isSignUp,
                  () => setState(() => isSignUp = false),
                ),
                _tabButton(
                  "Sign Up",
                  isSignUp,
                  () => setState(() => isSignUp = true),
                ),
              ],
            ),
            const SizedBox(height: 60),
            // Ô Username chỉ hiện khi Đăng ký
            if (isSignUp) _buildInput("Username", _usernameController, false),
            _buildInput("Email", _emailController, false),
            _buildInput("Password", _passwordController, true),
            if (isSignUp)
              _buildInput("Confirm Password", _confirmPasswordController, true),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isSignUp ? _handleSignUp : _handleLogin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(isSignUp ? "CREATE ACCOUNT" : "LOG IN"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String text, bool active, VoidCallback onTap) {
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

  Widget _buildInput(
    String hint,
    TextEditingController controller,
    bool isPass,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
