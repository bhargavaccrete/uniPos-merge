class HiveBox {
  // Core data boxes
  static const String category = 'categories';
  static const String items = 'itemBoxs';
  static const String variante = 'variante';
  static const String choice = 'choice';
  static const String extra = 'extra';
  static const String companyBox = 'companyBox';
  static const String staffBox = 'staffBox';
  
  // Order related boxes
  static const String order = 'orderBox';
  static const String cart = 'cart';
  static const String pastOrder = 'pastorderBox';
  
  // Configuration boxes
  static const String tables = 'tablesBox';
  static const String tax = 'TaxBox';
  static const String appState = 'app_state';
  static const String eod = 'eodBox';

  // List of all available boxes
  static const List<String> allBoxes = [
    category,
    items,
    variante,
    choice,
    extra,
    companyBox,
    staffBox,
    order,
    cart,
    pastOrder,
    tables,
    tax,
    appState,
    eod,
  ];
}