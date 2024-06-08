import { createClient } from '@supabase/supabase-js'

// Load .env from parent directory
import { config as dotenvConfig } from 'dotenv'
dotenvConfig('../.env')

// Create a single supabase client for interacting with your database
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY)

const phone = process.env.SUPABASE_USER_PHONE

// Sign in with phone number
// const { data, error } = await supabase.auth.signInWithOtp({
//     phone,
// })

// Verify the OTP
// const {
//     data: { session },
//     error,
// } = await supabase.auth.verifyOtp({
//     phone,
//     token: '368908',
//     type: 'sms',
// })

const accessToken = process.env.SUPABASE_USER_ACCESS_TOKEN
const refreshToken = process.env.SUPABASE_USER_REFRESH_TOKEN


const { data, error } = await supabase
  .from('topics')
  .select()

debugger
