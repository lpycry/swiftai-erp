package main

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
	"golang.org/x/time/rate"
)

// ReverseProxy creates a Gin handler that proxies requests to the target URL.
func ReverseProxy(target string) gin.HandlerFunc {
	return func(c *gin.Context) {
		remote, err := url.Parse(target)
		if err != nil {
			log.Err(err).Str("target", target).Msg("invalid proxy target")
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		proxy := httputil.NewSingleHostReverseProxy(remote)

		// Rewrite path
		c.Request.URL.Path = strings.TrimPrefix(c.Request.URL.Path, "/api/v1")

		// Inject headers
		c.Request.Header.Set("X-Forwarded-Host", c.Request.Host)
		c.Request.Header.Set("X-Forwarded-Proto", c.Request.Header.Get("X-Forwarded-Proto"))
		if c.Request.Header.Get("X-Forwarded-Proto") == "" {
			if c.Request.TLS != nil {
				c.Request.Header.Set("X-Forwarded-Proto", "https")
			} else {
				c.Request.Header.Set("X-Forwarded-Proto", "http")
			}
		}
		c.Request.Header.Set("X-Real-IP", c.ClientIP())

		proxy.ServeHTTP(c.Writer, c.Request)
	}
}

// RateLimiter returns a Gin middleware that rate-limits by IP.
func RateLimiter(rdb *redis.Client) gin.HandlerFunc {
	// Per-IP rate limiter using token bucket
	clients := make(map[string]*rate.Limiter)
	go func() {
		for {
			time.Sleep(10 * time.Minute)
			clients = make(map[string]*rate.Limiter) // periodic cleanup
		}
	}()

	return func(c *gin.Context) {
		ip := c.ClientIP()
		limiter, ok := clients[ip]
		if !ok {
			limiter = rate.NewLimiter(rate.Limit(100), 200) // 100 req/s burst 200
			clients[ip] = limiter
		}

		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
			})
			return
		}
		c.Next()
	}
}
