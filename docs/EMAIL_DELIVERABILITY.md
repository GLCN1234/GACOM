# Sign-up and login emails landing in spam (Mailjet)

## Why it happens

Supabase sends sign-up, login and reset emails from its own shared sender
(`noreply@mail.app.supabase.io`) when no custom mail server is set. Thousands of
projects share that address, it is rate limited, and it is not tied to
gamicom.net. Gmail, Yahoo and Outlook treat it as untrusted, so the mail goes to
spam or never arrives. The wording is a small factor; the sender is the big one.

The fix is to send these emails from your own domain through Mailjet, with the
domain authenticated (SPF + DKIM + DMARC).

Note: the Edge Functions in this repo (orders, newsletter, renewals) call the
Resend API directly. That is a separate path from sign-up mail and does not
affect it. Sign-up, login and reset mail is sent by Supabase Auth, so only the
Supabase SMTP setting below matters for this problem.

## Step 1: Authenticate gamicom.net in Mailjet (10 minutes)

1. Mailjet > Account Settings > **Sender domains & addresses** > Add a domain >
   `gamicom.net`.
2. Add a sender address `no-reply@gamicom.net` (Mailjet sends a validation email
   to it; create that mailbox or an alias first, or validate by uploading the
   file Mailjet gives you to the domain root).
3. Click **Authenticate this domain**. Mailjet shows DNS records. Add them at
   your DNS host (the place you manage gamicom.net):
   - **SPF** (TXT on the root `gamicom.net`). If you already have an SPF record,
     do not add a second one; add Mailjet to it:
     `v=spf1 include:spf.mailjet.com ~all`
     (with other senders: `v=spf1 include:spf.mailjet.com include:<other> ~all`)
   - **DKIM** (TXT, name like `mailjet._domainkey`, value `k=rsa; p=...` as shown
     by Mailjet). Copy it exactly, one record.
4. Back in Mailjet press **Check now**. Both SPF and DKIM must be green.
   DNS can take from a few minutes to a few hours.
5. Add a DMARC record (one TXT record) if you have none:
   - Name: `_dmarc`
   - Value: `v=DMARC1; p=none; rua=mailto:dmarc@gamicom.net; adkim=r; aspf=r`
   After two weeks with no problems, change `p=none` to `p=quarantine`.

If you only validate a single sender address without authenticating the domain,
Mailjet signs mail with its own domain and Gmail will keep sending it to spam.
Domain authentication is the step that matters.

## Step 2: Point Supabase at Mailjet

1. Mailjet > Account Settings > **REST API** (API Key Management): copy the
   **API Key** and **Secret Key**.
2. Supabase > Project Settings > Authentication > **SMTP Settings** > turn on
   "Enable Custom SMTP":
   - Sender email: `no-reply@gamicom.net` (the exact address validated in Mailjet)
   - Sender name: `GACOM`
   - Host: `in-v3.mailjet.com`
   - Port: `465` (use `587` if 465 fails)
   - Username: the Mailjet **API Key**
   - Password: the Mailjet **Secret Key**
3. Save. Then Authentication > Rate Limits: raise "emails sent per hour" (it
   starts very low once custom SMTP is on), for example to 100.

If a test sign-up never arrives, check Mailjet > Statistics > Messages for the
status (blocked, soft bounce, sender not validated) and Supabase > Logs > Auth.

## Step 3: Use the new email templates

Supabase > Authentication > **Email Templates**. For each type, paste the file
from `supabase/templates/` and set the subject:

| Template        | File                     | Subject                          |
|-----------------|--------------------------|----------------------------------|
| Confirm signup  | confirmation.html        | Confirm your GACOM account       |
| Reset password  | recovery.html            | Reset your GACOM password        |
| Magic link      | magic_link.html          | Your GACOM sign-in link          |
| Invite user     | invite.html              | You are invited to GACOM         |
| Change email    | email_change.html        | Confirm your new GACOM email     |
| Reauthenticate  | reauthentication.html    | Your GACOM confirmation code     |

The templates are plain and short on purpose: real sentences, one button, the
link written out as text, a line saying why the person got the email, and the
company name and address. No emojis, no shouting, no tracking images.

## Step 4: Turn off Mailjet link tracking for these mails

Mailjet rewrites links through its own tracking domain by default, which makes
confirm and reset links look suspicious and can break them. Mailjet > Account
Settings > **Sender domains & addresses** (or Transactional > Settings) > make
sure **click tracking and open tracking are off** for transactional mail sent
over SMTP. This matters for deliverability.

## Step 5: Test

1. Send a sign-up to a fresh Gmail address. Open the message > three dots >
   "Show original". You want `SPF: PASS`, `DKIM: PASS`, `DMARC: PASS`, and the
   "signed-by" domain should be `gamicom.net`.
2. Send one to https://www.mail-tester.com (it gives you an address). Aim for 9/10 or better.
3. Ask a few early users to mark the first message "Not spam". It speeds up trust.

## Mailjet plan limits

The Free plan has a daily send cap (about 200 per day, 6,000 per month) and shows
a Mailjet footer. A busy launch day can pass that, and sign-ups then silently
stop getting mail. Watch Mailjet > Statistics, and upgrade before a push.

## Branded links (done in the templates and the app)

The templates now link to `https://gamicom.net/#/auth/confirm?token_hash=...&type=...`
instead of the Supabase address. The app route `/auth/confirm`
(`auth_confirm_screen.dart`) swaps the token for a session with `verifyOTP`. You
must deploy the app (Netlify) before pasting the new templates, otherwise the
links open a page that does not exist yet. Also set Authentication > URL
Configuration > Site URL to `https://gamicom.net`.

Run in this order: push and let Netlify finish, paste the templates in Supabase,
then send a fresh test. Links in emails sent before that keep the old format.

## What to tell users meanwhile

"Check your spam or junk folder and mark the email 'Not spam'. We have just
moved to a new sender, and the problem should disappear within days."
