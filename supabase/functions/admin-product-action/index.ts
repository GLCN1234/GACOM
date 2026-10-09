// Server-side admin product actions (update/delete), bypassing RLS by design.
// Built because direct client-side updates were being rejected by RLS despite
// every layer checking out. The caller's admin role is verified HERE, on the
// server, from their JWT and the profiles table, and only then is the
// service-role write performed.
//
// Security notes:
//   - identity and role come from the JWT + profiles.role, never the body
//   - `updates` is an allow-list of columns with type/length checks
//     (previously any column, including seller_id/is_ai_sourced, could be set)
import { secureServe, requireAdmin, asUuid, asEnum, HttpError, cleanText, safeHttpsUrlOrNull } from '../_shared/security.ts'

const UPDATABLE = ['name', 'price', 'description', 'price_confidence', 'stock', 'category', 'images', 'is_active', 'delivery_estimate'] as const

// deno-lint-ignore no-explicit-any
function sanitizeUpdates(raw: any): Record<string, unknown> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new HttpError(400, 'updates object is required for action=update')
  }
  const out: Record<string, unknown> = {}
  for (const [k, v] of Object.entries(raw)) {
    if (!(UPDATABLE as readonly string[]).includes(k)) throw new HttpError(400, `Field not editable: ${k.slice(0, 40)}`)
    switch (k) {
      case 'name': out[k] = cleanText(v, 200); if (!out[k]) throw new HttpError(400, 'name is required'); break
      case 'description': out[k] = cleanText(v, 4000); break
      case 'category': out[k] = cleanText(v, 50); break
      case 'delivery_estimate': out[k] = cleanText(v, 200); break
      case 'price_confidence': out[k] = asEnum(v, 'price_confidence', ['high', 'low', 'unknown'] as const); break
      case 'price': {
        const n = Number(v)
        if (!Number.isFinite(n) || n < 0 || n > 100_000_000) throw new HttpError(400, 'price is invalid')
        out[k] = n
        break
      }
      case 'stock': {
        const n = Number(v)
        if (!Number.isInteger(n) || n < 0 || n > 1_000_000) throw new HttpError(400, 'stock is invalid')
        out[k] = n
        break
      }
      case 'is_active':
        if (typeof v !== 'boolean') throw new HttpError(400, 'is_active must be true or false')
        out[k] = v
        break
      case 'images': {
        if (!Array.isArray(v) || v.length > 12) throw new HttpError(400, 'images is invalid')
        const urls = v.map((u) => safeHttpsUrlOrNull(u, 1000))
        if (urls.some((u) => u === null)) throw new HttpError(400, 'images must be https URLs')
        out[k] = urls
        break
      }
    }
  }
  if (Object.keys(out).length === 0) throw new HttpError(400, 'No updates supplied')
  return out
}

secureServe('admin-product-action', async (req, ctx) => {
  const { svc } = await requireAdmin(req)

  const body = await ctx.readJson()
  const action = asEnum(body.action, 'action', ['delete', 'update'] as const)
  const productId = asUuid(body.productId, 'productId')

  if (action === 'delete') {
    // Soft delete, as before.
    const { error } = await svc.from('products').update({ is_active: false }).eq('id', productId)
    if (error) throw error
  } else {
    const updates = sanitizeUpdates(body.updates)
    const { error } = await svc.from('products').update(updates).eq('id', productId)
    if (error) throw error
  }
  return ctx.json({ success: true })
})
