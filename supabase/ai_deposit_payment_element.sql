-- Sahara Club Spa - Configuración para modo Payment Element embebido
-- ----------------------------------------------------------------------------
-- Cambia el flujo de Stripe Checkout (redirect externo) a Payment Element
-- (embebido en saharaclubspa.com/pagar-anticipo/{booking_id}).

-- 1. ai_settings: configurabilidad del anticipo
alter table public.ai_settings
  add column if not exists appointment_deposit_amount numeric not null default 200,
  add column if not exists appointment_deposit_currency text not null default 'mxn',
  add column if not exists appointment_deposit_enabled boolean not null default true;

-- 2. stripe_settings: modo de experiencia de pago
alter table public.stripe_settings
  add column if not exists payment_experience_mode text not null default 'payment_element';

alter table public.stripe_settings
  drop constraint if exists stripe_settings_payment_experience_mode_check;
alter table public.stripe_settings
  add constraint stripe_settings_payment_experience_mode_check
  check (payment_experience_mode in ('checkout','payment_element','payment_sheet'));

-- 3. RPC público para que la página HTML obtenga la info del booking sin
--    necesitar autenticación. SOLO devuelve datos no-sensibles.
create or replace function public.get_booking_for_deposit_payment(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_booking record;
  v_service text;
  v_client_name text;
begin
  select b.id, b.status, b.booking_date, b.booking_time,
         b.deposit_amount, b.payment_status, b.stripe_payment_intent_id,
         b.service_id, b.client_record_id
  into v_booking
  from public.bookings b
  where b.id = p_booking_id
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'booking_not_found');
  end if;

  if v_booking.status not in ('pending_payment','payment_received','confirmed') then
    return jsonb_build_object('ok', false, 'error', 'booking_not_payable',
                              'status', v_booking.status::text);
  end if;

  select s.name into v_service from public.services s where s.id = v_booking.service_id;
  select c.full_name into v_client_name from public.clients c where c.id = v_booking.client_record_id;

  return jsonb_build_object(
    'ok', true,
    'booking_id', v_booking.id,
    'status', v_booking.status::text,
    'payment_status', coalesce(v_booking.payment_status, 'pending'),
    'service_name', coalesce(v_service, 'Servicio Sahara'),
    'client_name', coalesce(v_client_name, 'Cliente'),
    'booking_date', v_booking.booking_date::text,
    'booking_time', v_booking.booking_time::text,
    'amount', coalesce(v_booking.deposit_amount, 200),
    'currency', 'mxn'
  );
end;
$$;

-- El RPC se llama desde la HTML page (anon key del navegador).
grant execute on function public.get_booking_for_deposit_payment(uuid) to anon;
grant execute on function public.get_booking_for_deposit_payment(uuid) to authenticated;

-- 4. Verificación
select
  (select payment_experience_mode from public.stripe_settings where is_active=true) as mode,
  (select appointment_deposit_amount from public.ai_settings where id=1) as amount,
  (select appointment_deposit_currency from public.ai_settings where id=1) as currency;
