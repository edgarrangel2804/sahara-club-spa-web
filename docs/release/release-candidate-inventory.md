# Release Candidate Inventory

Fecha local: 2026-07-23.

Worktree: `C:\Proyectos\sahara-club-spa-web-regularization`
Rama: `chore/regularize-production-baseline`
HEAD base antes de recuperar RPCs: `04970fb85ec424b00d789f4281ba761067364e6c`
Base: `f38833922e7a8dac300c0b57067c9654c38e7b99`

## Veredicto de inventario

Estado: `CERTIFICACION INTEGRAL BLOQUEADA POR TIMEOUT LOCAL DE SUPABASE CLI/STORAGE`.

La rama compila, pasa tests Flutter/Deno, aplica todas las migraciones locales y deja operativas las RPCs que los handlers de reserva web/WhatsApp invocan. Sin embargo, `supabase db reset` no puede declararse PASS formal porque la CLI termina con exit 1 durante el healthcheck final de Storage, despues de aplicar migraciones y reiniciar contenedores. Storage queda `healthy` posteriormente y las pruebas SQL pasan contra esa base reconstruida, pero el comando de reconstruccion reproducible sigue sin cerrar en verde.

- `check_availability_for_booking_from_ai`
- `create_pending_booking_from_ai`
- `check_booking_payment_requirement`

El grafo de codigo las ubicaba en SQL suelto versionado fuera de `supabase/migrations`:

- `supabase/staff_availability.sql`
- `supabase/ai_availability_check.sql`
- `supabase/ai_pending_booking_flow.sql`
- `supabase/ai_booking_payment_waiver.sql`
- `supabase/packages_anticipo_waiver.sql`

La recuperacion quedo regularizada en `supabase/migrations/20260722040000_ai_booking_rpcs.sql`, con contratos documentados en `docs/operations/ai-booking-rpc-contracts.md` y pruebas en `supabase/tests/ai_booking_rpcs.sql`.

## Dominios

| Dominio | Commits | Archivos | Capacidad | Riesgo | Estado |
|---|---|---|---|---|---|
| Baseline y migraciones | `a0ab6ef`, `20260721*`, `20260722*` | `supabase/migrations/*` | Reconstruye ecommerce, alertas, Gift Cards, hardening y RPCs de reserva/IA. | MEDIO: pendiente aplicar/verificar remoto. | CERTIFICADO LOCAL |
| Seguridad | `602d993`, `71592dd`, `cc83448`, `427bcf6`, `f1f4622`, `f3f084f`, `8d42867` | `docs/security/*`, `runtime_security.ts`, migrations hardening, tests | RLS, grants, buckets privados, endpoint auth/rate limits. | MEDIO: pendiente verificacion remota/productiva. | CERTIFICADO LOCAL |
| Edge Functions | `fbd88e7`, `d1f45e7`, `d1e9367`, `d9dabae`, `f1f4622` | `supabase/functions/*` | Handlers recuperados, idempotencia RPC y check/lint/test Deno OK. | MEDIO: no se probo Anthropic/Meta/Stripe real. | CERTIFICADO LOCAL |
| Agenda y Recepcion | `284370b`, `38da37f`, `770f5ae`, `95afa1c`, `c19b9fa`, `b064248` | `agenda_page.dart`, `reception_alerts/*`, migrations alertas | Agenda, alertas, Gift Card alerts, Realtime y soporte SQL de disponibilidad AI. | MEDIO: pendiente verificacion remota. | CERTIFICADO LOCAL |
| Clientes | `5d170c5`, `88c746a`, `91e5db1` | `clients_module.dart`, `client_identity_helpers.dart`, tests | Clientes operativos e identidad normalizada. | BAJO: modulo monolitico legacy. | CERTIFICADO |
| Stripe y anticipos | `e642d7f`, `9f5a73e`, `e82ad78`, hardening | `create_booking_deposit_checkout`, `deposit_voucher`, `deposit_receipts.ts` | Checkout y comprobantes con tokens firmados. | MEDIO: no se ejecuto Stripe real ni sandbox externo. | CERTIFICACION PENDIENTE |
| Comprobantes | `e3a5ded`, `d1c669e`, `e642d7f`, `9f5a73e`, `e82ad78` | `deposit_receipt_actions.dart`, `web/comprobante-anticipo.html`, tests | Voucher publico limitado, URL firmada, Storage privado. | BAJO. | CERTIFICADO |
| Gift Cards | `0e120eb`, `39a772b`, `077b60a`, `b685078`, `d1e9367`, `a8a0717`, `6c9afe9` | Gift Card form, fulfillment, download token, migrations, tests | Fulfillment digital, vigencia 3 meses, PDF privado, descarga firmada. | MEDIO: funciones nuevas no estan desplegadas en remoto. | CERTIFICACION PENDIENTE |
| WhatsApp | Runtime commits y Gift Card alerts | `whatsapp-ai-router`, `whatsapp_business.ts`, admin notifications | Router, ledger, notificaciones admin y argumentos RPC idempotentes. | MEDIO: no hay Meta real. | CERTIFICADO LOCAL |
| Landing | `d748d58`, `d0b9ed5`, `01520c3`, `79e9509`, `d132e36` | `landing_page.dart`, widgets, assets, test web | Hero multimedia, experiencia, Store, concierge. | BAJO. | CERTIFICADO |
| Concierge | `01520c3`, runtime hardening | `concierge_chat.dart`, `web_concierge` | Chat publico ligero con backend endurecido y `p_request_id` para reservas. | MEDIO: no hay LLM real en smoke. | CERTIFICADO LOCAL |
| Panel IA | `b21ca46` | `ai_control_panel.dart` | Modos Apagado/Piloto/Publico sin secretos cliente. | BAJO: RLS efectiva depende del backend. | CERTIFICADO |
| Assets | `d0b9ed5`, `01520c3`, `79e9509` | `Portada-2.mp4`, `assets/experiencia/*`, `pubspec.yaml` | Assets declarados y presentes en build. | BAJO: build web grande por video. | CERTIFICADO |
| Tests | multiples commits `test(*)` | `test/*`, Deno tests, SQL tests | 46 Flutter, 31 Deno, SQL boundary PASS y AI booking RPC PASS con 24 aserciones de comportamiento/grants. | MEDIO: `supabase db reset` aun falla en healthcheck local de Storage. | CERTIFICADO LOCAL CON BLOQUEO CLI |
| Blueprint | docs commits | `docs/blueprints/spa-wellness/*` | Clasificacion de capacidades y legacy. | BAJO. | DOCUMENTACION |

