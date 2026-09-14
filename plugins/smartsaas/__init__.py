# Hermes plugin package — must export ``register`` for discovery.
from .adapter import register

__all__ = ["register"]
