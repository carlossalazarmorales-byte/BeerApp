"""Logging setup using only the standard library.

The application logs under the `app.*` namespace (`app.access` for one line per
request, `app.errors` for unhandled failures). Nothing here talks to a logging
vendor, and nothing logs request bodies, tokens, connection strings or keys.
"""

import logging

_FORMAT = "%(asctime)s %(levelname)s %(name)s %(message)s"
_HANDLER_MARKER = "_beerapp_stream_handler"

# Third-party loggers that would otherwise duplicate or leak what we control:
# - uvicorn.access logs the full request line INCLUDING the query string
#   (search text, barcodes); `app.access` replaces it without the query.
# - httpx/httpcore log outbound URLs (e.g. the Supabase admin user URL) at INFO.
_QUIETED_LOGGERS = ("uvicorn.access", "httpx", "httpcore")


def configure_logging(level: str = "INFO") -> None:
    """Idempotent. Sets the `app` logger level and, only when the process has
    no logging handlers at all (the uvicorn default), attaches one stream
    handler so the application's own logs are actually emitted.
    """
    app_logger = logging.getLogger("app")
    app_logger.setLevel(level.upper())

    already_attached = any(getattr(h, _HANDLER_MARKER, False) for h in app_logger.handlers)
    if not logging.getLogger().handlers and not already_attached:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(_FORMAT))
        setattr(handler, _HANDLER_MARKER, True)
        app_logger.addHandler(handler)

    for name in _QUIETED_LOGGERS:
        logger = logging.getLogger(name)
        if logger.level == logging.NOTSET or logger.level < logging.WARNING:
            logger.setLevel(logging.WARNING)
