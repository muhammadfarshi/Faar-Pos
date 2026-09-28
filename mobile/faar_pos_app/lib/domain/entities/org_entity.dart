class OrgEntity {
  final int id;
  final String name;
  final String slug;
  final String currencyCode;
  final String currencySymbol;
  final String timezone;
  final String? logoUrl;
  final String subscriptionPlan;

  const OrgEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.currencyCode,
    required this.currencySymbol,
    required this.timezone,
    this.logoUrl,
    required this.subscriptionPlan,
  });

  factory OrgEntity.fromJson(Map<String, dynamic> json) {
    return OrgEntity(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      currencyCode: json['currency_code'] as String? ?? 'USD',
      currencySymbol: json['currency_symbol'] as String? ?? '\$',
      timezone: json['timezone'] as String? ?? 'UTC',
      logoUrl: json['logo_url'] as String?,
      subscriptionPlan: json['subscription_plan'] as String? ?? 'starter',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'slug': slug,
    'currency_code': currencyCode, 'currency_symbol': currencySymbol,
    'timezone': timezone, 'logo_url': logoUrl,
    'subscription_plan': subscriptionPlan,
  };
}
