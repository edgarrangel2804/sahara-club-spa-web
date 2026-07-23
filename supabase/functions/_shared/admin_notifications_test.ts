import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts"
import {
  buildGiftCardAdminMessage,
  type GiftCardPurchaseAdminNotice,
  normalizePurchaseChannel,
  notifyGiftCardPurchaseAdmins,
  purchaseChannelLabel,
  resolveAdminRecipients,
  shouldNotifyGiftCardAdmins,
} from "./admin_notifications.ts"

Deno.test("admin notification channels are explicit", () => {
  assertEquals(normalizePurchaseChannel("WEB"), "web")
  assertEquals(normalizePurchaseChannel("whatsapp"), "whatsapp")
  assertEquals(normalizePurchaseChannel("reception"), "reception")
  assertEquals(normalizePurchaseChannel("manual"), "manual")
  assertEquals(normalizePurchaseChannel("admin"), "admin")
  assertEquals(normalizePurchaseChannel("kiosk"), "unknown")

  assertEquals(shouldNotifyGiftCardAdmins("web"), true)
  assertEquals(shouldNotifyGiftCardAdmins("whatsapp"), true)
  assertEquals(shouldNotifyGiftCardAdmins("unknown"), true)
  assertEquals(shouldNotifyGiftCardAdmins("reception"), false)
  assertEquals(shouldNotifyGiftCardAdmins("manual"), false)
  assertEquals(shouldNotifyGiftCardAdmins("admin"), false)

  assertEquals(purchaseChannelLabel("web"), "Pagina web")
  assertEquals(purchaseChannelLabel("whatsapp"), "WhatsApp")
  assertEquals(purchaseChannelLabel("manual"), "Venta manual")
})

Deno.test("admin gift card message includes operational summary without sensitive PII", () => {
  const notice = {
    ...baseNotice(),
    buyerPhone: "+526461519597",
    paymentIntent: "pi_1234567890",
    checkoutSession: "cs_test_1234567890",
    code: "SAHARA-ABCDEFGH",
    dedicationMessage: "Feliz cumple",
    token: "header.payload.signature",
  } as unknown as GiftCardPurchaseAdminNotice
  const message = buildGiftCardAdminMessage(notice)

  assertStringIncludes(message, "Nueva Gift Card pagada en Sahara Club Spa.")
  assertStringIncludes(message, "Comprador: Laura Perez")
  assertStringIncludes(message, "Destinatario: Maria Garcia")
  assertStringIncludes(message, "Experiencia: Masaje Sahara")
  assertStringIncludes(message, "Monto pagado: $1200.50 MXN")
  assertStringIncludes(message, "Vigencia: 2026-07-22 al 2026-10-22")
  assertStringIncludes(message, "Entrega al destinatario: enviada")
  assertStringIncludes(message, "Tarjeta digital: generada")
  assert(!message.includes("+526461519597"))
  assert(!message.includes("6461519597"))
  assert(!message.includes("SAHARA-ABCDEFGH"))
  assert(!message.includes("pi_1234567890"))
  assert(!message.includes("cs_test_1234567890"))
  assert(!message.includes("Feliz cumple"))
  assert(!message.includes("header.payload.signature"))
})

Deno.test("admin recipients normalize, dedupe by last ten digits, and mask destinations", async () => {
  const recipients = await resolveAdminRecipients({
    ai_admin_numbers: [
      "646 151 9597",
      "+52 646 151 9597",
      "001 602 587 7771",
      "+1 602 587 7771",
      "646 151 0000",
      "12345",
    ],
  })

  assertEquals(recipients.length, 3)
  assertEquals(recipients.map((recipient) => recipient.phone), [
    "5216461519597",
    "16025877771",
    "5216461510000",
  ])
  assertEquals(recipients.map((recipient) => recipient.recipientMask), [
    "****9597",
    "****7771",
    "****0000",
  ])
  assert(recipients.every((recipient) => recipient.destinationHash.length === 64))
})

Deno.test("admin notification logs masked failures when Meta config is missing", async () => {
  const supabase = new FakeAdminClient([
    "646 151 9597",
    "001 602 587 7771",
    "646 151 0000",
  ])

  const result = await notifyGiftCardPurchaseAdmins(supabase, [baseNotice()])

  assertEquals(result, { attempted: 3, sent: 0, failed: 3 })
  assertEquals(supabase.whatsappLogs.length, 3)
  assertEquals(supabase.completes.length, 3)
  assertEquals(supabase.rpcClaims.length, 3)
  const serializedLogs = JSON.stringify(supabase.whatsappLogs)
  assert(!serializedLogs.includes("6461519597"))
  assert(!serializedLogs.includes("16025877771"))
  assert(!serializedLogs.includes("6461510000"))
  assertStringIncludes(serializedLogs, "****9597")
  assertStringIncludes(serializedLogs, "missing_meta_config")
})

Deno.test("admin notification skips sent recipients and retries failed recipients", async () => {
  const numbers = ["646 151 9597", "001 602 587 7771"]
  const recipients = await resolveAdminRecipients({ ai_admin_numbers: numbers })
  const supabase = new FakeAdminClient(numbers)
  supabase.seedDelivery({
    giftCardId: baseNotice().giftCardId,
    destinationHash: recipients[0].destinationHash,
    deliveryType: "admin_whatsapp_purchase_alert",
    status: "sent",
  })
  supabase.seedDelivery({
    giftCardId: baseNotice().giftCardId,
    destinationHash: recipients[1].destinationHash,
    deliveryType: "admin_whatsapp_purchase_alert",
    status: "failed",
  })

  const result = await notifyGiftCardPurchaseAdmins(supabase, [baseNotice()])

  assertEquals(result, { attempted: 1, sent: 0, failed: 1 })
  assertEquals(supabase.whatsappLogs.length, 1)
  assertEquals(supabase.completes.length, 1)
  assertEquals(supabase.rpcClaims.map((claim) => claim.claimed), [false, true])
})

