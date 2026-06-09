import { errors } from '../../contracts/errors.ts'

// Best-effort E.164 normalization. US-centric default (bare 10-digit → +1).
// Stage 1 keeps this simple; a real libphonenumber pass is a later follow-up.
export function normalizePhone(raw: string): string {
  const trimmed = (raw ?? '').trim()
  const hasPlus = trimmed.startsWith('+')
  let digits = trimmed.replace(/\D/g, '')

  if (!hasPlus) {
    if (digits.length === 10) digits = '1' + digits // assume US/NANP
  }

  if (digits.length < 8 || digits.length > 15) {
    throw errors.badRequest('phone_invalid', 'Invalid phone number')
  }
  return '+' + digits
}
