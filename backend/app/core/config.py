from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    secret_key: str = "dev-secret-change-me"
    database_url: str = "sqlite:///./kalasetu.db"

    # ---- Async jobs ----
    redis_url: str = ""              # e.g. redis://localhost:6379/0
    use_celery: bool = False         # when False (or no redis_url), tasks run inline (eager)

    # ---- Auth / tokens ----
    access_token_ttl_min: int = 60           # short-lived access token
    refresh_token_ttl_days: int = 30         # long-lived refresh token

    # ---- OTP ----
    otp_ttl_sec: int = 300                   # 5 min validity
    otp_max_attempts: int = 5                # wrong tries before invalidation
    otp_resend_cooldown_sec: int = 30        # anti-spam between resends
    otp_length: int = 6
    sms_provider: str = "console"            # console | msg91 | twilio
    sms_api_key: str = ""
    sms_sender_id: str = "KLSETU"
    allow_dev_otp: bool = False              # demo-only: return OTP in the response (no real SMS)

    # ---- CORS / rate limiting / uploads ----
    cors_origins: str = "*"                  # comma-separated list or "*"
    rate_limit_enabled: bool = True
    max_upload_mb: int = 8
    allowed_image_types: str = "image/jpeg,image/png,image/webp"
    allowed_audio_types: str = "audio/wav,audio/x-wav,audio/mpeg,audio/mp4,audio/aac,audio/ogg,audio/webm"

    # ---- AI (Vertex AI primary) ----
    use_vertex: bool = True                  # True -> Vertex AI (GCP); False -> Gemini Developer API
    gcp_project: str = ""                    # GCP project id (Vertex)
    gcp_location: str = "asia-south1"        # Mumbai region — India data residency
    gemini_api_key: str = ""                 # only used when use_vertex=False (fallback)
    gemini_model: str = "gemini-2.5-flash"   # same model id on both backends
    ai_daily_quota: int = 50                 # per-user AI calls/day (cost guard)

    # Image (F1)
    use_real_ai: bool = False
    use_rembg: bool = False
    cloudinary_url: str = ""
    gcs_bucket: str = ""             # durable image storage (Cloud Run disk is ephemeral)
    # Gemini image-to-image "studio" enhancement — turns the artisan's real photo
    # into a professional product shot (the product stays identical).
    use_gemini_image: bool = False
    gemini_image_model: str = "gemini-2.5-flash-image"
    gemini_image_location: str = "global"   # image-gen isn't served from asia-south1

    # Kala voice agent (Gemini Live, native audio). NOTE: the native-audio Live
    # model is NOT served from asia-south1 — us-central1 is the nearest that has it.
    voice_model: str = "gemini-live-2.5-flash-native-audio"
    voice_location: str = "us-central1"

    pricing_model_path: str = "../ml/pricing_model.pkl"

    # ---- Payments ----
    payment_provider: str = "mock"   # mock | razorpay
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""

    # ---- Notifications ----
    notify_provider: str = "log"     # log | fcm | sms

    # ---- Observability ----
    sentry_dsn: str = ""             # empty -> Sentry disabled
    log_level: str = "INFO"
    log_json: bool = False           # True -> structured JSON logs (prod)

    # ---- Govt integrations (P5) ----
    # Bhashini (govt Indic STT/MT) — when on, used for voice transcription+translation
    # before the LLM writes the listing. Off -> Vertex handles audio directly.
    use_bhashini_stt: bool = False
    bhashini_user_id: str = ""
    bhashini_api_key: str = ""
    bhashini_pipeline_id: str = ""

    # ONDC / GeM — publish listed products to the open network. Off -> local only.
    use_ondc: bool = False
    ondc_subscriber_id: str = ""
    ondc_signing_key: str = ""
    ondc_base_url: str = ""

    # ---- Ad campaigns (P8) ----
    # Meta Marketing API — creates a real, PAUSED campaign in the artisan's own ad
    # account (never spends, never goes live). Off -> stub (fake campaign id/url).
    use_meta_ads: bool = False
    meta_app_id: str = ""
    meta_app_secret: str = ""
    meta_access_token: str = ""       # long-lived user/system-user token (ads_management)
    meta_ad_account_id: str = ""      # numeric id, without the "act_" prefix
    meta_api_version: str = "v21.0"

    # Google Ads API — same PAUSED-campaign-only approach. Off -> stub.
    use_google_ads: bool = False
    google_ads_developer_token: str = ""
    google_ads_client_id: str = ""
    google_ads_client_secret: str = ""
    google_ads_refresh_token: str = ""
    google_ads_customer_id: str = ""  # 10-digit id, no dashes

    @property
    def is_dev(self) -> bool:
        return self.app_env == "dev"

    @property
    def cors_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def image_types(self) -> set[str]:
        return {t.strip() for t in self.allowed_image_types.split(",") if t.strip()}

    @property
    def audio_types(self) -> set[str]:
        return {t.strip() for t in self.allowed_audio_types.split(",") if t.strip()}


settings = Settings()
