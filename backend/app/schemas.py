"""Pydantic request/response semalari — openapi.yaml ile uyumlu."""
from __future__ import annotations

import uuid

from pydantic import BaseModel, EmailStr, Field


# ------------------------------- auth -------------------------------------- #
class LoginRequest(BaseModel):
    tenant_slug: str = Field(..., examples=["acme-plaza"])
    email: EmailStr
    password: str = Field(..., min_length=8)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


# ------------------------------- users ------------------------------------- #
class UserOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    ad: str
    email: str
    role: str
    is_active: bool


# ----------------------- Faz-0 dogrulama (diagnostic) ---------------------- #
# NOT: Asagidakiler tenant izolasyonunu token uzerinden uctan uca dogrulamak
# icin Faz-0 yardimci semalaridir; Checkpoint CRUD Prompt 3'te gelince
# openapi'deki Checkpoint semasiyla degistirilecek.
class CheckpointBrief(BaseModel):
    id: uuid.UUID
    ad: str
    nfc_tag_uid: str
