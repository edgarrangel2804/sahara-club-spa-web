import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  createGiftCardSignedUrl,
  ensureGiftCardDigitalAsset,
  giftCardDownloadSigningSecret,
  publicGiftCardPayload,
  recordGiftCardDownload,
  verifyGiftCardDownloadToken,
} from "../_shared/gift_card_fulfillment.ts"
import { corsHeaders, jsonResponse } from "../_shared/stripe_checkout.ts"

function createAdminClient(): any {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST" && req.method !== "GET") {
    return jsonResponse({ ok: false, error: "method_not_allowed" }, 405)
  }

  let token = ""
  try {
    const url = new URL(req.url)
    if (req.method === "GET") {
      token = String(url.searchParams.get("gift_card_token") ?? url.searchParams.get("token") ?? "")
    } else {
      const body = await req.json().catch(() => ({})) as Record<string, unknown>
      token = String(body.gift_card_token ?? body.token ?? "")
    }

    const verified = await verifyGiftCardDownloadToken(token, giftCardDownloadSigningSecret())
    if (!verified.ok) {
      return jsonResponse({ ok: false, error: verified.error }, verified.status)
    }

    const supabase = createAdminClient()
    const { data: card, error } = await supabase
      .from("gift_cards")
      .select("*")
      .eq("id", verified.payload.gift_card_id)
      .maybeSingle()
    if (error) throw error
    if (!card) return jsonResponse({ ok: false, error: "gift_card_not_found" }, 404)

    let signedUrl = ""
    let currentCard = card as Record<string, unknown>
    if (
      currentCard.digital_asset_path &&
      String(currentCard.digital_asset_status ?? "") === "generated"
    ) {
      signedUrl = await createGiftCardSignedUrl(supabase, String(currentCard.digital_asset_path))
    } else {
      const asset = await ensureGiftCardDigitalAsset(supabase, currentCard)
      currentCard = asset.card
      signedUrl = asset.signedUrl
    }

    if (!signedUrl) {
      return jsonResponse({
        ok: false,
        error: "gift_card_asset_pending",
        asset_status: String(currentCard.digital_asset_status ?? "pending"),
      }, 202)
    }

    await recordGiftCardDownload(supabase, {
      giftCardId: verified.payload.gift_card_id,
      token,
    })

    return jsonResponse(publicGiftCardPayload({ card: currentCard, signedUrl }))
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error ?? "")
    console.warn("gift_card_download failed:", message.slice(0, 160))
    return jsonResponse({ ok: false, error: "gift_card_download_unavailable" }, 500)
  }
})
