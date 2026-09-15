"""
SmartSaaS Hermes platform adapter.

Telegram-style bridge: Hermes dials out to SmartSaaS, long-polls the bridge inbox,
runs messages through the gateway AIAgent, and POSTs replies back.

Install:
  cp -R plugins/smartsaas ~/.hermes/plugins/smartsaas
  # set SMARTSAAS_BASE_URL + SMARTSAAS_BRIDGE_TOKEN in ~/.hermes/.env
  hermes gateway
"""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Any, Optional

import aiohttp

from gateway.config import Platform, PlatformConfig
from gateway.platforms.base import (
    BasePlatformAdapter,
    MessageEvent,
    MessageType,
    SendResult,
)

logger = logging.getLogger(__name__)


def _env(name: str, default: str = "") -> str:
    return (os.getenv(name) or default).strip()


class SmartSaaSAdapter(BasePlatformAdapter):
    """Outbound long-poll bridge to SmartSaaS cloud."""

    def __init__(self, config: PlatformConfig):
        super().__init__(config, Platform("smartsaas"))
        extra = config.extra or {}
        self.base_url = (
            _env("SMARTSAAS_BASE_URL")
            or str(extra.get("base_url") or extra.get("baseUrl") or "")
        ).rstrip("/")
        self.bridge_token = _env("SMARTSAAS_BRIDGE_TOKEN") or str(
            extra.get("bridge_token") or extra.get("bridgeToken") or ""
        )
        self.poll_seconds = int(
            _env("SMARTSAAS_POLL_SECONDS")
            or str(extra.get("poll_seconds") or 25)
            or 25
        )
        self._session: Optional[aiohttp.ClientSession] = None
        self._poll_task: Optional[asyncio.Task] = None
        self._stop = asyncio.Event()
        # chat_id → correlationId for session chat waiters
        self._pending_correlations: dict[str, str] = {}
        # FIFO fallback when Hermes remaps chat_id to home channel (e.g. "hermes")
        self._pending_correlation_fifo: list[str] = []

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.bridge_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "smartsaas-hermes-bridge/1.0",
        }

    async def connect(self, *, is_reconnect: bool = False) -> bool:
        if not self.base_url or not self.bridge_token:
            logger.error(
                "[smartsaas] SMARTSAAS_BASE_URL and SMARTSAAS_BRIDGE_TOKEN are required"
            )
            return False

        self._stop.clear()
        timeout = aiohttp.ClientTimeout(
            total=None, sock_connect=30, sock_read=self.poll_seconds + 15
        )
        self._session = aiohttp.ClientSession(timeout=timeout, headers=self._headers())

        ok = await self._heartbeat()
        if not ok:
            await self._close_session()
            return False

        self._poll_task = asyncio.create_task(self._poll_loop(), name="smartsaas-poll")
        self._mark_connected()
        logger.info("[smartsaas] connected to %s", self.base_url)
        return True

    async def disconnect(self) -> None:
        self._stop.set()
        if self._poll_task and not self._poll_task.done():
            self._poll_task.cancel()
            try:
                await self._poll_task
            except asyncio.CancelledError:
                pass
        await self._close_session()
        self._mark_disconnected()
        logger.info("[smartsaas] disconnected")

    async def _close_session(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()
        self._session = None

    async def _heartbeat(self) -> bool:
        assert self._session is not None
        url = f"{self.base_url}/api/protected/hermes/bridge/heartbeat"
        try:
            async with self._session.post(url, json={"platform": "smartsaas"}) as resp:
                if resp.status >= 400:
                    body = await resp.text()
                    logger.error(
                        "[smartsaas] heartbeat failed %s: %s", resp.status, body[:300]
                    )
                    return False
                return True
        except Exception as exc:
            logger.error("[smartsaas] heartbeat error: %s", exc)
            return False

    async def _poll_loop(self) -> None:
        assert self._session is not None
        url = f"{self.base_url}/api/protected/hermes/bridge/poll"
        while not self._stop.is_set():
            try:
                payload = {"waitSeconds": self.poll_seconds, "maxMessages": 10}
                async with self._session.post(url, json=payload) as resp:
                    if resp.status == 401:
                        logger.error(
                            "[smartsaas] unauthorized — check SMARTSAAS_BRIDGE_TOKEN"
                        )
                        await asyncio.sleep(5)
                        continue
                    if resp.status >= 400:
                        text = await resp.text()
                        logger.warning(
                            "[smartsaas] poll %s: %s", resp.status, text[:200]
                        )
                        await asyncio.sleep(3)
                        continue
                    data = await resp.json(content_type=None)
                    messages = data.get("messages") or []
                    for msg in messages:
                        await self._ingest(msg)
            except asyncio.CancelledError:
                raise
            except asyncio.TimeoutError:
                continue
            except Exception as exc:
                logger.warning("[smartsaas] poll loop error: %s", exc)
                await asyncio.sleep(3)

    async def _ingest(self, msg: dict[str, Any]) -> None:
        text = str(
            msg.get("text") or msg.get("message") or msg.get("content") or ""
        ).strip()
        if not text:
            return
        chat_id = str(msg.get("chatId") or msg.get("conversationId") or "smartsaas")
        user_id = str(msg.get("userId") or msg.get("senderId") or "smartsaas-user")
        message_id = str(msg.get("id") or msg.get("messageId") or "")
        source_kind = str(msg.get("source") or "user")
        correlation_id = str(msg.get("correlationId") or message_id or "")

        if source_kind in ("orchestrator", "proactive", "cron"):
            title = str(msg.get("title") or "SmartSaaS orchestrator task")
            text = f"[SmartSaaS orchestrator] {title}\n\n{text}"

        if correlation_id:
            self._pending_correlations[chat_id] = correlation_id
            self._pending_correlation_fifo.append(correlation_id)

        logger.info(
            "[smartsaas] ingest chat_id=%s user_id=%s corr=%s text=%s",
            chat_id,
            user_id,
            correlation_id,
            text[:120],
        )

        source = self.build_source(
            chat_id=chat_id,
            chat_name="SmartSaaS",
            chat_type="dm",
            user_id=user_id,
            user_name="SmartSaaS",
        )

        event = MessageEvent(
            text=text,
            message_type=MessageType.TEXT,
            source=source,
            user_id=user_id,
            user_name="SmartSaaS",
            message_id=message_id or None,
            raw_message=msg,
            metadata={
                "smartsaas": {
                    "source": source_kind,
                    "agentId": msg.get("agentId"),
                    "correlationId": correlation_id or None,
                    "companyId": msg.get("companyId"),
                }
            },
        )
        await self.handle_message(event)

    async def send(
        self,
        chat_id,
        content,
        reply_to=None,
        metadata=None,
    ) -> SendResult:
        if not self._session:
            return SendResult(success=False, error="not_connected")

        url = f"{self.base_url}/api/protected/hermes/bridge/reply"
        body: dict[str, Any] = {
            "chatId": str(chat_id),
            "conversationId": str(chat_id),
            "message": content if isinstance(content, str) else str(content),
            "done": True,
        }
        if reply_to:
            body["replyTo"] = str(reply_to)

        correlation_id = None
        if metadata and isinstance(metadata, dict):
            ss = (
                metadata.get("smartsaas")
                if isinstance(metadata.get("smartsaas"), dict)
                else {}
            )
            correlation_id = (
                ss.get("correlationId")
                or metadata.get("correlationId")
            )
        if not correlation_id:
            correlation_id = self._pending_correlations.pop(str(chat_id), None)
        if not correlation_id and self._pending_correlation_fifo:
            # Home-channel remaps (ID: hermes) must still complete SmartSaaS waiters.
            correlation_id = self._pending_correlation_fifo.pop(0)
            for key, value in list(self._pending_correlations.items()):
                if value == correlation_id:
                    self._pending_correlations.pop(key, None)
                    break
        elif correlation_id and correlation_id in self._pending_correlation_fifo:
            self._pending_correlation_fifo = [
                c for c in self._pending_correlation_fifo if c != correlation_id
            ]
        if correlation_id:
            body["correlationId"] = str(correlation_id)

        try:
            async with self._session.post(url, json=body) as resp:
                if resp.status >= 400:
                    text = await resp.text()
                    return SendResult(
                        success=False, error=f"HTTP {resp.status}: {text[:200]}"
                    )
                data = await resp.json(content_type=None)
                return SendResult(
                    success=True,
                    message_id=str(data.get("messageId") or data.get("id") or ""),
                )
        except Exception as exc:
            return SendResult(success=False, error=str(exc))

    async def send_typing(self, chat_id, metadata=None) -> None:
        if not self._session:
            return
        url = f"{self.base_url}/api/protected/hermes/bridge/typing"
        try:
            async with self._session.post(
                url, json={"chatId": str(chat_id), "conversationId": str(chat_id)}
            ):
                pass
        except Exception:
            pass

    async def get_chat_info(self, chat_id: str) -> dict[str, Any]:
        return {"name": str(chat_id), "type": "dm"}


def check_requirements() -> bool:
    """Passive probe: aiohttp + bridge env present."""
    try:
        import aiohttp  # noqa: F401
    except ImportError:
        return False
    return bool(_env("SMARTSAAS_BASE_URL") and _env("SMARTSAAS_BRIDGE_TOKEN"))


def validate_config(config) -> bool:
    extra = getattr(config, "extra", {}) or {}
    base = _env("SMARTSAAS_BASE_URL") or str(extra.get("base_url") or "")
    token = _env("SMARTSAAS_BRIDGE_TOKEN") or str(extra.get("bridge_token") or "")
    return bool(base and token)


def is_connected(config) -> bool:
    return validate_config(config)


def _env_enablement() -> dict | None:
    """Auto-enable platform when bridge env is set."""
    base = _env("SMARTSAAS_BASE_URL")
    token = _env("SMARTSAAS_BRIDGE_TOKEN")
    if not base or not token:
        return None
    return {
        "base_url": base,
        "bridge_token": token,
        "poll_seconds": int(_env("SMARTSAAS_POLL_SECONDS") or "25"),
    }


def register(ctx) -> None:
    """Hermes plugin entrypoint."""
    ctx.register_platform(
        name="smartsaas",
        label="SmartSaaS",
        adapter_factory=lambda config: SmartSaaSAdapter(config),
        check_fn=check_requirements,
        validate_config=validate_config,
        is_connected=is_connected,
        required_env=["SMARTSAAS_BASE_URL", "SMARTSAAS_BRIDGE_TOKEN"],
        env_enablement_fn=_env_enablement,
        emoji="🛰️",
        allowed_users_env="SMARTSAAS_ALLOWED_USERS",
        allow_all_env="SMARTSAAS_ALLOW_ALL_USERS",
        platform_hint=(
            "You are connected to SmartSaaS via the Hermes bridge. "
            "Reply helpfully; user and orchestrator messages arrive over this platform."
        ),
    )
