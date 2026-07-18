import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DemoSetupService {
  static Future<void> setupInitialData() async {
    final db = DatabaseService();
    final uuid = const Uuid();

    // 1. Create Categories
    await db.addCategory(CategoryModel(id: 'cat1', name: 'Charger'));
    await db.addCategory(CategoryModel(id: 'cat2', name: 'Battery'));
    await db.addCategory(CategoryModel(id: 'cat3', name: 'Display'));
    await db.addCategory(CategoryModel(id: 'cat4', name: 'Headphones'));

    // 2. Create Sample Products
    await db.addProduct(ProductModel(
      id: uuid.v4(),
      name: 'Fast Charger 20W',
      category: 'Charger',
      price: 1500,
      units: 20,
      shopId: 'Shop 1',
    ));
  }

  static Future<String?> createFirstOwner(String email, String password, String name) async {
    final auth = FirebaseAuth.instance;
    try {
      UserCredential result = await auth.createUserWithEmailAndPassword(email: email, password: password);
      final userModel = UserModel(
        uid: result.user!.uid,
        email: email,
        name: name,
        role: 'owner',
      );
      await DatabaseService().updateUser(userModel);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
