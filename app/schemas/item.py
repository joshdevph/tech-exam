from __future__ import annotations

from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ItemBase(BaseModel):
    title: str = Field(max_length=255)
    description: Optional[str] = None


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    title: Optional[str] = Field(default=None, max_length=255)
    description: Optional[str] = None


class ItemRead(ItemBase):
    id: UUID
    owner_id: UUID

    class Config:
        from_attributes = True
