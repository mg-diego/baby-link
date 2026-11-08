from typing import Any, Callable

# Supabase (PostgREST) devuelve como máximo 1000 filas por petición y trunca sin avisar.
PAGE_SIZE = 1000


def fetch_all(build_query: Callable[[], Any], page_size: int = PAGE_SIZE) -> list[dict]:
    """Ejecuta la query página a página hasta agotar los resultados.

    `build_query` debe devolver una query NUEVA en cada llamada (los builders de
    postgrest acumulan parámetros) y con un orden estable, o las páginas se solapan.
    """
    rows: list[dict] = []
    offset = 0
    while True:
        page = build_query().range(offset, offset + page_size - 1).execute().data or []
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size
