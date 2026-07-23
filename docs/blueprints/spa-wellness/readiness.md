# Spa Wellness Readiness

Fecha local: 2026-07-23.

Estado global: `PRODUCTIVO PENDIENTE DE DESPLIEGUE`, con RPCs de reserva/IA funcionales localmente, pero certificacion integral bloqueada porque `supabase db reset` termina con exit 1 por timeout local de Storage.

## Universal NEXORA

| Modulo | Madurez | Evidencia | Nota |
|---|---|---|---|
| Seguridad y RLS | PRODUCTIVO PENDIENTE DE DESPLIEGUE | SQL boundary PASS, RLS/policies/buckets locales, grants RPC `service_role` only | Falta verificacion remota/productiva. |
| Eventos/alertas internas | PRODUCTIVO PENDIENTE DE DESPLIEGUE | `reception_alerts`, Realtime, Gift Card alerts | Modelo reusable como foundation. |
| Documentos firmados | PRODUCTIVO CERTIFICADO | Voucher/Gift Card tokens, Storage privado, tests | Buen patron para documentos privados. |
| Pagos/checkout | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Helpers y handlers compilan; pricing server-side | Falta prueba sandbox supervisada. |
| Notificaciones | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Admin notification tests, delivery ledger | Meta real no usado. |
| Edge runtime | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Deno fmt/lint/check/test PASS; smoke serve PASS | Reserva web/WhatsApp ya cuenta con RPCs locales probadas; reset CLI aun bloquea cierre formal. |
| Auditoria/idempotencia | FOUNDATION | Tests helper, indices, docs, SQL replay de reserva IA | Necesita pruebas E2E remotas/sandbox. |
| Repo hygiene | DEUDA LEGACY | `node_modules` versionado historico; formato Dart global falla | No agregado por regularizacion. |

## Spa & Wellness

| Modulo | Madurez | Evidencia | Nota |
|---|---|---|---|
| Terapeutas | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Staff availability y RPC de disponibilidad migradas localmente | Pendiente aplicar/verificar remoto. |
| Cabinas | PARCIAL | Campos/validaciones en agenda | Modelo aun acoplado. |
| Tratamientos/servicios | PRODUCTIVO PENDIENTE DE DESPLIEGUE | `services` existe; Store/booking usan servicios | Tabla `products` no existe local; catalogo local usa servicios/modelos. |
| Paquetes | PARCIAL | SQL historico y Gift Card support parcial | Requiere fase dedicada. |
| Gift Cards | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Fulfillment, PDF, tokens, alertas, canje | Nuevas funciones aun no estan remoto. |
| Anticipos | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Voucher firmado, receipt actions, checkout handler | Falta prueba sandbox supervisada. |
| Canje | PRODUCTIVO CERTIFICADO LOCAL | `redeem_service_gift_card` local + tests helper | Certificado local, pendiente despliegue. |
| Recepcion | PRODUCTIVO PENDIENTE DE DESPLIEGUE | Alertas, detalles, reenvios, SQL local, RLS/grants locales | Remoto pendiente. |
| Experiencia publica | PRODUCTIVO CERTIFICADO | Landing tests/build/assets | Apta localmente. |
| Concierge/reserva IA | CERTIFICADO LOCAL CON BLOQUEO CLI | `web_concierge`, `whatsapp-ai-router`, SQL RPC tests ampliados y smoke Edge | Pendiente reset CLI exit 0 y LLM/Meta/Stripe real supervisado. |

## Decision de madurez

La rama no debe considerarse NEXORA-ready ni release final hasta resolver:

1. `supabase db reset` con exit 0 en entorno local o CI equivalente.
2. Verificacion remota de migraciones/policies/buckets, incluyendo RPCs de reserva/IA.
3. Metadata Vercel valida de proyecto, alias/deployment activo y SHA.
4. Formato Dart global o excepcion aceptada formalmente.
5. Pruebas supervisadas de Stripe/Meta/WhatsApp antes de activar trafico real.
