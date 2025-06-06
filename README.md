# 🚨 NOLOCK Audit

Este proyecto audita archivos `.sql` para verificar que todas las tablas físicas usen correctamente `WITH (NOLOCK)` o `(NOLOCK)`.

## ✅ ¿Qué detecta?

- Tablas sin `WITH (NOLOCK)` o `(NOLOCK)`
- Variaciones válidas:
  - `WITH (NOLOCK)`
  - `WITH(NOLOCK)`
  - `(NOLOCK)`
  - `WITH (NOLOCK, READUNCOMMITTED)`
- Ignora:
  - Tablas temporales (`#tabla`)
  - Tablas dinámicas con variables (`@tabla`)

## 📦 Requisitos

```bash
pip install -r requirements.txt
```

## 🧪 Uso local

```bash
python audit_nolock.py ejemplo.sql
```

## 🤖 GitHub Actions

Este proyecto incluye una configuración para ejecutar el script automáticamente en cada push o pull request.
