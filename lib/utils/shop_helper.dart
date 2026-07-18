class ShopHelper {
  static String getDisplayName(String shopId) {
    final clean = shopId.trim().toLowerCase().replaceAll(' ', '');
    if (clean == '1' || clean == 'shop1' || clean == 'dhkinmobiles') {
      return 'Dhkin Mobiles';
    }
    if (clean == '2' || clean == 'shop2' || clean == 'hanthikamobile' || clean == 'handhikamobile') {
      return 'Handhika Mobiles';
    }
    if (shopId.isEmpty) return shopId;
    return shopId.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}
