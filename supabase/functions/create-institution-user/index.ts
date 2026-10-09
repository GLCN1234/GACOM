// Creates (or resets) the login account for an institution. Admin only: the
// role is checked server side from the JWT + profiles.role.
//
// Security notes:
//   - login_email / login_code / institution_id validated; the password policy
//     is enforced here (min 8) because this sets a real auth password
//   - an existing ADMIN or other privileged account can never be overwritten
//     into an 'institution' role through this endpoint
//   - the existing-user lookup pages through auth users instead of trusting a
//     single 1000-row page
//   - errors are generic; details only in server logs
import { secureServe, requireAdmin, asString, asUuid, HttpError, redact, ADMIN_ROLES } from '../_shared/security.ts'

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,}$/

secureServe('create-institution-user', async (req, ctx) => {
  const { svc: admin, user } = await requireAdmin(req)

  const body = await ctx.readJson()
  const institutionId = asUuid(body.institution_id, 'institution_id')
  const email = asString(body.login_email, 'login_email', { max: 254, pattern: EMAIL_RE }).toLowerCase()
  const code = asString(body.login_code, 'login_code', { min: 8, max: 72 })
  const localPart = email.split('@')[0]
  const profileRow = (id: string) => ({
    id,
    display_name: localPart.replace(/\./g, ' '),
    role: 'institution',
    username: localPart,
  })

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password: code,
    email_confirm: true,
    user_metadata: { institution_id: institutionId, role: 'institution' },
    // app_metadata is writable only with the service role; ownership checks read this one
    app_metadata: { institution_id: institutionId },
  })

  if (createError) {
    if (!String(createError.message ?? '').toLowerCase().includes('already')) {
      console.error('[create-institution-user] create failed:', redact(String(createError.message)))
      throw new HttpError(400, 'Could not create the institution account')
    }
    let existing: { id: string; email?: string } | undefined
    for (let page = 1; page <= 20 && !existing; page++) {
      const { data: list } = await admin.auth.admin.listUsers({ page, perPage: 1000 })
      const users = list?.users ?? []
      existing = users.find((u: { email?: string }) => (u.email ?? '').toLowerCase() === email)
      if (users.length < 1000) break
    }
    if (!existing) throw new HttpError(400, 'Could not create the institution account')

    const { data: prof } = await admin.from('profiles').select('role').eq('id', existing.id).maybeSingle()
    const role = String(prof?.role ?? '')
    if (existing.id === user.id || ADMIN_ROLES.includes(role) || (role && role !== 'institution' && role !== 'user')) {
      throw new HttpError(409, 'That email belongs to an existing account that cannot be converted')
    }
    await admin.auth.admin.updateUserById(existing.id, {
      password: code, email_confirm: true, user_metadata: { institution_id: institutionId, role: 'institution' },
      app_metadata: { institution_id: institutionId },
    })
    await admin.from('profiles').upsert(profileRow(existing.id))
    return ctx.json({ success: true })
  }

  if (created?.user) await admin.from('profiles').upsert(profileRow(created.user.id))
  return ctx.json({ success: true, user_id: created?.user?.id })
}, { maxBodyBytes: 4 * 1024, ipRateLimit: { limit: 30, windowMs: 60_000 } })
