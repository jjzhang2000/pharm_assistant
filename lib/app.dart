import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/add_edit_medicine_screen.dart';
import 'screens/medicine_detail_screen.dart';

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小药箱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/medicine/add': (context) => const AddEditMedicineScreen(),
        '/medicine/edit': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return AddEditMedicineScreen(medicineId: id);
        },
        '/medicine/detail': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return MedicineDetailScreen(medicineId: id);
        },
      },
    );
  }
}