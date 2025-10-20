from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.api.routes import auth, items

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


def create_application() -> FastAPI:
    application = FastAPI(
        title=settings.project_name,
        debug=settings.debug,
        lifespan=lifespan,
        version="0.1.0",
    )

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    application.include_router(auth.router)
    application.include_router(items.router)

    @application.get("/healthz", tags=["health"])
    def healthcheck() -> dict[str, str]:
        return {"status": "ok"}

    return application


app = create_application()
