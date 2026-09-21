from pydantic import BaseModel

# Upper bound for every `page` query parameter. OFFSET grows linearly in cost,
# so an unbounded page is both a resource-exhaustion vector and (at extreme
# values) an int64 overflow in the driver. With the maximum page_size of 100
# this still addresses ~1,000,000 rows -- far beyond any catalog or personal
# list this API serves -- while keeping `(page - 1) * page_size` a small
# integer. Callers needing "further" use the existing filters/search.
MAX_PAGE = 10_000

# Postgres `text` cannot contain a NUL (U+0000) character; sending one is a
# database error (a 500). Applied as a pattern to every free-text request
# field and search parameter so it becomes an ordinary 422 instead.
NO_NUL_PATTERN = r"^[^\x00]*$"


class Page[T](BaseModel):
    items: list[T]
    page: int
    page_size: int
    total: int
