alter table whatsapp_templates add column if not exists type text check (type in ('confirmation', 'reminder_24h', 'reminder_2h', 'custom')) default 'custom';

create table if not exists whatsapp_logs (
  id uuid default gen_random_uuid() primary key,
  booking_id uuid references bookings(id) on delete cascade,
  type text,
  status text default 'sent',
  sent_at timestamp with time zone default now()
);
