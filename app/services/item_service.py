from __future__ import annotations

from typing import Iterable
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.item import Item
from app.schemas.item import ItemCreate, ItemUpdate


def list_items(db: Session, owner_id: UUID) -> Iterable[Item]:
    stmt = select(Item).where(Item.owner_id == owner_id).order_by(Item.created_at.desc())
    return db.scalars(stmt).all()


def get_item(db: Session, owner_id: UUID, item_id: UUID) -> Item | None:
    return db.scalar(select(Item).where(Item.owner_id == owner_id, Item.id == item_id))


def create_item(db: Session, owner_id: UUID, item_in: ItemCreate) -> Item:
    item = Item(title=item_in.title, description=item_in.description, owner_id=owner_id)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_item(db: Session, item: Item, item_in: ItemUpdate) -> Item:
    if item_in.title is not None:
        item.title = item_in.title
    if item_in.description is not None:
        item.description = item_in.description
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def delete_item(db: Session, item: Item) -> None:
    db.delete(item)
    db.commit()
