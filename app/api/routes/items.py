from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_user, get_db
from app.db.models.user import User
from app.schemas.item import ItemCreate, ItemRead, ItemUpdate
from app.services.item_service import (
    create_item,
    delete_item,
    get_item,
    list_items,
    update_item,
)

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/", response_model=list[ItemRead])
def list_my_items(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> list[ItemRead]:
    items = list_items(db, owner_id=current_user.id)
    return list(items)


@router.post("/", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
def create_item_for_user(
    item_in: ItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ItemRead:
    item = create_item(db, owner_id=current_user.id, item_in=item_in)
    return item


@router.get("/{item_id}", response_model=ItemRead)
def get_item_by_id(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ItemRead:
    item = get_item(db, owner_id=current_user.id, item_id=item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.put("/{item_id}", response_model=ItemRead)
def update_item_by_id(
    item_id: UUID,
    item_in: ItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> ItemRead:
    item = get_item(db, owner_id=current_user.id, item_id=item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    updated_item = update_item(db, item=item, item_in=item_in)
    return updated_item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item_by_id(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
) -> None:
    item = get_item(db, owner_id=current_user.id, item_id=item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    delete_item(db, item)
    return None
