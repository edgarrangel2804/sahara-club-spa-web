# AI Booking RPC Contracts

Fecha local: 2026-07-23.

Estos contratos son la fuente operativa para las reservas por IA en
`web_concierge` y `whatsapp-ai-router`.

## `check_availability_for_booking_from_ai`

Firma:

```sql
public.check_availability_for_booking_from_ai(
  p_service_id uuid,
  p_requested_date date,
  p_requested_time time,
  p_duration_min integer default null,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111',
  p_staff_id uuid default null
) returns jsonb
```

Consumidores:

- `supabase/functions/web_concierge/index.ts`
- `supabase/functions/whatsapp-ai-router/index.ts`

Respuesta minima estable:

```json
{
  "available": true,
  "reason": "ok",
  "service_duration_min": 60,
  "selected_staff_id": "uuid opcional",
  "selected_staff_name": "texto opcional",
  "suggested_slots": []
}
```

Errores esperados:

- `service_not_found`
- `staff_not_active`
- `business_closed`
- `outside_business_hours`
- `outside_staff_hours`
- `staff_break`
- `staff_time_off`
- `schedule_block`
- `existing_booking`
- `room_capacity_full`
- `no_staff_available`

## `create_pending_booking_from_ai`

Firma:

```sql
public.create_pending_booking_from_ai(
  p_phone text,
  p_client_name text,
  p_service_id uuid,
  p_booking_date date,
  p_booking_time time,
  p_duration_min integer default null,
  p_notes text default null,
  p_ai_conversation_id uuid default null,
  p_ai_confidence_score numeric default null,
  p_email text default null,
  p_therapist_id uuid default null,
  p_request_id text default null,
  p_branch_id uuid default '11111111-1111-1111-1111-111111111111'
) returns jsonb
```

Respuesta minima estable:

```json
{
  "ok": true,
  "created": true,
  "duplicate_prevented": false,
  "booking_id": "uuid",
  "status": "pending_reception",
  "client_id": "uuid",
  "client_is_new": true,
  "therapist_id": "uuid opcional"
}
```

Reglas:

- Normaliza telefono por digitos y busca clientes por ultimos 10 digitos.
- Crea cliente minimo si no existe.
- Guarda email solo si el cliente no tenia email.
- Revalida disponibilidad dentro de la misma transaccion.
- Usa `p_request_id` para idempotencia fuerte.
- Si `p_request_id` falta, genera hash server-side con telefono, cliente,
  email, servicio, fecha, hora, duracion, conversacion y terapeuta.
- Mantiene status inicial `pending_reception`; los handlers Edge aplican waiver
  o `pending_payment` despues.

Errores esperados:

- `phone_required`
- `missing_service_or_datetime`
- `service_not_found`
- `slot_not_available`

## `check_booking_payment_requirement`

Firma:

```sql
public.check_booking_payment_requirement(
  p_phone text,
  p_service_id uuid default null,
  p_requested_date date default null,
  p_requested_time time default null,
  p_customer_name text default null
) returns jsonb
```

Respuesta minima estable:

```json
{
  "requires_deposit": true,
  "requires_payment": true,
  "reason": "deposit_required",
  "payment_requirement": "deposit_required",
  "gift_card_id": null,
  "membership_id": null,
  "client_package_id": null,
  "client_package_session_id": null,
  "deposit_required_cents": 20000,
  "deposit_amount": 200,
  "currency": "MXN"
}
```

Prioridad de exencion:

1. Paquete activo con sesion pendiente para el servicio, solo si las tablas de
   paquetes existen.
2. Gift card activa, vigente y con saldo al menos igual al anticipo.
3. Membresia activa con sesiones disponibles.
4. Paquete activo con cualquier sesion pendiente, solo si las tablas existen.
5. Anticipo requerido.

Seguridad:

- Las tres RPCs son `SECURITY DEFINER`.
- `search_path` fijo: `public, pg_temp`.
- `EXECUTE` solo para `service_role`.
- Los endpoints publicos no reciben acceso directo a tablas privadas ni RPCs.
