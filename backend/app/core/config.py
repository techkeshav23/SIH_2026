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

    pricing_model_path: str = "../ml/pricing_model.pkl"

    # ---- Payments ----
    payment_provider: str = "mock"   # mock | razorpay
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""

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
