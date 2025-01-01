### HTTP request latency quick tests for example react app: 
- direct to web server ip from long-distance visitor: ~100ms 
- proxied through Cloudflare from long-distance visitor: ~700ms
- direct to Google.com: ~125ms
- to cloudflare CDN:  dropped to ~50ms but parallel requests are blocked by Cloudflare.