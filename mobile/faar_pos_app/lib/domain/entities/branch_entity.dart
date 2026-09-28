class BranchEntity {
  final int id;
  final int orgId;
  final String name;
  final String branchCode;
  final String invoicePrefix;
  final String currencyCode;
  final String currencySymbol;
  final String? taxRegistrationNo;
  final String countryCode;
  final String city;
  final bool isActive;

  const BranchEntity({
    required this.id,
    required this.orgId,
    required this.name,
    required this.branchCode,
    required this.invoicePrefix,
    required this.currencyCode,
    required this.currencySymbol,
    this.taxRegistrationNo,
    required this.countryCode,
    required this.city,
    required this.isActive,
  });

  factory BranchEntity.fromJson(Map<String, dynamic> json) {
    return BranchEntity(
      id: json['id'] as int,
      orgId: json['org_id'] as int,
      name: json['name'] as String,
      branchCode: json['branch_code'] as String,
      invoicePrefix: json['invoice_prefix'] as String? ?? 'INV',
      currencyCode: json['currency_code'] as String? ?? 'USD',
      currencySymbol: json['currency_symbol'] as String? ?? '\$',
      taxRegistrationNo: json['tax_registration_no'] as String?,
      countryCode: json['country_code'] as String? ?? 'US',
      city: json['city'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'name': name,
    'branch_code': branchCode, 'invoice_prefix': invoicePrefix,
    'currency_code': currencyCode, 'currency_symbol': currencySymbol,
    'tax_registration_no': taxRegistrationNo,
    'country_code': countryCode, 'city': city, 'is_active': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
