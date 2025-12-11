import 'dart:async';



import 'package:mobx/mobx.dart';

import 'package:shared_preferences/shared_preferences.dart';


part 'appStore.g.dart';

// This is the class used by rest of your codebase
class AppStore = _AppStore with _$AppStore;

// The store-class
abstract class _AppStore with Store {
  @observable
  bool isLoggedIn = false;

  @observable
  bool isLoading = false;

  @observable
  bool isShow = false;

  @observable
  String? userName = '';

  @observable
  String? userToken = '';

  @observable
  String? deviceCategory = '';



  // Cart
 //  @observable
 //   ObservableList<CartItem> cartItems = ObservableList<CartItem>();
 //
 //  @computed
 //  int get itemCount => cartItems.length;
 //
 //  @computed
 //  double get totalPrice => cartItems.fold(0.0, (sum, item)=> sum + item.totalPrice);
 //
 // @computed
 //  bool get isCartEmpty => cartItems.isEmpty;

 
 
  @action
  void setDeviceCategory({required String getDeviceCategory}){
    deviceCategory = getDeviceCategory;
  }


  @action
  Future<void> setIsLogin(bool value) async {
    isLoggedIn = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("IS_LOGGED_IN", value);
  }

  @action
  void setToken(String? token) {
    userToken = token;
  }

  @action
  void setLoader(bool value) {
    isLoading = value;
  }




// -----Cart Functionality ----------
//
// @action
//   Future<void> addToCart (Items item)async{
//     final existingItemIndex = cartItems.indexWhere((cartItems)=> cartItems.title == item.name );
//
//     if(existingItemIndex != -1){
//     //   if it exists, just increase its quantity
//       await increse
//     }
// }

// @action
//   Future<void> increaseQuantity(CartItem item) async{
//     item.quantity++;
//     await HiveCart.updateQuantity(item);
// }


}
