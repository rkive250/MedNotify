import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final Function(String correo, String password) onLogin;
  final VoidCallback onRegister;

  const LoginScreen({required this.onLogin, required this.onRegister, super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  String mensaje = "";
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  DeviceType _getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return DeviceType.mobile;
    } else if (width < 1200) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  ResponsiveDimensions _getResponsiveDimensions(BuildContext context) {
    final deviceType = _getDeviceType(context);
    final screenWidth = MediaQuery.of(context).size.width;

    switch (deviceType) {
      case DeviceType.mobile:
        return ResponsiveDimensions(
          containerWidth: screenWidth * 0.9,
          logoSize: 140.0,
          titleFontSize: 24.0,
          subtitleFontSize: 14.0,
          horizontalPadding: 20.0,
          formPadding: 25.0,
          buttonHeight: 50.0,
          spacing: 20.0,
        );
      case DeviceType.tablet:
        return ResponsiveDimensions(
          containerWidth: screenWidth > 800 ? 600.0 : screenWidth * 0.7,
          logoSize: 180.0,
          titleFontSize: 32.0,
          subtitleFontSize: 16.0,
          horizontalPadding: 40.0,
          formPadding: 35.0,
          buttonHeight: 55.0,
          spacing: 30.0,
        );
      case DeviceType.desktop:
        return ResponsiveDimensions(
          containerWidth: 500.0,
          logoSize: 200.0,
          titleFontSize: 36.0,
          subtitleFontSize: 18.0,
          horizontalPadding: 50.0,
          formPadding: 40.0,
          buttonHeight: 60.0,
          spacing: 40.0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);
    final deviceType = _getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: dimensions.horizontalPadding,
              vertical: 20,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: dimensions.containerWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: dimensions.logoSize,
                      height: dimensions.logoSize,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(isDesktop ? 40 : 35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: isDesktop ? 30 : 25,
                            offset: Offset(0, isDesktop ? 20 : 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isDesktop ? 40 : 35),
                        child: Image.asset(
            'assets/mednotify.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.medical_services,
                              size: dimensions.logoSize * 0.5,
                              color: Colors.grey[600],
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: dimensions.spacing),
                    Text(
                      "WELCOME",
                      style: TextStyle(
                        fontSize: dimensions.titleFontSize,
                        fontFamily: 'Kalam',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Inicia sesión para continuar",
                      style: TextStyle(
                        fontSize: dimensions.subtitleFontSize,
                        fontFamily: 'Kalam',
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: dimensions.spacing),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(dimensions.formPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Correo electrónico",
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.black, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              labelStyle: TextStyle(
                                fontFamily: 'Kalam',
                                color: Colors.grey[600],
                                fontSize: isDesktop ? 16 : 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isDesktop ? 20 : 16,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.black, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              labelStyle: TextStyle(
                                fontFamily: 'Kalam',
                                color: Colors.grey[600],
                                fontSize: isDesktop ? 16 : 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isDesktop ? 20 : 16,
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: dimensions.buttonHeight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.grey.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final correo = _correoController.text.trim();
                                      final pass = _passwordController.text.trim();

                                      if (correo.isEmpty || pass.isEmpty) {
                                        setState(() {
                                          mensaje = "Por favor llena todos los campos.";
                                        });
                                        return;
                                      }

                                      setState(() {
                                        _isLoading = true;
                                        mensaje = "";
                                      });

                                      try {
                                        await widget.onLogin(correo, pass);
                                      } catch (e) {
                                        setState(() {
                                          mensaje = "Error al iniciar sesión. Intenta nuevamente.";
                                        });
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      "Iniciar Sesión",
                                      style: TextStyle(
                                        fontSize: isDesktop ? 20 : 18,
                                        fontFamily: 'Kalam',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 20),
                          if (mensaje.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.grey[700], size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      mensaje,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Kalam',
                                        fontSize: isDesktop ? 16 : 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: dimensions.spacing),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "¿No tienes cuenta? ",
                          style: TextStyle(
                            fontSize: dimensions.subtitleFontSize,
                            color: Colors.grey[600],
                            fontFamily: 'Kalam',
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onRegister,
                          child: Text(
                            "Regístrate",
                            style: TextStyle(
                              fontSize: dimensions.subtitleFontSize,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kalam',
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum DeviceType { mobile, tablet, desktop }

class ResponsiveDimensions {
  final double containerWidth;
  final double logoSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double horizontalPadding;
  final double formPadding;
  final double buttonHeight;
  final double spacing;

  ResponsiveDimensions({
    required this.containerWidth,
    required this.logoSize,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.horizontalPadding,
    required this.formPadding,
    required this.buttonHeight,
    required this.spacing,
  });
}