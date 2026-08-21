from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    secret_key: str = "dev-secret-change-me"
    database_url: str = "sqlite:///./kalasetu.db"

    use_real_ai: bool = False

    # Gemini powers voice cataloging + pricing reasoning
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"

    # Image (F1): Pillow by default (no deps); rembg for real bg-removal
    use_rembg: bool = False
    cloudinary_url: str = ""  # optional hosted alternative

    pricing_model_path: str = "../ml/pricing_model.pkl"

    @property
    def is_dev(self) -> bool:
        return self.app_env == "dev"


settings = Settings()
