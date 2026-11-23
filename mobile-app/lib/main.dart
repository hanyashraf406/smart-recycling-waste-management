import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'models/app_colors.dart';
import 'providers/theme_provider.dart';
import 'services/firebase_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/loading_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/user_login_screen.dart';
import 'screens/auth/employ_login_screen.dart';
import 'screens/auth/user_signup_screen.dart';
import 'screens/auth/employ_signup_screen.dart';
import 'screens/auth/user_forgot_password_screen.dart';
import 'screens/auth/employ_forgot_password_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/user/user_home_screen.dart';
import 'screens/user/user_profile_screen.dart';
import 'screens/user/user_history_screen.dart';
import 'screens/user/my_qr_screen.dart';
import 'screens/user/store_screen.dart';
import 'screens/user/water_bills_screen.dart';
import 'screens/user/electricity_bills_screen.dart';
import 'screens/user/gas_bills_screen.dart';
import 'screens/employ/employ_home_screen.dart';
import 'screens/employ/employ_profile_screen.dart';
import 'screens/employ/employ_inventory_screen.dart';
import 'screens/employ/employ_users_screen.dart';
import 'screens/employ/employ_reports_screen.dart';
import 'screens/employ/qr_scanner_screen.dart';
import 'screens/employ/material_input_screen.dart';
import 'screens/shared/map_screen.dart';
import 'screens/shared/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseService.initialize();
    await _initializeFirestoreData();
  } catch (e) {
    print(e);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeFirestoreData() async {
  final firestore = FirebaseFirestore.instance;

  try {
    final countersDoc = await firestore.collection('counters').doc('counters').get();
    if (!countersDoc.exists) {
      await firestore.collection('counters').doc('counters').set({
        'lastUserId': 0,
        'lastEmployeeId': 0,
        'lastProcessId': 0,
        'lastMaterialId': 3,
        'lastWarehouseId': 7,
        'lastStoreTransactionId': 0,
      });
    } else {
      final data = countersDoc.data()!;
      if (!data.containsKey('lastStoreTransactionId')) {
        await firestore.collection('counters').doc('counters').update({
          'lastStoreTransactionId': 0,
        });
      }
    }
  } catch (e) {}

  try {
    final warehousesSnapshot = await firestore.collection('warehouses').limit(1).get();
    if (warehousesSnapshot.docs.isEmpty) {
      final batch = firestore.batch();
      final warehouses = [
        {'warehouseId': 'WH-001', 'name': 'Madinaty', 'city': 'Cairo', 'address': 'Madinaty City', 'isActive': true},
        {'warehouseId': 'WH-002', 'name': 'Al Shorouk', 'city': 'Cairo', 'address': 'Al Shorouk City', 'isActive': true},
        {'warehouseId': 'WH-003', 'name': 'Al Rehab', 'city': 'Cairo', 'address': 'Al Rehab City', 'isActive': true},
        {'warehouseId': 'WH-004', 'name': 'New Cairo', 'city': 'Cairo', 'address': 'New Cairo City', 'isActive': true},
        {'warehouseId': 'WH-005', 'name': '6th of October', 'city': 'Giza', 'address': '6th of October City', 'isActive': true},
        {'warehouseId': 'WH-006', 'name': 'Sheikh Zayed', 'city': 'Giza', 'address': 'Sheikh Zayed City', 'isActive': true},
        {'warehouseId': 'WH-007', 'name': 'Al Obour', 'city': 'Qalyubia', 'address': 'Al Obour City', 'isActive': true},
      ];

      for (var wh in warehouses) {
        final docRef = firestore.collection('warehouses').doc(wh['warehouseId'] as String);
        batch.set(docRef, {
          'warehouseId': wh['warehouseId'],
          'name': wh['name'],
          'city': wh['city'],
          'address': wh['address'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (e) {}

  try {
    final materialsSnapshot = await firestore.collection('materials').limit(1).get();
    if (materialsSnapshot.docs.isEmpty) {
      final batch = firestore.batch();
      final materials = [
        {'materialId': 'M-001', 'name': 'Plastic', 'type': 'plastic', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
        {'materialId': 'M-002', 'name': 'Cans', 'type': 'cans', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
        {'materialId': 'M-003', 'name': 'Glass', 'type': 'glass', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
      ];

      for (var mat in materials) {
        final docRef = firestore.collection('materials').doc(mat['materialId'] as String);
        batch.set(docRef, {
          'materialId': mat['materialId'],
          'name': mat['name'],
          'type': mat['type'],
          'icon': mat['icon'],
          'pointsPerKg': mat['pointsPerKg'],
          'status': 'Active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (e) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'TRASH TO CASH',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.white,
            fontFamily: 'Poppins',
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: AppColors.textPrimary),
              titleTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: AppColors.textPrimary),
              bodyMedium: TextStyle(color: AppColors.textSecondary),
            ),
            cardColor: Colors.white,
            dialogBackgroundColor: Colors.white,
            useMaterial3: false,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: Colors.grey[900],
            fontFamily: 'Poppins',
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900],
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            textTheme: TextTheme(
              bodyLarge: const TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.grey[400]),
            ),
            cardColor: Colors.grey[800],
            dialogBackgroundColor: Colors.grey[800],
            useMaterial3: false,
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/role-selection': (context) => const RoleSelectionScreen(),
            '/user-login': (context) => const UserLoginScreen(),
            '/employ-login': (context) => const EmployLoginScreen(),
            '/user-signup': (context) => const UserSignupScreen(),
            '/employ-signup': (context) => const EmploySignupScreen(),
            '/user-forgot': (context) => const UserForgotPasswordScreen(),
            '/employ-forgot': (context) => const EmployForgotPasswordScreen(),
            '/qr-scanner': (context) => const QRScannerScreen(),
            '/material-input': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return MaterialInputScreen(
                userId: args['userId'] as String,
                userData: args['userData'] as Map<String, dynamic>,
              );
            },
            '/my-qr': (context) => const MyQRScreen(),
            '/user-home': (context) => const UserHomeScreen(),
            '/user-history': (context) => const UserHistoryScreen(),
            '/user-profile': (context) => const UserProfileScreen(),
            '/employ-home': (context) => const EmployHomeScreen(),
            '/employ-inventory': (context) => const EmployInventoryScreen(),
            '/employ-users': (context) => const EmployUsersScreen(),
            '/employ-reports': (context) => const EmployReportsScreen(),
            '/employ-profile': (context) => const EmployProfileScreen(),
            '/store': (context) => const StoreScreen(),
            '/water-bills': (context) => const WaterBillsScreen(),
            '/electricity-bills': (context) => const ElectricityBillsScreen(),
            '/gas-bills': (context) => const GasBillsScreen(),
            '/map': (context) => const MapScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/otp-verification': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return OtpVerificationScreen(email: args['email'] as String);
            },
            '/reset-password': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return ResetPasswordScreen(email: args['email'] as String);
            },
          },
        );
      },
    );
  }
}