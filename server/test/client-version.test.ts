import { expect, test } from 'bun:test'

import { parseClientHeader } from '../src/plugins/client-version.ts'

test('parses a well-formed client header', () => {
  expect(parseClientHeader('ios/1.4.2+312')).toEqual({
    platform: 'ios',
    version: '1.4.2',
    build: 312,
  })
})

test('handles android + multi-dot versions', () => {
  expect(parseClientHeader('android/2.0.0-beta.1+1099')).toEqual({
    platform: 'android',
    version: '2.0.0-beta.1',
    build: 1099,
  })
})

test('returns null for missing or malformed headers', () => {
  expect(parseClientHeader(undefined)).toBeNull()
  expect(parseClientHeader('')).toBeNull()
  expect(parseClientHeader('garbage')).toBeNull()
  expect(parseClientHeader('ios/1.0.0')).toBeNull() // no build
})
