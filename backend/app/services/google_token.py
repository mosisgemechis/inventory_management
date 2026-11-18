"""Verification of Google ID tokens.

The client must never be trusted to say who it is: the ID token is verified
against Google's published signing keys, and the issuer, audience, expiration
and email-verification claims are checked here.
"""
import base64
import json
import threading
import time
import urllib.request

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa

CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
VALID_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}

_lock = threading.Lock()
_cache = {"fetched_at": 0.0, "keys": {}}


class GoogleTokenError(Exception):
    """Raised when a Google ID token cannot be trusted."""


def _b64url_decode(value: str) -> bytes:
    padding_needed = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding_needed)


def _load_keys() -> dict:
    with _lock:
        if time.time() - _cache["fetched_at"] < 3600 and _cache["keys"]:
            return _cache["keys"]
        data = None
        last_error = None
        for _ in range(2):
            try:
                with urllib.request.urlopen(CERTS_URL, timeout=10) as response:
                    data = json.load(response)
                break
            except Exception as exc:  # network / parse failure
                last_error = exc
                time.sleep(0.4)
        if data is None:
            raise GoogleTokenError(
                "Google sign-in could not be verified right now. Please try again."
            ) from last_error

        keys = {}
        for jwk in data.get("keys", []):
            try:
                n = int.from_bytes(_b64url_decode(jwk["n"]), "big")
                e = int.from_bytes(_b64url_decode(jwk["e"]), "big")
                keys[jwk["kid"]] = rsa.RSAPublicNumbers(e, n).public_key()
            except Exception:
                continue
        if not keys:
            raise GoogleTokenError(
                "Google sign-in could not be verified right now. Please try again."
            )
        _cache["keys"] = keys
        _cache["fetched_at"] = time.time()
        return keys


def _decode_segment(segment: str) -> dict:
    try:
        decoded = json.loads(_b64url_decode(segment))
    except Exception as exc:
        raise GoogleTokenError("Invalid Google authentication response.") from exc
    if not isinstance(decoded, dict):
        raise GoogleTokenError("Invalid Google authentication response.")
    return decoded


def verify_google_id_token(token: str, audiences: list[str]) -> dict:
    """Returns the verified claims, or raises GoogleTokenError."""
    if not token or token.count(".") != 2:
        raise GoogleTokenError("Invalid Google authentication response.")

    header_seg, payload_seg, signature_seg = token.split(".")
    header = _decode_segment(header_seg)
    claims = _decode_segment(payload_seg)

    if header.get("alg") != "RS256":
        raise GoogleTokenError("Invalid Google authentication response.")

    kid = header.get("kid")
    keys = _load_keys()
    key = keys.get(kid)
    if key is None:
        # Key rotation: refetch once.
        _cache["fetched_at"] = 0.0
        key = _load_keys().get(kid)
    if key is None:
        raise GoogleTokenError("Invalid Google authentication response.")

    signing_input = f"{header_seg}.{payload_seg}".encode("ascii")
    try:
        key.verify(
            _b64url_decode(signature_seg),
            signing_input,
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
    except (InvalidSignature, ValueError) as exc:
        raise GoogleTokenError("Invalid Google authentication response.") from exc

    now = time.time()
    if claims.get("iss") not in VALID_ISSUERS:
        raise GoogleTokenError("Invalid Google authentication response.")
    if audiences and claims.get("aud") not in audiences:
        raise GoogleTokenError("Invalid Google authentication response.")
    try:
        expires_at = float(claims.get("exp", 0))
    except (TypeError, ValueError):
        expires_at = 0
    if expires_at <= now:
        raise GoogleTokenError("Your Google sign-in expired. Please try again.")
    if not claims.get("email"):
        raise GoogleTokenError("Google did not share an email address for this account.")
    if claims.get("email_verified") is False:
        raise GoogleTokenError("Please verify your Google email address first.")
    if not claims.get("sub"):
        raise GoogleTokenError("Invalid Google authentication response.")

    return claims
