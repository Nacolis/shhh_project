import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'widgets/widgets.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const ShhhApp());
}

class ShhhApp extends StatelessWidget {
  const ShhhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'SHHH',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<AppProvider>();
    await provider.initialize();
    
    if (mounted) {
      // Va au screen approprié après l'initialisation
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return provider.isAuthenticated 
                ? const ConversationsScreen() 
                : const AuthScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ScanlineOverlay(
        child: NoiseOverlay(
          opacity: 0.05,
          child: GridBackground(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ASCII Logo
                  Text(
                    '''
███████╗██╗  ██╗██╗  ██╗██╗  ██╗
██╔════╝██║  ██║██║  ██║██║  ██║
███████╗███████║███████║███████║
╚════██║██╔══██║██╔══██║██╔══██║
███████║██║  ██║██║  ██║██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝''',
                    style: AppTextStyles.code.copyWith(
                      fontSize: 6,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const GlitchText(
                    text: 'SHHH',
                    glitchIntensity: 0.08,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '// ENCRYPTED_COMMUNICATIONS',
                    style: AppTextStyles.terminal,
                  ),
                  const SizedBox(height: 48),
                  const AsciiLoader(),
                  const SizedBox(height: 16),
                  const TypewriterText(
                    text: 'INITIALIZING_SECURE_CHANNEL...',
                    typingSpeed: Duration(milliseconds: 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