Deno.test("admin notification returns skipped for manual/reception/admin channels", async () => {
  const supabase = new FakeAdminClient(["646 151 9597"])

  assertEquals(
    await notifyGiftCardPurchaseAdmins(supabase, [
      { ...baseNotice(), purchaseChannel: "manual" },
      { ...baseNotice(), purchaseChannel: "reception" },
      { ...baseNotice(), purchaseChannel: "admin" },
    ]),
    {
      attempted: 0,
      sent: 0,
      failed: 0,
      skipped: "channel_not_admin_notifiable",
    },
  )
  assertEquals(supabase.rpcClaims.length, 0)
  assertEquals(supabase.whatsappLogs.length, 0)
})

function baseNotice(): GiftCardPurchaseAdminNotice {
  return {
    orderId: "00000000-0000-4000-8000-000000000011",
    orderItemId: "00000000-0000-4000-8000-000000000012",
    giftCardId: "00000000-0000-4000-8000-000000000013",
    buyerName: "Laura Perez",
    recipientName: "Maria Garcia",
    productName: "Masaje Sahara",
    amountPaid: 1200.5,
    currency: "MXN",
    validFrom: "2026-07-22",
    expiresOn: "2026-10-22",
    deliveryStatus: "sent",
    assetStatus: "generated",
    purchaseChannel: "web",
  }
}

type DeliveryStatus = "pending" | "processing" | "sent" | "failed" | "skipped"

type DeliveryRecord = {
  id: string
  giftCardId: string
  destinationHash: string
  deliveryType: string
  status: DeliveryStatus
  attemptCount: number
}

class FakeAdminClient {
  readonly deliveries = new Map<string, DeliveryRecord>()
  readonly whatsappLogs: Record<string, unknown>[] = []
  readonly completes: Record<string, unknown>[] = []
  readonly rpcClaims: Array<{ destinationHash: string; claimed: boolean }> = []

  constructor(private readonly adminNumbers: string[]) {}

  from(table: string) {
    if (table === "ai_settings") {
      return new SingleRowQuery({ ai_admin_numbers: this.adminNumbers })
    }
    if (table === "business_whatsapp_settings") {
      return new SingleRowQuery(null)
    }
    if (table === "whatsapp_logs") {
      return new InsertQuery((row) => {
        this.whatsappLogs.push(row)
        return { id: `log-${this.whatsappLogs.length}` }
      })
    }
    throw new Error(`unexpected table ${table}`)
  }

  async rpc(name: string, args: Record<string, unknown>) {
    if (name === "claim_gift_card_delivery") {
      return { data: this.claim(args), error: null }
    }
    if (name === "complete_gift_card_delivery") {
      this.completes.push(args)
      const row = Array.from(this.deliveries.values()).find((item) =>
        item.id === args.p_delivery_id
      )
      if (row) row.status = String(args.p_status) as DeliveryStatus
      return { data: null, error: null }
    }
    throw new Error(`unexpected rpc ${name}`)
  }

  seedDelivery(input: {
    giftCardId: string
    destinationHash: string
    deliveryType: string
    status: DeliveryStatus
  }) {
    const key = this.deliveryKey(
      input.giftCardId,
      input.destinationHash,
      input.deliveryType,
    )
    this.deliveries.set(key, {
      id: `delivery-${this.deliveries.size + 1}`,
      ...input,
      attemptCount: 1,
    })
  }

  private claim(args: Record<string, unknown>) {
    const giftCardId = String(args.p_gift_card_id ?? "")
    const destinationHash = String(args.p_destination_hash ?? "")
    const deliveryType = String(args.p_delivery_type ?? "")
    const key = this.deliveryKey(giftCardId, destinationHash, deliveryType)
    let row = this.deliveries.get(key)

    if (!row) {
      row = {
        id: `delivery-${this.deliveries.size + 1}`,
        giftCardId,
        destinationHash,
        deliveryType,
        status: "processing",
        attemptCount: 1,
      }
      this.deliveries.set(key, row)
      this.rpcClaims.push({ destinationHash, claimed: true })
      return {
        delivery_id: row.id,
        claimed: true,
        status: row.status,
        attempt_count: row.attemptCount,
      }
    }

    if (row.status === "sent" || row.status === "processing") {
      this.rpcClaims.push({ destinationHash, claimed: false })
      return {
        delivery_id: row.id,
        claimed: false,
        status: row.status,
        attempt_count: row.attemptCount,
      }
    }

    row.status = "processing"
    row.attemptCount += 1
    this.rpcClaims.push({ destinationHash, claimed: true })
    return {
      delivery_id: row.id,
      claimed: true,
      status: row.status,
      attempt_count: row.attemptCount,
    }
  }

  private deliveryKey(giftCardId: string, destinationHash: string, deliveryType: string) {
    return `${giftCardId}:${destinationHash}:${deliveryType}`
  }
}

class SingleRowQuery {
  constructor(private readonly row: Record<string, unknown> | null) {}
  select() {
    return this
  }
  eq() {
    return this
  }
  async maybeSingle() {
    return { data: this.row, error: null }
  }
}

class InsertQuery {
  constructor(
    private readonly insertRow: (row: Record<string, unknown>) => Record<string, unknown>,
  ) {
  }
  insert(row: Record<string, unknown>) {
    return new InsertSelectQuery(this.insertRow(row))
  }
}

class InsertSelectQuery {
  constructor(private readonly row: Record<string, unknown>) {}
  select() {
    return this
  }
  async maybeSingle() {
    return { data: this.row, error: null }
  }
}
