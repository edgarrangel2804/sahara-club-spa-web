-- SAHARA CLUB SPA - PRODUCTIVE HOTFIX ROLLBACK
-- Disables Gift Card paid purchase -> Reception alert.
--
-- This rollback intentionally does not delete already generated alerts.
-- It also does not narrow reception_alerts_event_type_check back to the prior
-- value set, because doing so can fail after legitimate gift_card_purchased
-- rows exist and would require data deletion or mutation.

begin;

drop trigger if exists trg_gift_card_reception_alert on public.gift_cards;

drop function if exists public.notify_reception_on_gift_card_created();

drop index if exists public.idx_reception_alerts_gift_card_purchased_once;

commit;
