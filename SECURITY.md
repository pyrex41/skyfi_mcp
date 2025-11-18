# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in SkyFi MCP, please report it by emailing [your-email@example.com] or opening a private security advisory on GitHub.

**Please do not open public issues for security vulnerabilities.**

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- We aim to acknowledge reports within 48 hours
- We will provide a fix timeline within 1 week for critical issues
- You will be credited in the fix release notes (unless you prefer to remain anonymous)

---

## Security Best Practices

### API Key Management

- **Never commit API keys to version control**
- Use environment variables (`SKYFI_API_KEY`) for all deployments
- API keys are automatically hashed (SHA256) before database storage
- Monitor keys are stored securely and never logged

### For Production Deployments

1. **Use Fly.io Secrets for sensitive data:**
   ```bash
   fly secrets set SKYFI_API_KEY=your_key_here
   fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   ```

2. **Enable HTTPS only:**
   - Fly.io handles TLS termination automatically
   - Webhook URLs should use HTTPS

3. **Regularly rotate secrets:**
   - Change SECRET_KEY_BASE periodically
   - Rotate SkyFi API keys if compromised

4. **Monitor for unusual activity:**
   - Check logs for failed authentication attempts
   - Monitor webhook delivery failures
   - Review order placement patterns

### Known Security Considerations

1. **Webhook Security** (Current Implementation)
   - Webhooks validate URL format (HTTP/HTTPS)
   - 10-second timeout prevents long-running requests
   - 3-attempt retry with exponential backoff
   - **Future Enhancement**: HMAC signing for webhook payload verification

2. **Rate Limiting**
   - OpenStreetMap: 1 request/second (respects ToS)
   - SkyFi API: Handled by upstream service

3. **Input Validation**
   - All GeoJSON inputs validated via Ecto schemas
   - Bounding boxes validated for valid coordinate ranges
   - Date ranges validated for ISO8601 format
   - Cloud cover validated (0-100 range)

---

## Security Audit Status

**Last Audit**: 2025-11-18
**Status**: ✅ **No critical issues**

### Audit Findings

- ✅ API keys never logged or exposed in errors
- ✅ API keys hashed (SHA256) before database storage
- ✅ No known vulnerable dependencies (`mix hex.audit` clean)
- ✅ Input validation prevents basic injection attacks
- ✅ Webhook URLs validated before storage
- ⚠️ HMAC signing for webhooks not yet implemented (planned for v0.2)

---

## Contact

For security concerns, please contact: [your-email@example.com]
