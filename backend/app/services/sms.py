"""SMS provider abstraction.

`console` provider (default) just logs the OTP — perfect for dev/staging.
Swap SMS_PROVIDER=msg91 (or twilio) + SMS_API_KEY in prod. Real providers are
stubbed with clear TODOs; the interface stays identical so nothing else changes.
"""
import logging

from app.core.config import settings

log = logging.getLogger("kalasetu.sms")


def send_otp(phone: str, otp: str) -> None:
    provider = settings.sms_provider
    if provider == "console":
        log.info("[SMS:console] OTP for %s = %s", phone, otp)
        return
    if provider == "msg91":
        _send_msg91(phone, otp)
        return
    if provider == "twilio":
        _send_twilio(phone, otp)
        return
    log.warning("Unknown SMS provider '%s' — OTP not sent", provider)


def _send_msg91(phone: str, otp: str) -> None:
    # TODO(prod): POST https://control.msg91.com/api/v5/otp with settings.sms_api_key
    raise NotImplementedError("Wire MSG91 here")


def _send_twilio(phone: str, otp: str) -> None:
    # TODO(prod): twilio Client(...).messages.create(...)
    raise NotImplementedError("Wire Twilio here")
