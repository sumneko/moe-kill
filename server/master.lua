local thread = require 'bee.thread'

moe.threadName = 'master'
thread.setname 'master'

log.info('moe-kill startup')
log.info('THREAD:', moe.threadName)
log.info('ROOT_PATH:', moe.env.ROOT_PATH:string())
log.info('LOG_FILE:', moe.env.LOG_FILE:string())
log.info('RUNTIME:', _VERSION)
log.info('LOGLEVEL:', log.level)

moe.timer.loop(60, function ()
    log.info('MEMORY: {%.1f} MB' % { collectgarbage('count') / 1024 })
end)
