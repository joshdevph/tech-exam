from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables or `.env`."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    project_name: str = Field(default="FastAPI AWS Ready API", env="PROJECT_NAME")
    environment: str = Field(default="local", env="ENVIRONMENT")
    debug: bool = Field(default=False, env="DEBUG")

    # Security
    secret_key: str = Field(default="change-me", env="SECRET_KEY")
    algorithm: str = Field(default="HS256", env="ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")

    # Database
    postgres_user: str = Field(default="app", env="POSTGRES_USER")
    postgres_password: str = Field(default="app", env="POSTGRES_PASSWORD")
    postgres_server: str = Field(default="db", env="POSTGRES_SERVER")
    postgres_port: int = Field(default=5432, env="POSTGRES_PORT")
    postgres_db: str = Field(default="app_db", env="POSTGRES_DB")
    sqlalchemy_database_uri: str | None = Field(default=None, env="DATABASE_URL")

    # AWS hints
    aws_region: str = Field(default="us-east-1", env="AWS_REGION")

    @property
    def database_url(self) -> str:
        """Construct the SQLAlchemy database URL."""
        if self.sqlalchemy_database_uri:
            return self.sqlalchemy_database_uri

        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_server}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()
