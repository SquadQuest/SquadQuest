import Fastify from 'fastify'

import { app } from './app.ts'

const server = Fastify({
  logger: { level: 'info' },
})

server.register(app)

const gracefulShutdown = async (signal: string) => {
  server.log.info(`Received ${signal}, shutting down gracefully`)
  try {
    await server.close()
    process.exit(0)
  } catch (error) {
    server.log.error(error, 'Error during shutdown')
    process.exit(1)
  }
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

const start = async () => {
  try {
    await server.ready()
    const { PORT, HOST } = server.config
    await server.listen({ port: PORT, host: HOST })
    server.log.info(`squadquest-server listening at http://${HOST}:${PORT}`)
  } catch (err) {
    server.log.error(err)
    process.exit(1)
  }
}

start()