## Validaciones ejecutadas

| Area | Comando | Resultado |
|---|---|---|
| Git | `git diff --check` | PASS |
| Flutter clean | `flutter clean` | PASS |
| Flutter deps | `flutter pub get` | PASS |
| Flutter format | `dart format --output=none --set-exit-if-changed .` | FAIL: 53 archivos historicos requeririan formato |
| Flutter analyze | `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS, 146 issues historicos |
| Flutter tests | `flutter test --no-pub -r expanded` | PASS, 46/46 |
| Flutter build | `flutter build web --release` | PASS, `build/web` aprox. 115.91 MB |
| Deno version | `deno 2.9.3` | Registrado |
| Deno fmt | `deno task edge:fmt` | PASS, 26 archivos |
| Deno lint | `deno task edge:lint` | PASS, 25 archivos |
| Deno check | `deno task edge:check` | PASS |
| Deno tests | `deno task edge:test` | PASS, 31/31 |
| Supabase start/status | `supabase stop/start/status` | PASS; DB, Storage, Auth, Realtime y APIs locales operativas; pooler/imgproxy detenidos como servicios no usados |
| Supabase reset | `supabase db reset` | FAIL formal: aplica todas las migraciones, pero termina con timeout en `GET /storage/v1/bucket`; Storage queda `healthy` despues |
| SQL/RLS | `supabase/tests/security_boundaries.sql` | PASS |
| SQL/RPCs reserva IA | `supabase/tests/ai_booking_rpcs.sql` | PASS, 18 aserciones de comportamiento + 6 de grants |
| RPC catalogo | `pg_proc`/`has_function_privilege` | 3 RPCs presentes, `SECURITY DEFINER`, `service_role` only |
| Edge smoke | `supabase functions serve --env-file .audit/edge-runtime.local.env --no-verify-jwt` | PASS: 10+ funciones criticas responden OPTIONS=200; `web_concierge GET=405`, `whatsapp-ai-router` validacion temprana=400; proceso detenido |
| Supabase vector | `docker logs/inspect` + busqueda de codigo | NO BLOQUEANTE FUNCIONAL: reinicia por error local del colector de logs contra Docker; sin uso de embeddings/pgvector en codigo |
| Vercel read-only | `node_modules/.bin/vercel.cmd whoami` | Auth local OK; deployment/proyecto activo NO COMPROBABLE porque no hay `.vercel` link local y no se hizo deploy |

## Auditoria Git y secretos

| Busqueda | Resultado | Clasificacion |
|---|---|---|
| Stripe live/webhook reales en rango | 0 secretos reales; un falso positivo en test helper actual | FALSO POSITIVO |
| Service role asignado en rango | 0 | LIMPIO |
| JWT completos | 0 en rango; falso positivo heredado en `node_modules` | FALSO POSITIVO / DEUDA HISTORICA |
| Password assignments | 0 | LIMPIO |
| URLs con credenciales | 0 en rango; falsos positivos heredados en tipos de Node | FALSO POSITIVO / DEUDA HISTORICA |
| `.env` versionados | 0 | LIMPIO |
| `.audit` versionado | 0 | LIMPIO |
| Dumps | `supabase_schema_dump.sql` existe historico pero esta vacio | DEUDA HISTORICA BAJA |
| `node_modules` versionado | 7132 archivos heredados, no agregados por el RC | DEUDA HISTORICA MEDIA |
| Correos/telefonos | Solo archivos con copy publica/test placeholders; sin evidencia de clientes reales | LIMPIO CON REVISION MANUAL |

## Commits del RC

Rango previo de certificacion: 43 commits desde `f38833922e7a8dac300c0b57067c9654c38e7b99` hasta `d132e36c1daca65b9e12fd017b4175b7473e1492`. La recuperacion de RPCs agrega commits nuevos sobre `04970fb85ec424b00d789f4281ba761067364e6c`; el cierre actual parte de `867661fa53c985276d2b001dfd43d17d4ed2fe2a` y agrega la correccion de duracion server-side en reserva IA, pruebas SQL ampliadas y esta documentacion.

Los commits tienen proposito identificable por dominio y mensajes consistentes con contenido. No se detectaron secretos productivos, dumps nuevos, backups nuevos, builds versionados ni binarios accidentales fuera de los assets requeridos.
