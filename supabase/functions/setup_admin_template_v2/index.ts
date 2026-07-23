// NEUTRALIZADA. Función de uso puntual ya ejecutada (creó la plantilla
// pago_anticipo_recibido_v2 en Meta el 2026-06-26). Devuelve 410 para que no
// quede accesible. Puede eliminarse del proyecto cuando se desee.
Deno.serve(() =>
  new Response(JSON.stringify({ error: "gone", note: "one-shot ya ejecutado" }), {
    status: 410,
    headers: { "Content-Type": "application/json" },
  })
)
