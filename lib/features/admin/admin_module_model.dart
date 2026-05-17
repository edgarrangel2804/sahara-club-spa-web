class _Staff {
  final String id;
  final String name;
  final String role;
  final bool active;
  final String? photoUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? city;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<String> workDays;
  final String? workStartTime;
  final String? workEndTime;
  final String? breakTime;
  final bool showInCalendar;
  final double? fixedSalary;
  final double? commissionPercentage;
  final String? paymentNotes;
  final bool canAccessMobile;
  final bool canAccessWeb;
  final String? accessEmail;

  _Staff({
    required this.id,
    required this.name,
    required this.role,
    this.active = true,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.city,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.workDays = const [],
    this.workStartTime,
    this.workEndTime,
    this.breakTime,
    this.showInCalendar = false,
    this.fixedSalary,
    this.commissionPercentage,
    this.paymentNotes,
    this.canAccessMobile = false,
    this.canAccessWeb = false,
    this.accessEmail,
  });

  factory _Staff.fromMap(Map<String, dynamic> m) {
    List<String> parseDays(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    }

    return _Staff(
      id: m['id'] ?? '',
      name: m['name'] ?? '',
      role: m['role'] ?? 'other',
      active: m['active'] ?? true,
      photoUrl: m['photo_url'],
      phone: m['phone'],
      whatsapp: m['whatsapp'],
      email: m['email'],
      address: m['address'],
      city: m['city'],
      emergencyContactName: m['emergency_contact_name'],
      emergencyContactPhone: m['emergency_contact_phone'],
      workDays: parseDays(m['work_days']),
      workStartTime: m['work_start_time'],
      workEndTime: m['work_end_time'],
      breakTime: m['break_time'],
      showInCalendar: m['show_in_calendar'] ?? false,
      fixedSalary: (m['fixed_salary'] as num?)?.toDouble(),
      commissionPercentage: (m['commission_percentage'] as num?)?.toDouble(),
      paymentNotes: m['payment_notes'],
      canAccessMobile: m['can_access_mobile'] ?? false,
      canAccessWeb: m['can_access_web'] ?? false,
      accessEmail: m['access_email'],
    );
  }
}
