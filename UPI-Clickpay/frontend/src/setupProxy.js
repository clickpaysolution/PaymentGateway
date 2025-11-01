const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  // Proxy auth requests to auth service
  app.use(
    '/auth',
    createProxyMiddleware({
      target: 'http://localhost:8080',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );

  // Proxy payment requests to payment service
  app.use(
    '/payments',
    createProxyMiddleware({
      target: 'http://localhost:8081',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );

  // Proxy merchant requests to merchant service
  app.use(
    '/merchants',
    createProxyMiddleware({
      target: 'http://localhost:8082',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );

  // Proxy transaction requests to transaction service
  app.use(
    '/transactions',
    createProxyMiddleware({
      target: 'http://localhost:8083',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );

  // Proxy API gateway requests
  app.use(
    '/api',
    createProxyMiddleware({
      target: 'http://localhost:8084',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );
};