import fp from 'fastify-plugin'
import postgres from 'postgres'
import { connectDb } from './connect'
import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js'

import * as schema from './schema/index.ts'

export type Database = PostgresJsDatabase<typeof schema>

declare module 'fastify' {
  interface FastifyInstance {
    db: Database
    sql: ReturnType<typeof postgres>
  }
}

// Decorates `fastify.db` (Drizzle) + `fastify.sql` (raw postgres-js client) and
// closes the pool on shutdown. DATABASE_URL is validated by the env plugin.
export default fp(async (fastify) => {
  const sql = connectDb(fastify.config.DATABASE_URL, { max: 10 })
  const db = drizzle(sql, { schema })

  fastify.decorate('db', db)
  fastify.decorate('sql', sql)

  fastify.addHook('onClose', async () => {
    await sql.end({ timeout: 5 })
  })
})
