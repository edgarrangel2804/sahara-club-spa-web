# Clients Receipts Source Recovery

Scope: Fase 3 preservation step. Source copied only from:

`C:\Proyectos\Backups\Sahara-Club-Spa\20260721-200207-pre-regularization`

Initial regularization HEAD:

`95afa1caa19a16d6d0387d6bbd570268a9d46bcf`

## Recovered Files

| Archivo | Estado original | Hash respaldo | Funcion | Dependencias | Confianza |
|---|---|---|---|---|---|
| `lib/features/clients/clients_module.dart` | `M` in original protected repo | `d09fb43b3113bfbb1aedebbf6fd25693017a8655e2ea618a6ebbd03b643e0449` | Client list, profile, booking history, packages, memberships, Gift Cards, notes, and client actions. | Supabase `clients`, `bookings`, package/membership/Gift Card tables, sales/payment data. | ALTA |
| `lib/features/receipts/deposit_receipt_actions.dart` | `??` in original protected repo | `2a64ff1f945900541979c31782623b627925562e94717dcb8fe4bf9fd1101a35` | Flutter dialog to open a deposit receipt PDF from the private `receipts` storage bucket via signed URL. | Supabase Storage, `url_launcher`, booking id as PDF object key. | MEDIA |
| `web/comprobante-anticipo.html` | `??` in original protected repo | `62668e67d6ccad6abbb64d3512ebe13ed28b2702d714805ee8026043e86d04a0` | Public voucher page that calls `deposit_voucher` and renders payment/booking data. | Hardcoded Supabase URL/anon key, Edge Function `deposit_voucher`, query params `session_id` or `booking_id`. | MEDIA |

## Initial Classification

| Archivo | Parece desplegado | Depende de Edge Functions recuperadas | Depende de acceso anon | Expone PII | URLs/claves hardcodeadas | Se puede versionar sin cambios | Requiere sanitizacion |
|---|---|---:|---:|---:|---:|---:|---:|
| `clients_module.dart` | Probable | No directo | No | Si: nombre, telefono, email, historial | No evidente | Si, como fuente recuperada | Si, en permisos/PII/logs antes de reutilizar |
| `deposit_receipt_actions.dart` | Probable | No directo; usa Storage | No | Bajo: folio derivado de booking id visible | No | Si, como fuente recuperada | Si, antes de reconectar Agenda |
| `web/comprobante-anticipo.html` | Probable | Si: `deposit_voucher` | Si | Si: cliente, servicio, fecha/hora, monto | Si: Supabase URL y anon key | No como version segura final | Si, obligatorio |

## Notes

- The backup hash matched the manifest and the original protected repo for all three files.
- The copy operation used only the backup path, not the original repo.
- `web/comprobante-anticipo.html` contains a public anon key. That is not automatically a service-role leak, but the real risk is the public query contract, RLS/Edge authorization, identifier enumeration, and unsanitized rendering.
- `deposit_receipt_actions.dart` opens a signed Storage URL valid for seven days and does not explicitly validate URL scheme/host or payment status.
- `clients_module.dart` is productive but monolithic; it should not be copied into NEXORA directly.
