import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "GM Inventory Everywhere Sync API"
    ENVIRONMENT: str = "development"
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "onboarding@resend.dev"
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    
    # Database URL defaults to env or PostgreSQL
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "sqlite:///./inventory_backend.db"
    )
    
    # Google OAuth client IDs accepted as ID-token audiences (comma separated)
    GOOGLE_CLIENT_IDS: str = ""
    GOOGLE_CLIENT_ID: str = ""

    # JWT / Auth
    JWT_SECRET: str = os.getenv("JWT_SECRET", "change-me-in-production")
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_EXPIRE_MINUTES: int = 30          # short-lived access token
    JWT_REFRESH_EXPIRE_DAYS: int = 30            # long-lived refresh token
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
