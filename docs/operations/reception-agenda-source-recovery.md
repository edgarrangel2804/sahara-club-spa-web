# Reception And Agenda Source Recovery

Fase 2 recupera fuentes operativas de recepcion, agenda y sincronizacion desde
el respaldo verificado:

`C:\Proyectos\Backups\Sahara-Club-Spa\20260721-200207-pre-regularization`

Fuente canonica: `sha256-manifest.csv` del respaldo. Antes de copiar cada
archivo se verifico que el hash del respaldo coincidiera con el manifest y con
el archivo actual del repositorio original protegido
`C:\Proyectos\sahara-club-spa-web`.

HEAD base de esta fase:
`3269e16c6f3935327e7441d7015029c891682034`.

## Fuentes Recuperadas

| Archivo | Commit base | Hash respaldo | Cambio local | Funcion operativa | Confianza |
|---|---|---|---|---|---|
| `lib/pages/agenda_page.dart` | `3269e16c6f3935327e7441d7015029c891682034` | `8537a08c0029cd884527d0c19407e6eb4af43fd46a87b7707d446f1d2739d8e5` | `M` tracked | Agenda, recepcion, navegacion modular, campana/banner de alertas, estados de cita, cobro, anticipos, WhatsApp y dialogos operativos. | ALTA |
| `lib/features/bookings/booking_sync_service.dart` | `3269e16c6f3935327e7441d7015029c891682034` | `48180e9945a3fd6f6d40d8588dc9305a7b59f93f1f73f5e83c526b1403a5b323` | `M` tracked | Consulta, valida, sincroniza y persiste citas contra Supabase, con disponibilidad, estados, sucursal, terapeuta, cliente y origen. | ALTA |
| `lib/features/reception_alerts/reception_alerts_service.dart` | `3269e16c6f3935327e7441d7015029c891682034` | `4acd8c18669c042fa2b1748ce889bf89e24d84e5e9ef09a5a939c92c8b3aca05` | `M` tracked | Carga inicial, conteo, Realtime, visto y resuelto de alertas internas de recepcion. | ALTA |
| `lib/pages/reception_login_page.dart` | `3269e16c6f3935327e7441d7015029c891682034` | `7276e76f8ca1a748ed08b5b5f978194485fd382b5af697979f79cf1a9c7c7b72` | `M` tracked | Login y puerta de entrada de recepcion/admin/staff hacia la agenda operativa. | ALTA |

## Archivos Revisados Pero No Reemplazados

| Archivo | Resultado | Motivo |
|---|---|---|
| `lib/features/reception_alerts/reception_alert.dart` | No recuperado | No forma parte de los 38 movimientos del respaldo; se conserva la version regularizada actual. |
| `lib/features/reception_alerts/reception_alert_banner.dart` | No recuperado | No forma parte de los 38 movimientos del respaldo; se conserva la version regularizada actual. |
| `lib/features/reception_alerts/reception_alerts_bell.dart` | No recuperado | No forma parte de los 38 movimientos del respaldo; se conserva la version regularizada actual. |

## Clasificacion Inicial Del Cambio

| Archivo | Parece desplegado | Corrige regresion | Complementa alertas | Agrega comprobantes | Cambia navegacion | Afecta citas | Afecta Realtime |
|---|---:|---:|---:|---:|---:|---:|---:|
| `agenda_page.dart` | NO COMPROBABLE | SI | SI | SI | SI | SI | SI |
| `booking_sync_service.dart` | NO COMPROBABLE | SI | NO | NO | NO | SI | SI |
| `reception_alerts_service.dart` | NO COMPROBABLE | SI | SI | NO | NO | SI | SI |
| `reception_login_page.dart` | NO COMPROBABLE | SI | NO | NO | SI | NO | NO |

## Notas

- No se copiaron archivos desde el repo original.
- No se integraron archivos ni commits de Gift Card Alerts.
- No se copiaron los widgets/modelos de alertas que no estaban en el manifest.
- La recuperacion exacta se hizo antes de formatear, refactorizar o regularizar.
