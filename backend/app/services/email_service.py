"""Transactional email delivery through Resend.

The API key is read from the environment (RESEND_API_KEY, loaded from
backend/.env) and never logged or returned in API responses.
"""

import logging
from typing import Optional

from ..config.settings import settings

logger = logging.getLogger(__name__)
_last_test_mode_block = False

try:  # pragma: no cover - import guard for deployments without the SDK
    import resend
except Exception:  # pragma: no cover
    resend = None


def is_configured() -> bool:
    return bool((settings.RESEND_API_KEY or "").strip()) and resend is not None


def last_delivery_blocked_by_test_mode() -> bool:
    return _last_test_mode_block


def send_email(to: str, subject: str, html: str) -> bool:
    """Sends one email. Returns False (never raises) when delivery fails."""
    global _last_test_mode_block
    _last_test_mode_block = False
    if not is_configured():
        logger.warning("Email not sent: RESEND_API_KEY is not configured.")
        return False

    resend.api_key = settings.RESEND_API_KEY.strip()
    try:
        resend.Emails.send(
            {
                "from": settings.EMAIL_FROM,
                "to": [to],
                "subject": subject,
                "html": html,
            }
        )
        logger.info("Email sent to %s", to)
        return True
    except Exception as exc:  # network, auth, validation, rate limits
        text = str(exc).lower()
        if "own email address" in text or "verify a domain" in text:
            _last_test_mode_block = True
        logger.warning("Email delivery to %s failed: %s", to, exc)
        return False


def _layout(title: str, body: str, code: Optional[str] = None) -> str:
    code_block = (
        f'<div style="margin:24px 0;padding:16px;background:#F4F6FB;'
        f'border-radius:12px;text-align:center;font-size:28px;'
        f'letter-spacing:6px;font-weight:700;color:#1E2A44;">{code}</div>'
        if code
        else ""
    )
    return f"""\
<div style="font-family:Segoe UI,Helvetica,Arial,sans-serif;background:#F7F8FC;padding:32px;">
  <div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-radius:16px;padding:32px;">
    <h2 style="margin:0 0 16px;color:#1E2A44;font-size:20px;">{title}</h2>
    {code_block}
    {body}
    <p style="margin-top:28px;font-size:12px;color:#7A869A;">
      GM Inventory Everywhere &middot; This message was sent because of activity on your account.
      If this wasn't you, you can ignore this email.
    </p>
  </div>
</div>"""


def send_verification_code(to: str, code: str) -> bool:
    return send_email(
        to,
        "Your GM Inventory Everywhere recovery email code",
        _layout(
            "Verify your recovery email",
            "<p style='color:#3D4A5C;font-size:14px;line-height:1.6;'>"
            "Enter this code in GM Inventory Everywhere to confirm this address as your "
            "recovery email. It expires in 15 minutes and can be used once.</p>",
            code,
        ),
    )


def send_recovery_token(to: str, token: str) -> bool:
    return send_email(
        to,
        "Reset your GM Inventory Everywhere password",
        _layout(
            "Password recovery",
            "<p style='color:#3D4A5C;font-size:14px;line-height:1.6;'>"
            "Enter this code in GM Inventory Everywhere to set a new password. It expires "
            "in 15 minutes and works once. Your Google sign-in and your shop "
            "data are not affected.</p>",
            token,
        ),
    )
