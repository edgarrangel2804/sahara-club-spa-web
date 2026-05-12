import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload = await req.json()
    const { record, old_record } = payload

    // 1. Validar que el estado cambió a 'confirmed'
    if (record.status !== 'confirmed' || old_record?.status === 'confirmed') {
      return new Response(JSON.stringify({ message: 'No action needed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 2. OBTENER CONFIGURACIÓN DINÁMICA DE WHATSAPP
    const { data: config, error: cError } = await supabase
      .from('configuracion_sistema')
      .select('whatsapp_access_token, whatsapp_phone_number_id')
      .limit(1)
      .single()

    if (cError || !config?.whatsapp_access_token || !config?.whatsapp_phone_number_id) {
      console.error('Configuración de WhatsApp incompleta o no encontrada');
      return new Response(JSON.stringify({ error: 'WhatsApp config missing' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200, // No detenemos el flujo, pero no enviamos
      })
    }

    // 3. Obtener datos completos de la reserva
    const { data: booking, error: bError } = await supabase
      .from('bookings')
      .select(`
        id,
        booking_date,
        booking_time,
        client_record:clients(full_name, phone),
        sucursales(nombre, direccion_completa)
      `)
      .eq('id', record.id)
      .single()

    if (bError || !booking) throw new Error('Error fetching booking data')

    const clientName = booking.client_record?.full_name || 'Cliente'
    const clientPhone = (booking.client_record?.phone || '').replace(/\D/g, '')
    const branchAddress = booking.sucursales?.direccion_completa || ''
    
    // 4. Formatear Fecha y Hora
    const dateObj = new Date(booking.booking_date + 'T' + booking.booking_time)
    const formattedDate = dateObj.toLocaleDateString('es-MX', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    })
    const formattedTime = dateObj.toLocaleTimeString('es-MX', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).toUpperCase()

    // 5. Enviar a Meta WhatsApp API (Datos Dinámicos)
    const waResponse = await fetch(
      `https://graph.facebook.com/v17.0/${config.whatsapp_phone_number_id}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.whatsapp_access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: clientPhone.length === 10 ? `52${clientPhone}` : clientPhone,
          type: "template",
          template: {
            name: "confirmacion_cita_sucursal",
            language: { code: "es_MX" },
            components: [
              {
                type: "body",
                parameters: [
                  { type: "text", text: clientName },
                  { type: "text", text: formattedDate },
                  { type: "text", text: formattedTime },
                  { type: "text", text: branchAddress },
                ]
              }
            ]
          }
        })
      }
    )

    const waData = await waResponse.json()

    return new Response(JSON.stringify({ success: true, waData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
