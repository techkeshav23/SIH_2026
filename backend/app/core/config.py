from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    secret_key: str = "dev-secret-change-me"
    database_url: str = "sqlite:///./kalasetu.db"

    use_real_ai: bool = False

    cloudinary_url: str = ""
    bhashini_user_id: str = ""
    bhashini_api_key: str = ""
    bhashini_pipeline_id: str = ""
    openai_api_key: str = ""
    gemini_api_key: str = ""
    pricing_model_path: str = "../ml/pricing_model.pkl"

    @property
    def is_dev(self) -> bool:
        return self.app_env == "dev"


settings = Settings()
