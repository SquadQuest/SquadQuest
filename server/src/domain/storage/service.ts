import { randomUUID } from 'node:crypto'
import { Storage } from '@google-cloud/storage'

import { errors } from '../../contracts/errors.ts'

// Allowed upload content types → file extension. Keep narrow; this is user media.
const CONTENT_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

// Upload "kinds" map to key prefixes so objects are loosely organized + so a
// caller can't smuggle a weird prefix. Reads are public (unguessable uuid keys).
const KINDS = new Set(['profile', 'community', 'message'])

const UPLOAD_URL_TTL_MS = 10 * 60 * 1000

export interface UploadTarget {
  key: string
  upload_url: string
  public_url: string
}

// Mints V4 signed PUT URLs for direct-to-GCS uploads and builds public read URLs.
// On Cloud Run it signs keylessly via IAM signBlob (ADC, no key file). See
// specs/api/uploads.md + conventions.md §Storage.
export class StorageService {
  private readonly storage: Storage
  constructor(private readonly bucketName: string) {
    this.storage = new Storage()
  }

  publicUrl(key: string): string {
    return `https://storage.googleapis.com/${this.bucketName}/${key}`
  }

  // Validate the requested upload and return a signed PUT target.
  async createUploadTarget(kind: string, contentType: string): Promise<UploadTarget> {
    if (!KINDS.has(kind)) {
      throw errors.badRequest('invalid_upload_kind', `Unknown upload kind: ${kind}`)
    }
    const ext = CONTENT_TYPES[contentType]
    if (!ext) {
      throw errors.badRequest(
        'unsupported_content_type',
        `Unsupported content type: ${contentType}`,
      )
    }

    const key = `${kind}/${randomUUID()}.${ext}`
    const file = this.storage.bucket(this.bucketName).file(key)
    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: Date.now() + UPLOAD_URL_TTL_MS,
      contentType,
    })

    return { key, upload_url: uploadUrl, public_url: this.publicUrl(key) }
  }
}
