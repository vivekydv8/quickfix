import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix/core/storage/hive_service.dart';

/// Represents an item in the booking cart.
class CartItem {
  final String id;
  final String title;
  final double price;
  final int quantity;
  final String pricingType;
  final bool isFreeInspection;
  final double visitingCharges;
  final double minPrice;
  final double maxPrice;

  const CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    this.pricingType = 'fixed',
    this.isFreeInspection = false,
    this.visitingCharges = 0.0,
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      title: title,
      price: price,
      quantity: quantity ?? this.quantity,
      pricingType: pricingType,
      isFreeInspection: isFreeInspection,
      visitingCharges: visitingCharges,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'quantity': quantity,
        'pricingType': pricingType,
        'isFreeInspection': isFreeInspection,
        'visitingCharges': visitingCharges,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        pricingType: json['pricingType']?.toString() ?? 'fixed',
        isFreeInspection: json['isFreeInspection'] == true,
        visitingCharges: (json['visitingCharges'] as num?)?.toDouble() ?? 0.0,
        minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0.0,
        maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Controller managing the shopping cart state with Hive local persistence.
class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super(_loadInitialCart());

  static Map<String, CartItem> _loadInitialCart() {
    try {
      final cached = HiveService.getDataCache('user_cart_items');
      if (cached != null && cached is Map) {
        final Map<String, CartItem> items = {};
        cached.forEach((key, value) {
          if (value is Map) {
            items[key.toString()] = CartItem.fromJson(Map<String, dynamic>.from(value));
          }
        });
        return items;
      }
    } catch (_) {}
    return {};
  }

  void _persistCart() {
    try {
      final Map<String, dynamic> serialized = {};
      state.forEach((key, item) {
        serialized[key] = item.toJson();
      });
      HiveService.saveDataCache('user_cart_items', serialized);
    } catch (_) {}
  }

  void addItem(
    String id,
    String title,
    double price, {
    String pricingType = 'fixed',
    bool isFreeInspection = false,
    double visitingCharges = 0.0,
    double minPrice = 0.0,
    double maxPrice = 0.0,
  }) {
    if (state.containsKey(id)) {
      state = {
        ...state,
        id: state[id]!.copyWith(quantity: state[id]!.quantity + 1),
      };
    } else {
      state = {
        ...state,
        id: CartItem(
          id: id,
          title: title,
          price: price,
          quantity: 1,
          pricingType: pricingType,
          isFreeInspection: isFreeInspection,
          visitingCharges: visitingCharges,
          minPrice: minPrice,
          maxPrice: maxPrice,
        ),
      };
    }
    _persistCart();
  }

  void removeItem(String id) {
    if (!state.containsKey(id)) return;

    if (state[id]!.quantity > 1) {
      state = {
        ...state,
        id: state[id]!.copyWith(quantity: state[id]!.quantity - 1),
      };
    } else {
      final newState = Map<String, CartItem>.from(state);
      newState.remove(id);
      state = newState;
    }
    _persistCart();
  }

  void clearCart() {
    state = {};
    _persistCart();
    try {
      HiveService.saveDataCache('cart_shop_id', null);
    } catch (_) {}
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItem>>(
  (ref) {
    return CartNotifier();
  },
);

final cartTotalItemsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.values.fold(0, (sum, item) => sum + item.quantity);
});

/// **Complex Calculations**: Accumulates the total price of all items currently in the cart.
/// 
/// Watches the [cartProvider] and computes the sum by folding over the collection,
/// multiplying each service's base price by its selected quantity.
final cartTotalAmountProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.values.fold(
    0.0,
    (sum, item) => sum + (item.price * item.quantity),
  );
});
