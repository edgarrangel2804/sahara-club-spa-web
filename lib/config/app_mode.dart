const bool kEnableMultiBranch = false;

// The current production schema uses UUIDs for branch ids.
// We keep a fixed UUID for the default branch so single-branch mode
// remains stable and future multi-branch support can reuse the same key.
const String kDefaultBranchId = '11111111-1111-1111-1111-111111111111';
const String kDefaultBranchName = 'Sahara Club Spa';
const String kDefaultBranchAddress = '';
const String kDefaultBranchMaps = '';

Map<String, dynamic> defaultBranchMap() => const {
  'id': kDefaultBranchId,
  'nombre': kDefaultBranchName,
  'direccion_completa': kDefaultBranchAddress,
  'link_maps': kDefaultBranchMaps,
  'telefono_contacto': '',
  'whatsapp': '',
  'email': '',
};
