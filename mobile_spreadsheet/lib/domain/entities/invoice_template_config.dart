class InvoiceTemplateConfig {
  final String businessName;
  final String businessAddress;
  final String phone;
  final String email;
  final String gstNo;
  final String? logoPath;
  final int primaryColorHex;
  final double taxPercentage;
  final String currencySymbol;
  final String termsAndConditions;
  final String footerNote;

  const InvoiceTemplateConfig({
    this.businessName = 'My Business & Traders',
    this.businessAddress = '123 Business Park, Main Market, City',
    this.phone = '+91 98765 43210',
    this.email = 'contact@mybusiness.com',
    this.gstNo = '27ABCDE1234F1Z5',
    this.logoPath,
    this.primaryColorHex = 0xFF2879FF,
    this.taxPercentage = 18.0,
    this.currencySymbol = '₹',
    this.termsAndConditions = '1. Goods once sold will not be taken back.\n2. Subject to local jurisdiction.\n3. E.&O.E.',
    this.footerNote = 'Thank you for doing business with us!',
  });

  InvoiceTemplateConfig copyWith({
    String? businessName,
    String? businessAddress,
    String? phone,
    String? email,
    String? gstNo,
    String? logoPath,
    int? primaryColorHex,
    double? taxPercentage,
    String? currencySymbol,
    String? termsAndConditions,
    String? footerNote,
  }) {
    return InvoiceTemplateConfig(
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstNo: gstNo ?? this.gstNo,
      logoPath: logoPath ?? this.logoPath,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      footerNote: footerNote ?? this.footerNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'businessAddress': businessAddress,
        'phone': phone,
        'email': email,
        'gstNo': gstNo,
        'logoPath': logoPath,
        'primaryColorHex': primaryColorHex,
        'taxPercentage': taxPercentage,
        'currencySymbol': currencySymbol,
        'termsAndConditions': termsAndConditions,
        'footerNote': footerNote,
      };

  factory InvoiceTemplateConfig.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplateConfig(
      businessName: json['businessName'] as String? ?? 'My Business & Traders',
      businessAddress: json['businessAddress'] as String? ?? '123 Business Park, Main Market',
      phone: json['phone'] as String? ?? '+91 98765 43210',
      email: json['email'] as String? ?? 'contact@mybusiness.com',
      gstNo: json['gstNo'] as String? ?? '27ABCDE1234F1Z5',
      logoPath: json['logoPath'] as String?,
      primaryColorHex: json['primaryColorHex'] as int? ?? 0xFF2879FF,
      taxPercentage: (json['taxPercentage'] as num?)?.toDouble() ?? 18.0,
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      termsAndConditions: json['termsAndConditions'] as String? ?? '1. Goods once sold will not be taken back.',
      footerNote: json['footerNote'] as String? ?? 'Thank you for your business!',
    );
  }
}
