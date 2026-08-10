# Python Project Detection

## Identification

- `pyproject.toml` exists → Python project (modern).
- `setup.py` exists → legacy Python project.
- `requirements.txt` exists → at least a Python project.

## Characterization

- **packageManager**:
  - `uv.lock` or `[tool.uv]` section in pyproject.toml → uv
  - `poetry.lock` or `[tool.poetry]` section → poetry
  - `Pipfile` → pipenv
  - `requirements.txt` only → pip
- **pythonVersion**: from `.project.requires-python`; extract `X.Y` with regex.
- **framework**: scan dependencies for fastapi, django, flask, starlette, aiohttp, tornado.
- **testCommand**: presence of `[tool.pytest.*]` → pytest.
- **lintCommand**: presence of `[tool.ruff]` → ruff check .
- **formatCommand**: presence of `[tool.ruff]` → ruff format.
- **typecheckCommand**: presence of `[tool.mypy]` → mypy; else `[tool.pyright]` → pyright.
- **virtualEnv**: defaults to packageManager; if none, venv.
- **dbMigrations**: `[tool.alembic]` → alembic; `django` in deps → django.

## Edge cases

- Multiple package managers (rare): uv wins over poetry wins over pipenv wins over pip.
- No pyproject.toml: read `setup.py` for name/version; treat as legacy.
- venv-style project with only `requirements.txt`: packageManager=pip, virtualEnv=venv.
