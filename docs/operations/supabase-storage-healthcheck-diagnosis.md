# Supabase Storage Healthcheck Diagnosis

Fecha local: 2026-07-22 22:38 America/Tijuana.

Worktree: `C:\Proyectos\sahara-club-spa-web-regularization`
Rama: `chore/regularize-production-baseline`
HEAD inicial: `556ff03a3e9ab823da89a6654295e29893e2cb8a`

## Veredicto

Estado Storage: `STORAGE LOCAL CERTIFICADO`.

Estado Release Candidate: `RELEASE CANDIDATE CERTIFICADO`.

La causa raiz del bloqueo formal era local: despues de algunos `supabase db reset` ejecutados sobre un stack ya vivo o sobre resets por cortes, Storage quedaba sano pero Kong conservaba un upstream hacia un IP anterior del contenedor Storage. La CLI 2.95.4 validaba `GET /storage/v1/bucket` a traves de Kong y recibia cancelacion/timeout porque Kong intentaba enrutar al IP viejo.

No hubo evidencia de fallo de Storage, migraciones Sahara, RLS, grants, buckets, PostgreSQL, Auth, REST, schema `storage` o datos.

La correccion aplicada fue operacional y no versionada en codigo: ejecutar ciclos limpios con `supabase stop`, `supabase start` y despues `supabase db reset`. Ese procedimiento regenera el stack local y mantiene alineado el upstream de Kong durante el reset. No se actualizo la CLI global, no se cambio `config.toml`, no se desactivo Storage y no se tocaron migraciones.

## Versiones

| Componente | Version |
|---|---|
| Windows | Windows 11 Pro 10.0.26200, x64 |
| Docker Desktop | 4.82.0 |
| Docker Engine | 29.6.1 |
| Docker backend | WSL2, linux/amd64 |
| Docker CPUs | 6 |
| Docker memoria | 8257130496 bytes |
| Docker context | `desktop-linux` |
| Docker Compose | v5.3.0 |
| Supabase CLI | 2.95.4 |
| Storage image | `public.ecr.aws/supabase/storage-api:v1.54.1` |
| Kong image | `public.ecr.aws/supabase/kong:2.8.1` |
| Postgres image | `public.ecr.aws/supabase/postgres:17.6.1.106` |
| Project ID local | `sahara-club-spa` |

## Reproduccion

Intento inicial limpio:

| Comando | Exit | Duracion |
|---|---:|---:|
| `supabase stop` | 0 | 12843 ms |
| `supabase start --debug` | 0 | 37130 ms |
| `supabase db reset --debug` | 0 | 33414 ms |

Luego se aislaron migraciones por cortes con el stack vivo:

| Escenario | Version | Exit | Duracion | Storage |
|---|---:|---:|---:|---|
| Base ecommerce | `20260721000000` | 1 | 42181 ms | running/healthy |
| Hardening Storage | `20260722030200` | 1 | 44245 ms | running/healthy |
| Full | all | 1 | 43397 ms | running/healthy |

Esto descarta una migracion Sahara especifica: el fallo aparece incluso con la primera migracion, y Storage queda healthy.

## Contenedor Storage

| Campo | Valor |
|---|---|
| Nombre | `supabase_storage_sahara-club-spa` |
| Imagen | `public.ecr.aws/supabase/storage-api:v1.54.1` |
| Entrypoint | `docker-entrypoint.sh` |
| Command | `node dist/start/server.js` |
| Restart policy | `unless-stopped` |
| Healthcheck real | `CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:5000/status` |
| Intervalo | 10s |
| Timeout | 2s |
| Retries | 3 |
| Estado final | running/healthy |
| RestartCount final | 0 durante ciclos certificados |

El healthcheck manual dentro del contenedor paso con exit 0 en 151-171 ms.

## Logs y causa raiz

Storage registro arranque correcto:

- `Server listening at http://127.0.0.1:5000`
- `Server listening at http://<container-ip>:5000`
- `[Server] Started Successfully`

En el intento exitoso, Kong registro:

- `GET /storage/v1/bucket` con status 200 para `SupabaseCLI/2.95.4`.

En los intentos fallidos por cortes, Kong registro:

- `GET /storage/v1/bucket` con status 502 o 499.
- `connect() failed (113: Host is unreachable)` hacia el upstream de Storage.
- `connect() failed (111: Connection refused)` hacia el mismo upstream.

El upstream observado apuntaba al IP anterior de Storage. Despues de reinicios parciales del stack, Storage podia quedar con otro IP, mientras Kong retenia el upstream viejo. Por eso la CLI fallaba aunque Storage estuviera healthy y su endpoint interno funcionara.

Clasificacion: `BLOQUEO LOCAL DE KONG/CLI POR UPSTREAM OBSOLETO`, no falla de Storage ni migracion.

## Dependencias

| Servicio | Estado | Health | Impacto |
|---|---|---|---|
| PostgreSQL | running | healthy | OK |
| Kong | running | healthy | Gateway retuvo upstream viejo en escenarios fallidos |
| Auth | running | healthy | OK; warnings/deprecations no bloqueantes |
| REST | running | sin healthcheck Docker | OK |
| Storage | running | healthy | OK |
| Realtime | running | healthy | OK; warnings de metricas no bloqueantes |
| Analytics | running | healthy | OK; deuda local de logging |

