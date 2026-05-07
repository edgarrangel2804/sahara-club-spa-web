
---

# 📜 2. RULES.md (LAS LEYES DEL SISTEMA)

## 🔹 ¿Qué debe tener?

Las rules son **la constitución del proyecto**.

Definen:

- Cómo trabajan los agentes
- Qué está permitido
- Qué está prohibido
- Estándares de calidad
- Convenciones

---

## 📄 `/agents/core/rules.md`

```md
# SAHARA CLUB — SYSTEM RULES

## GLOBAL PRINCIPLE

Este proyecto se construye como una plataforma escalable, no como una app aislada.

---

## 1. ARCHITECTURE RULE

Siempre seguir este orden:

1. Database (Supabase)
2. Lógica (Feature Agents)
3. UI (Flutter)
4. Integraciones

Nunca al revés.

---

## 2. SINGLE SOURCE OF TRUTH

- Los datos viven en Supabase
- El frontend SOLO consume
- No duplicar lógica en Flutter

---

## 3. MODULARITY

Cada módulo debe ser independiente:

- Agenda
- Shop
- Payments
- Notifications

No mezclar responsabilidades.

---

## 4. DATA CONTRACT MANDATORY

Todos los agentes deben respetar estructuras de datos definidas.

Ejemplo:

```json
{
  "appointment_id": "uuid",
  "status": "confirmed"
}