DNS interno desde Storage resolvio `supabase_db_sahara-club-spa` y `supabase_kong_sahara-club-spa`.

## Schema Storage

| Objeto Storage | Esperado | Encontrado | Diferencia | Impacto |
|---|---|---|---|---|
| Schema `storage` | owner de plataforma | owner `supabase_admin` | Ninguna bloqueante | OK |
| Tablas internas | presentes | 10 tablas presentes | Ninguna | OK |
| Owner tablas | `supabase_storage_admin` | `supabase_storage_admin` | Ninguna | OK |
| RLS tablas | activo | activo | Ninguna | OK |
| Policies Sahara | service role only | `gift_card_assets_service_role_all`, `receipts_service_role_all` | Ninguna | OK |
| Bucket `gift-card-assets` | privado PDF | privado, PDF, 10 MB | Ninguna | OK |
| Bucket `receipts` | privado PDF | privado, PDF, 10 MB | Ninguna | OK |

Las migraciones Sahara no cambiaron owners internos, no eliminaron tablas, no alteraron columnas internas, no rompieron grants de plataforma y no abrieron acceso anon.

## Red y puertos

Red local: `supabase_network_sahara-club-spa`.

Storage, Kong, DB, Auth, REST, Realtime, Studio, Analytics, Edge Runtime e Inbucket estan en la misma red. Puertos publicados reales observados en Windows: 54321, 54322, 54323, 54324 y 54327. No se detecto un segundo stack Sahara con nombres/puertos duplicados.

`supabase_vector_sahara-club-spa` sigue reiniciando por acceso del colector de logs Docker, pero no participa en Storage y no hay dependencia de pgvector/embeddings en el codigo.

## Certificacion Storage funcional

Prueba local con bucket privado `receipts`, archivo PDF ficticio y service role local sin imprimir keys:

| Paso | Resultado |
|---|---|
| Listado no autorizado de buckets | 400, bloqueado |
| Upload autorizado PDF | 200 |
| Objeto persistido en `storage.objects` | 1 |
| Acceso publico directo | 400, bloqueado |
| Signed URL | 200 |
| GET por signed URL | 200 |
| Delete autorizado | 200 |
| Objeto despues de delete | 0 |
| Residuos `storage-healthcheck/*` | 0 |

## Tres ciclos certificados

Procedimiento usado en cada ciclo:

1. `supabase stop`
2. `supabase start`
3. `supabase db reset --debug`

| Ciclo | Stop | Start | Reset | Reset ms | Storage IP antes | Storage IP despues | Storage |
|---:|---:|---:|---:|---:|---|---|---|
| 1 | 0 | 0 | 0 | 34437 | 172.18.0.10 | 172.18.0.10 | healthy |
| 2 | 0 | 0 | 0 | 34319 | 172.18.0.10 | 172.18.0.10 | healthy |
| 3 | 0 | 0 | 0 | 34038 | 172.18.0.10 | 172.18.0.10 | healthy |

## Regresion posterior

| Area | Resultado |
|---|---|
| `supabase/tests/security_boundaries.sql` | PASS |
| `supabase/tests/ai_booking_rpcs.sql` | PASS, 18 aserciones funcionales + 6 grants |
| Deno fmt | PASS |
| Deno lint | PASS |
| Deno check | PASS |
| Deno tests | PASS, 31/31 |
| Flutter analyze | PASS con 146 incidencias historicas no fatales |
| Flutter tests | PASS, 46/46 |
| Flutter Web build | PASS |
| Edge Runtime smoke | PASS, funciones criticas cargan y no quedan procesos vivos |

## Riesgos residuales

| Riesgo | Clasificacion | Bloquea RC | Nota |
|---|---|---|---|
| Ejecutar `supabase db reset` repetidamente sobre stack vivo despues de cambios de IP | DEUDA LOCAL | No, si se usa ciclo limpio | Puede volver a mostrar upstream obsoleto en Kong |
| Supabase CLI 2.95.4 avisa version nueva | BAJO | No | No se actualizo globalmente porque la certificacion paso con la version actual |
| `supabase_vector` reinicia por colector Docker | DEUDA LOCAL | No | No hay dependencia productiva actual de pgvector/embeddings |
| Verificacion remota Supabase/Vercel | MEDIO | No bloquea RC local; bloquea despliegue | No se hizo deploy ni remote writes |
| Stripe/Meta/WhatsApp reales | MEDIO | No bloquea RC local; bloquea activacion real | Requiere pruebas sandbox/supervisadas |

## Requisito operativo

Para repetir certificacion local antes de release:

```powershell
supabase stop
supabase start
supabase db reset
```

No usar `supabase db reset` como unica accion despues de resets parciales o recreaciones de contenedores que puedan cambiar el IP de Storage sin regenerar Kong.

## Cierre

- No se usaron secretos productivos.
- No se tocaron datos productivos.
- No se modifico Supabase remoto.
- No se hizo deploy.
- No se desactivo Storage.
- No se modifico `config.toml`.
- No se borraron volumenes, redes ni contenedores globalmente.
- No se cambio el repo original ni el worktree Gift Card Alerts.
